## Owns projectile flight, terrain sampling, fuse/bounce behavior, and resolution signals.
class_name ItemProjectile
extends Node2D


signal resolved(projectile: ItemProjectile, impact_position: Vector2, resolution_kind: StringName)


var velocity := Vector2.ZERO
var gravity := 900.0
var fuse_seconds := 0.0
var remaining_fuse := 0.0
var destroyed_by_lava := true
var ignores_water := false
var bounce_on_impact := false
var bounce_damping := 0.55
var horizontal_bounce_damping := 0.72
var action: ItemAction
var explosive: WorldExplosive2D
var world: WorldGrid
var terrain_registry: TerrainRegistry
var hex_radius := 16.0

var body: Polygon2D
var outline: Line2D
var _pending_polygon := PackedVector2Array([-6, -6, 6, -6, 6, 6, -6, 6])
var _pending_color := Color.WHITE
var _pending_outline_color := Color(0.1, 0.05, 0.02, 1.0)


func _ready() -> void:
	_ensure_visuals()
	remaining_fuse = fuse_seconds


func configure(config: Dictionary) -> void:
	velocity = config.get("velocity", Vector2.ZERO) as Vector2
	gravity = float(config.get("gravity", 900.0))
	fuse_seconds = float(config.get("fuse_seconds", 0.0))
	remaining_fuse = fuse_seconds
	destroyed_by_lava = bool(config.get("destroyed_by_lava", true))
	ignores_water = bool(config.get("ignores_water", false))
	bounce_on_impact = bool(config.get("bounce_on_impact", false))
	bounce_damping = float(config.get("bounce_damping", 0.55))
	horizontal_bounce_damping = float(config.get("horizontal_bounce_damping", 0.72))
	_pending_polygon = config.get("polygon", _pending_polygon) as PackedVector2Array
	_pending_color = config.get("color", Color.WHITE) as Color
	_pending_outline_color = config.get("outline_color", Color(0.1, 0.05, 0.02, 1)) as Color
	var explosion_definition := config.get("explosion_definition") as ExplosionDefinition
	if explosion_definition != null:
		if explosive == null:
			explosive = WorldExplosive2D.new()
			explosive.name = "WorldExplosive"
			add_child(explosive)
		explosive.configure(explosion_definition, _pending_polygon)
	_ensure_visuals()


func visual_polygon() -> PackedVector2Array:
	return _pending_polygon.duplicate()


func outline_point_count() -> int:
	if outline == null:
		return 0
	return outline.points.size()


func apply_blast_impulse(origin: Vector2, maximum_impulse: float, radius: float) -> void:
	if maximum_impulse <= 0.0 or radius <= 0.0:
		return
	var displacement := global_position - origin
	var distance := displacement.length()
	if distance > radius:
		return
	var direction := Vector2.UP if distance <= 0.001 else displacement / distance
	var falloff := 1.0 - distance / radius
	velocity += direction * maximum_impulse * falloff


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
	if outline_points.size() > 0:
		outline_points.append(outline_points[0])
	outline.points = outline_points
	outline.default_color = _pending_outline_color


func _physics_process(delta: float) -> void:
	remaining_fuse -= delta
	velocity.y += gravity * delta
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
	var previous_position := global_position
	global_position += velocity * delta
	var definition := _sample_terrain(global_position)
	if definition != null:
		if destroyed_by_lava and definition.blast_reaction.resolve().detonate_immediately and definition.hazard_behavior.resolve_for_fill(_sample_fill(global_position)) != null:
			_resolve_at(global_position, &"lava")
			queue_free()
			return
		if not definition.is_passable:
			if bounce_on_impact:
				_bounce(previous_position, delta)
			else:
				resolved.emit(self, previous_position, &"impact")
				queue_free()
				return

	if remaining_fuse <= 0.0:
		_resolve_at(global_position, &"fuse")
		queue_free()


func _resolve_at(impact_position: Vector2, resolution_kind: StringName) -> void:
	if explosive != null:
		explosive.request_immediate_detonation()
		return
	resolved.emit(self, impact_position, resolution_kind)


func _sample_terrain(world_position: Vector2) -> TerrainDefinition:
	if world == null or terrain_registry == null:
		return null
	var offset := HexMetrics.offset_for_world(world_position, hex_radius)
	if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return null
	return terrain_registry.get_definition(world.get_committed_by_offset(offset.x, offset.y))


func _sample_fill(world_position: Vector2) -> int:
	if world == null:
		return 0
	var offset := HexMetrics.offset_for_world(world_position, hex_radius)
	if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return 0
	return world.get_committed_fill_by_offset(offset.x, offset.y)


func _bounce(previous_position: Vector2, delta: float) -> void:
	global_position = previous_position
	var x_hit := _is_blocked(previous_position + Vector2(velocity.x * delta, 0.0))
	var y_hit := _is_blocked(previous_position + Vector2(0.0, velocity.y * delta))

	if x_hit:
		velocity.x = -velocity.x * horizontal_bounce_damping
	else:
		velocity.x *= horizontal_bounce_damping

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
