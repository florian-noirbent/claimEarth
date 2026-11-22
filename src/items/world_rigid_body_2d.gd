@tool
## Terrain-aware dynamic world body shared by thrown items and autonomous objects.
class_name WorldRigidBody2D
extends Node2D


## Feedback fact: the body rebounded off terrain at this speed in px/s.
signal bounced(impact_speed: float)

## Sprite scale used when a body config names a texture without its own `visual_scale`.
const DEFAULT_VISUAL_SCALE := 0.45

var velocity := Vector2.ZERO
var gravity := 900.0
var destructive_terrain_tags := PackedStringArray(["lava"])
var destroyed_by_lava: bool:
	get:
		return destructive_terrain_tags.has(&"lava")
	set(value):
		if value:
			if not destructive_terrain_tags.has(&"lava"):
				destructive_terrain_tags.append(&"lava")
		else:
			destructive_terrain_tags.erase(&"lava")
var ignores_water := false
var bounce_on_impact := false
var stop_on_impact := false
var bounce_damping := 0.55
var horizontal_bounce_damping := 0.72
var simulation_backend: TerrainSimulationBackend
var world: WorldGrid
var terrain_registry: TerrainRegistry
## Optional terrain tables shared by the owner; compiled from the registry when unset.
var compiled_terrain: CompiledTerrainData
var hex_radius := 16.0
var _terrain_query = TerrainCollisionQuery.new()

var body: Polygon2D
var outline: Line2D
var sprite: Sprite2D
## Mirrors the sprite across the flight axis when the body heads left, so an icon with an up
## side never flies upside down.
var sprite_mirrors_with_heading := false
## Speed in px/s below which the sprite keeps the orientation it had in flight, so an item
## that settles into small bounces lies still instead of flipping with each one. 0 disables it.
var sprite_settle_speed := 0.0
## Sprite rotation of a body heading right.
var _sprite_rest_rotation := 0.0
var _sprite_heading := 1.0
## Body rotation the sprite is shown at; differs from the body's own only while settled.
var _sprite_flight_rotation := 0.0
var _pending_polygon := PackedVector2Array([-6, -6, 6, -6, 6, 6, -6, 6])
var _pending_color := Color.WHITE
var _pending_outline_color := Color(0.1, 0.05, 0.02, 1.0)


func _ready() -> void:
	_ensure_visuals()


func configure_body(config: Dictionary) -> void:
	velocity = config.get("velocity", Vector2.ZERO) as Vector2
	gravity = float(config.get("gravity", 900.0))
	if config.has("destructive_terrain_tags"):
		destructive_terrain_tags = config["destructive_terrain_tags"] as PackedStringArray
	else:
		destroyed_by_lava = bool(config.get("destroyed_by_lava", true))
	ignores_water = bool(config.get("ignores_water", false))
	bounce_on_impact = bool(config.get("bounce_on_impact", false))
	stop_on_impact = bool(config.get("stop_on_impact", false))
	bounce_damping = float(config.get("bounce_damping", 0.55))
	horizontal_bounce_damping = float(config.get("horizontal_bounce_damping", 0.72))
	_pending_polygon = config.get("polygon", _pending_polygon) as PackedVector2Array
	_pending_color = config.get("color", Color.WHITE) as Color
	_pending_outline_color = config.get("outline_color", Color(0.1, 0.05, 0.02, 1)) as Color
	var visual_texture := config.get("visual_texture") as Texture2D
	if visual_texture != null and sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = visual_texture
		sprite.scale = Vector2.ONE * float(config.get("visual_scale", DEFAULT_VISUAL_SCALE))
		sprite.rotation = deg_to_rad(float(config.get("visual_rotation_degrees", 0.0)))
		sprite.offset = config.get("visual_offset", Vector2.ZERO) as Vector2
		# World sprites are drawn far below their texture size; mipmaps keep them stable in motion.
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.z_index = 10
		sprite_mirrors_with_heading = bool(config.get("visual_mirror_with_heading", false))
		sprite_settle_speed = float(config.get("visual_settle_speed", 0.0))
		_sprite_rest_rotation = sprite.rotation
		add_child(sprite)
	_ensure_visuals()


## World position of a point given in texture px from the sprite's center. It follows the
## sprite's scale, rotation, and mirroring; without a sprite the point is in body space.
func visual_point(texture_offset: Vector2) -> Vector2:
	if sprite == null:
		return global_transform * texture_offset
	return sprite.global_transform * (sprite.offset + texture_offset)


func visual_polygon() -> PackedVector2Array:
	return _pending_polygon.duplicate()


func outline_point_count() -> int:
	return outline.points.size() if outline != null else 0


