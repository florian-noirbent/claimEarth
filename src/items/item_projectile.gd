class_name ItemProjectile
extends Node2D


signal resolved(projectile: ItemProjectile, impact_position: Vector2, resolution_kind: StringName)


var velocity := Vector2.ZERO
var gravity := 900.0
var fuse_seconds := 0.0
var remaining_fuse := 0.0
var destroyed_by_lava := true
var ignores_water := false
var action
var world: WorldGrid
var terrain_registry: TerrainRegistry
var hex_radius := 16.0

@onready var body: Polygon2D = Polygon2D.new()
@onready var outline: Line2D = Line2D.new()


func _ready() -> void:
	if body.get_parent() == null:
		body.polygon = PackedVector2Array([-6, -6, 6, -6, 6, 6, -6, 6])
		add_child(body)
	if outline.get_parent() == null:
		outline.width = 2.0
		add_child(outline)
	remaining_fuse = fuse_seconds


func configure(config: Dictionary) -> void:
	velocity = config.get("velocity", Vector2.ZERO)
	gravity = float(config.get("gravity", 900.0))
	fuse_seconds = float(config.get("fuse_seconds", 0.0))
	remaining_fuse = fuse_seconds
	destroyed_by_lava = bool(config.get("destroyed_by_lava", true))
	ignores_water = bool(config.get("ignores_water", false))
	body.polygon = config.get("polygon", body.polygon)
	body.color = config.get("color", Color.WHITE)
	var outline_points := body.polygon.duplicate()
	if outline_points.size() > 0:
		outline_points.append(outline_points[0])
	outline.points = outline_points
	outline.default_color = config.get("outline_color", Color(0.1, 0.05, 0.02, 1))


func _physics_process(delta: float) -> void:
	remaining_fuse -= delta
	velocity.y += gravity * delta
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
	var previous_position := global_position
	global_position += velocity * delta
	var definition := _sample_terrain(global_position)
	if definition != null:
		if destroyed_by_lava and definition.blast_reaction.resolve().detonate_immediately:
			resolved.emit(self, global_position, &"lava")
			queue_free()
			return
		if not definition.is_passable:
			resolved.emit(self, previous_position, &"impact")
			queue_free()
			return

	if remaining_fuse <= 0.0:
		resolved.emit(self, global_position, &"fuse")
		queue_free()


func _sample_terrain(world_position: Vector2) -> TerrainDefinition:
	if world == null or terrain_registry == null:
		return null
	var offset := HexMetrics.offset_for_world(world_position, hex_radius)
	if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return null
	return terrain_registry.get_definition(world.get_committed_by_offset(offset.x, offset.y))
