class_name ChunkBuildJob
extends RefCounted


var chunk_coord := Vector2i.ZERO
var revision := 0
var layer_mask := TerrainLayerMask.NONE
var chunk_rect := Rect2i()
var snapshot_rect := Rect2i()
var snapshot_cells := PackedByteArray()
var collision_indices := PackedInt32Array()
var metadata: CompiledTerrainData
var hex_radius := 16.0
var world_width := 0
var result := ChunkBuildResult.new()
var _cursor := 0
var _started_usec := 0
var _corners := PackedVector2Array()
var _static_vertices: Array[Vector3] = []
var _static_colors: Array[Color] = []
var _static_uvs: Array[Vector2] = []
var _static_indices: Array[int] = []
var _sand_vertices: Array[Vector3] = []
var _sand_colors: Array[Color] = []
var _sand_uvs: Array[Vector2] = []
var _sand_indices: Array[int] = []
var _fluid_vertices: Array[Vector3] = []
var _fluid_colors: Array[Color] = []
var _fluid_uvs: Array[Vector2] = []
var _fluid_indices: Array[int] = []
var _collision_segments: Array[Vector2] = []
var _collision_cursor := 0
var _collision_edge_keys: Array[int] = []
var _collision_edge_enabled: Array[int] = []
var _collision_edge_points: Array[Vector2] = []


func configure(
	chunk_coord_value: Vector2i,
	revision_value: int,
	layer_mask_value: int,
	chunk_rect_value: Rect2i,
	snapshot_rect_value: Rect2i,
	snapshot_cells_value: PackedByteArray,
	metadata_value: CompiledTerrainData,
	hex_radius_value: float,
	world_width_value: int,
	collision_indices_value: PackedInt32Array = PackedInt32Array()
) -> void:
	chunk_coord = chunk_coord_value
	revision = revision_value
	layer_mask = layer_mask_value
	chunk_rect = chunk_rect_value
	snapshot_rect = snapshot_rect_value
	snapshot_cells = snapshot_cells_value
	collision_indices = collision_indices_value
	metadata = metadata_value
	hex_radius = hex_radius_value
	world_width = world_width_value
	_corners = HexMetrics.corners(hex_radius)
	result.chunk_coord = chunk_coord
	result.revision = revision
	result.layer_mask = layer_mask
	result.collision_full_rebuild = (layer_mask & TerrainLayerMask.COLLISION) != 0 and collision_indices.is_empty()
	_started_usec = Time.get_ticks_usec()


func advance(time_budget_usec: int) -> bool:
	var deadline := Time.get_ticks_usec() + maxi(time_budget_usec, 1)
	var cell_count := chunk_rect.size.x * chunk_rect.size.y
	while _cursor < cell_count:
		var local_col := _cursor % chunk_rect.size.x
		var local_row := int(_cursor / chunk_rect.size.x)
		var col := chunk_rect.position.x + local_col
		var row := chunk_rect.position.y + local_row
		_process_cell(col, row)
		_cursor += 1
		if Time.get_ticks_usec() >= deadline:
			return false
	if (layer_mask & TerrainLayerMask.COLLISION) != 0:
		var collision_count := cell_count if result.collision_full_rebuild else collision_indices.size()
		while _collision_cursor < collision_count:
			var collision_index: int
			if result.collision_full_rebuild:
				var local_col := _collision_cursor % chunk_rect.size.x
				var local_row := int(_collision_cursor / chunk_rect.size.x)
				collision_index = (chunk_rect.position.y + local_row) * world_width + chunk_rect.position.x + local_col
			else:
				collision_index = collision_indices[_collision_cursor]
			_append_collision_cell_edges(collision_index)
			_collision_cursor += 1
			if Time.get_ticks_usec() >= deadline:
				return false
	result.static_vertices = PackedVector3Array(_static_vertices)
	result.static_colors = PackedColorArray(_static_colors)
	result.static_uvs = PackedVector2Array(_static_uvs)
	result.static_indices = PackedInt32Array(_static_indices)
	result.sand_vertices = PackedVector3Array(_sand_vertices)
	result.sand_colors = PackedColorArray(_sand_colors)
	result.sand_uvs = PackedVector2Array(_sand_uvs)
	result.sand_indices = PackedInt32Array(_sand_indices)
	result.fluid_vertices = PackedVector3Array(_fluid_vertices)
	result.fluid_colors = PackedColorArray(_fluid_colors)
	result.fluid_uvs = PackedVector2Array(_fluid_uvs)
	result.fluid_indices = PackedInt32Array(_fluid_indices)
	result.collision_segments = PackedVector2Array(_collision_segments)
	result.collision_edge_keys = PackedInt64Array(_collision_edge_keys)
	result.collision_edge_enabled = PackedByteArray(_collision_edge_enabled)
	result.collision_edge_points = PackedVector2Array(_collision_edge_points)
	result.build_usec = Time.get_ticks_usec() - _started_usec
	return true