func apply_blast_impulse(origin: Vector2, maximum_impulse: float, radius: float) -> void:
	if maximum_impulse <= 0.0 or radius <= 0.0:
		return
	var displacement := global_position - origin
	var distance := displacement.length()
	if distance > radius:
		return
	var direction := Vector2.UP if distance <= 0.001 else displacement / distance
	velocity += direction * maximum_impulse * (1.0 - distance / radius)


## Advances one body step and returns a destructive terrain tag, impact, grounded, or an empty kind.
func advance_body(delta: float) -> StringName:
	if delta <= 0.0:
		return &""
	velocity.y += gravity * delta
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
		_orient_sprite()
	var previous_position := global_position
	global_position += velocity * delta
	_ensure_terrain_query()
	var definition := _sample_terrain(global_position)
	var destruction_kind := _destructive_terrain_kind(definition, _sample_quantity(global_position))
	if not destruction_kind.is_empty():
		return destruction_kind
	if not _terrain_query.is_solid_at_world(global_position):
		return &""
	if stop_on_impact:
		global_position = previous_position
		velocity = Vector2.ZERO
		rotation = 0.0
		return &"grounded"
	if bounce_on_impact:
		_bounce(previous_position, delta)
		return &""
	global_position = previous_position
	return &"impact"


func _ensure_visuals() -> void:
	if body == null:
		body = Polygon2D.new()
	if body.get_parent() == null:
		add_child(body)
	if outline == null:
		outline = Line2D.new()
		outline.width = 2.0
	if outline.get_parent() == null:
		add_child(outline)
	body.polygon = _pending_polygon
	body.color = _pending_color
	var outline_points := _pending_polygon.duplicate()
	if not outline_points.is_empty():
		outline_points.append(outline_points[0])
	outline.points = outline_points
	outline.default_color = _pending_outline_color
	# The polygon is the fallback look; a body with a sprite shows only the sprite.
	body.visible = sprite == null
	outline.visible = sprite == null


## Keeps the sprite's look in step with the body: mirrored for a left heading, and held at
## its flight orientation while the body is slower than the settle speed.
func _orient_sprite() -> void:
	if sprite == null:
		return
	var settled := sprite_settle_speed > 0.0 and velocity.length() < sprite_settle_speed
	if not settled:
		_sprite_flight_rotation = rotation
		if sprite_mirrors_with_heading and not is_zero_approx(velocity.x):
			_sprite_heading = signf(velocity.x)
	# The body turns with its velocity, which puts a left-bound sprite on its head. Flipping
	# the sprite across the flight axis stands it up again as its own mirror image.
	sprite.scale.y = absf(sprite.scale.y) * _sprite_heading
	sprite.rotation = _sprite_rest_rotation * _sprite_heading
	if sprite_settle_speed > 0.0:
		sprite.rotation += _sprite_flight_rotation - rotation


func _sample_terrain(world_position: Vector2) -> TerrainDefinition:
	if world == null or terrain_registry == null:
		return null
	var offset := HexMetrics.offset_for_world(world_position, hex_radius)
	if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return null
	return terrain_registry.get_definition(world.get_committed_by_offset(offset.x, offset.y))


func _sample_quantity(world_position: Vector2) -> int:
	if world == null:
		return 0
	var offset := HexMetrics.offset_for_world(world_position, hex_radius)
	if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return 0
	return world.get_committed_quantity_by_offset(offset.x, offset.y)


func _destructive_terrain_kind(definition: TerrainDefinition, quantity: int) -> StringName:
	if definition == null or definition.hazard_behavior.resolve_for_quantity(quantity) == null:
		return &""
	for terrain_tag in destructive_terrain_tags:
		if definition.perk_tags.has(terrain_tag):
			return terrain_tag
	return &""


func _bounce(previous_position: Vector2, delta: float) -> void:
	global_position = previous_position
	var impact_speed := velocity.length()
	var x_hit := _is_blocked(previous_position + Vector2(velocity.x * delta, 0.0))
	var y_hit := _is_blocked(previous_position + Vector2(0.0, velocity.y * delta))
	velocity.x = -velocity.x * horizontal_bounce_damping if x_hit else velocity.x * horizontal_bounce_damping
	if y_hit:
		velocity.y = -velocity.y * bounce_damping
		if absf(velocity.y) < 40.0:
			velocity.y = -40.0
	else:
		velocity.y = -absf(velocity.y) * bounce_damping
	rotation = velocity.angle() if velocity.length_squared() > 1.0 else rotation
	_orient_sprite()
	bounced.emit(impact_speed)


func _is_blocked(world_position: Vector2) -> bool:
	_ensure_terrain_query()
	return _terrain_query.is_solid_at_world(world_position)


func _ensure_terrain_query() -> void:
	if world == null or terrain_registry == null or _terrain_query.is_configured():
		return
	if compiled_terrain == null:
		compiled_terrain = CompiledTerrainData.compile(terrain_registry)
	_terrain_query.configure(world, compiled_terrain, hex_radius)
