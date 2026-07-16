## Terrain-aware dynamic world body shared by thrown items and autonomous objects.
class_name WorldRigidBody2D
extends Node2D


var velocity := Vector2.ZERO
var gravity := 900.0
var destroyed_by_lava := true
var ignores_water := false
var bounce_on_impact := false
var stop_on_impact := false
var bounce_damping := 0.55
var horizontal_bounce_damping := 0.72
var simulation_backend: TerrainSimulationBackend
var world: WorldGrid
var terrain_registry: TerrainRegistry
var hex_radius := 16.0

var body: Polygon2D
var outline: Line2D
var sprite: Sprite2D
var _pending_polygon := PackedVector2Array([-6, -6, 6, -6, 6, 6, -6, 6])
var _pending_color := Color.WHITE
var _pending_outline_color := Color(0.1, 0.05, 0.02, 1.0)


func _ready() -> void:
	_ensure_visuals()


func configure_body(config: Dictionary) -> void:
	velocity = config.get("velocity", Vector2.ZERO) as Vector2
	gravity = float(config.get("gravity", 900.0))
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
		sprite.scale = Vector2(0.45, 0.45)
		sprite.z_index = 10
		add_child(sprite)
	_ensure_visuals()


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


## Advances one body step and returns lava, impact, grounded, or an empty kind.
func advance_body(delta: float) -> StringName:
	if delta <= 0.0:
		return &""
	velocity.y += gravity * delta
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
	var previous_position := global_position
	global_position += velocity * delta
	var definition := _sample_terrain(global_position)
	if definition == null:
		return &""
	if destroyed_by_lava and definition.blast_reaction.resolve().detonate_immediately and definition.hazard_behavior.resolve_for_quantity(_sample_quantity(global_position)) != null:
		return &"lava"
	if definition.is_passable:
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


func _bounce(previous_position: Vector2, delta: float) -> void:
	global_position = previous_position
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


func _is_blocked(world_position: Vector2) -> bool:
	var definition := _sample_terrain(world_position)
	return definition != null and not definition.is_passable