func _process_cell(col: int, row: int) -> void:
	var cell_id := _cell_at(col, row)
	var visual_layer := metadata.visual_layer(cell_id)
	if (layer_mask & visual_layer) != 0:
		_append_hex(visual_layer, col, row, cell_id)


func _append_hex(layer: int, col: int, row: int, cell_id: int) -> void:
	var vertices: Array[Vector3]
	var colors: Array[Color]
	var uvs: Array[Vector2]
	var indices: Array[int]
	if layer == TerrainLayerMask.SAND_VISUAL:
		vertices = _sand_vertices
		colors = _sand_colors
		uvs = _sand_uvs
		indices = _sand_indices
	elif layer == TerrainLayerMask.FLUID_VISUAL:
		vertices = _fluid_vertices
		colors = _fluid_colors
		uvs = _fluid_uvs
		indices = _fluid_indices
	else:
		vertices = _static_vertices
		colors = _static_colors
		uvs = _static_uvs
		indices = _static_indices
	var center := _cell_center(col, row)
	var base := vertices.size()
	vertices.append(Vector3(center.x, center.y, 0.0))
	colors.append(metadata.fill_color_by_id[cell_id])
	uvs.append(center / 64.0)
	for corner in _corners:
		var point := center + corner
		vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append(metadata.fill_color_by_id[cell_id])
		uvs.append(point / 64.0)
	for corner_index in range(6):
		indices.append(base)
		indices.append(base + 1 + corner_index)
		indices.append(base + 1 + ((corner_index + 1) % 6))


func _append_collision_cell_edges(index: int) -> void:
	var col := index % world_width
	var row := int(index / world_width)
	if not chunk_rect.has_point(Vector2i(col, row)):
		return
	var center := _cell_center(col, row)
	var parity := col & 1
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(col + 1, row + parity),
		Vector2i(col + 1, row + parity - 1),
		Vector2i(col, row - 1),
		Vector2i(col - 1, row + parity - 1),
		Vector2i(col - 1, row + parity),
		Vector2i(col, row + 1),
	]
	for direction in range(6):
		var neighbor := neighbor_offsets[direction]
		var exposed := metadata.is_solid(_cell_at(col, row)) and (not _contains_snapshot(neighbor.x, neighbor.y) or not metadata.is_solid(_cell_at(neighbor.x, neighbor.y)))
		_collision_edge_keys.append(index * 6 + direction)
		_collision_edge_enabled.append(1 if exposed else 0)
		if not exposed:
			continue
		var edge := HexMetrics.edge_corner_indices_for_direction(direction)
		_collision_edge_points.append(center + _corners[edge.x])
		_collision_edge_points.append(center + _corners[edge.y])


func _cell_at(col: int, row: int) -> int:
	if not _contains_snapshot(col, row):
		return metadata.air_id
	var local_col := col - snapshot_rect.position.x
	var local_row := row - snapshot_rect.position.y
	return int(snapshot_cells[local_row * snapshot_rect.size.x + local_col])


func _contains_snapshot(col: int, row: int) -> bool:
	return snapshot_rect.has_point(Vector2i(col, row))


func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		hex_radius * 1.5 * float(col),
		hex_radius * sqrt(3.0) * (float(row) + float(col & 1) * 0.5)
	)

