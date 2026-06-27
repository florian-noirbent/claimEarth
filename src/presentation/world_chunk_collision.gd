class_name WorldChunkCollision
extends StaticBody2D


@onready var collision_shape: CollisionShape2D = CollisionShape2D.new()

var chunk_coord := Vector2i.ZERO
var chunk_rect := Rect2i()
var _edge_segments: Dictionary = {}


func _ready() -> void:
	if collision_shape.get_parent() == null:
		add_child(collision_shape)


func configure(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	chunk_coord_value: Vector2i,
	chunk_rect_value: Rect2i,
	hex_radius: float = 16.0
) -> void:
	chunk_coord = chunk_coord_value
	chunk_rect = chunk_rect_value
	var shape := ConcavePolygonShape2D.new()
	shape.segments = _build_segments(world, terrain_registry, hex_radius)
	collision_shape.shape = shape


func apply_segments(segments: PackedVector2Array) -> void:
	_edge_segments.clear()
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	collision_shape.shape = shape


func apply_result(result: ChunkBuildResult) -> void:
	if result.collision_full_rebuild:
		_edge_segments.clear()
	var point_cursor := 0
	for edge_index in range(result.collision_edge_keys.size()):
		var key := int(result.collision_edge_keys[edge_index])
		if result.collision_edge_enabled[edge_index] == 0:
			_edge_segments.erase(key)
			continue
		_edge_segments[key] = PackedVector2Array([
			result.collision_edge_points[point_cursor],
			result.collision_edge_points[point_cursor + 1],
		])
		point_cursor += 2
	var keys := _edge_segments.keys()
	keys.sort()
	var segments := PackedVector2Array()
	for key in keys:
		segments.append_array(_edge_segments[key] as PackedVector2Array)
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	collision_shape.shape = shape


func segment_count() -> int:
	var shape := collision_shape.shape as ConcavePolygonShape2D
	if shape == null:
		return 0
	return int(shape.segments.size() / 2)


func _build_segments(world: WorldGrid, terrain_registry: TerrainRegistry, hex_radius: float) -> PackedVector2Array:
	var metadata := CompiledTerrainData.compile(terrain_registry)
	var corners := HexMetrics.corners(hex_radius)
	var segments := PackedVector2Array()

	for row in range(chunk_rect.position.y, chunk_rect.end.y):
		for col in range(chunk_rect.position.x, chunk_rect.end.x):
			var cell_id := world.get_committed_by_offset(col, row)
			var fill := world.get_committed_fill_by_offset(col, row)
			if not metadata.is_solid(cell_id, fill):
				continue

			var center := HexMetrics.center_for_offset(col, row, hex_radius)
			var cell_coord := HexCoord.from_offset_odd_q(col, row)
			for direction in range(6):
				var neighbor_offset := cell_coord.neighbor(direction).to_offset_odd_q()
				var add_edge := true
				if world.dimensions.is_in_bounds_offset(neighbor_offset.x, neighbor_offset.y):
					add_edge = not metadata.is_solid(
						world.get_committed_by_offset(neighbor_offset.x, neighbor_offset.y),
						world.get_committed_fill_by_offset(neighbor_offset.x, neighbor_offset.y)
					)
				if add_edge:
					var edge_corners := HexMetrics.edge_corner_indices_for_direction(direction)
					segments.append(center + corners[edge_corners.x])
					segments.append(center + corners[edge_corners.y])

	return segments
