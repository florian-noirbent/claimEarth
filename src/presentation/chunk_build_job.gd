## Builds resource-free chunk mesh arrays and collision edge updates from world snapshots.
class_name ChunkBuildJob
extends RefCounted


var chunk_coord := Vector2i.ZERO
var revision := 0
var layer_mask := TerrainLayerMask.NONE
var chunk_rect := Rect2i()
var snapshot_rect := Rect2i()
var snapshot_cells := PackedByteArray()
var snapshot_fill := PackedByteArray()
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
var _static_material_meshes := {}
var _static_edge_meshes := {}
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
	snapshot_fill_value: PackedByteArray,
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
	snapshot_fill = snapshot_fill_value
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
	result.static_material_meshes = _static_material_meshes
	result.static_edge_meshes = _static_edge_meshes
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
	var fill := _fill_at(col, row)
	var visual_layer := metadata.visual_layer(cell_id)
	if (layer_mask & visual_layer) != 0:
		_append_cell_visual(visual_layer, col, row, cell_id, fill)
		if visual_layer == TerrainLayerMask.STATIC_VISUAL:
			_append_static_edges(col, row, cell_id, fill)


func _append_cell_visual(layer: int, col: int, row: int, cell_id: int, fill: int) -> void:
	if not metadata.is_moving(cell_id) or fill >= 255:
		_append_hex_polygon(layer, col, row, cell_id, _corners)
		return
	if fill <= 0:
		return
	var above_id := _cell_at(col, row - 1)
	var above_fill := _fill_at(col, row - 1)
	if metadata.is_solid(above_id, above_fill):
		_append_hex_polygon(layer, col, row, cell_id, _corners)
		return
	var surface := _moving_surface_points(col, row, cell_id, fill)
	var bottom_polygon := _filled_moving_polygon(surface)
	if bottom_polygon.size() >= 3:
		_append_hex_polygon(layer, col, row, cell_id, bottom_polygon)
	if metadata.motion(above_id) == CompiledTerrainData.MOTION_LIQUID and above_fill > 0:
		var above_layer := metadata.visual_layer(above_id)
		if (layer_mask & above_layer) != 0:
			var top_polygon := _empty_moving_polygon(surface)
			if top_polygon.size() >= 3:
				_append_hex_polygon(above_layer, col, row, above_id, top_polygon)


func _moving_surface_points(col: int, row: int, cell_id: int, fill: int) -> PackedVector2Array:
	var center := _cell_center(col, row)
	var center_y := _fill_line_y(fill)
	var left_y := _side_surface_y(col, row, cell_id, fill, -1, center, center_y)
	var right_y := _side_surface_y(col, row, cell_id, fill, 1, center, center_y)
	return PackedVector2Array([
		Vector2(_left_boundary_x(left_y), left_y),
		Vector2(0.0, center_y),
		Vector2(_right_boundary_x(right_y), right_y),
	])


func _side_surface_y(col: int, row: int, cell_id: int, fill: int, side: int, center: Vector2, center_y: float) -> float:
	var neighbor := _surface_neighbor_for_side(col, row, side, center_y)
	if _cell_at(neighbor.x, neighbor.y) != cell_id:
		return center_y
	var neighbor_fill := _fill_at(neighbor.x, neighbor.y)
	if neighbor_fill <= 0:
		return center_y
	var neighbor_center := _cell_center(neighbor.x, neighbor.y)
	var side_world_y := (center.y + _fill_line_y(fill) + neighbor_center.y + _fill_line_y(neighbor_fill)) * 0.5
	var half_height := _half_height()
	return clampf(side_world_y - center.y, -half_height, half_height)


func _surface_neighbor_for_side(col: int, row: int, side: int, surface_y: float) -> Vector2i:
	var parity := col & 1
	var row_delta := parity - 1 if surface_y <= 0.0 else parity
	return Vector2i(col + side, row + row_delta)


func _filled_moving_polygon(surface: PackedVector2Array) -> PackedVector2Array:
	var polygon := PackedVector2Array([surface[0], surface[1], surface[2]])
	if surface[2].y <= 0.0:
		polygon.append(_corners[1])
	polygon.append(_corners[2])
	polygon.append(_corners[3])
	if surface[0].y < 0.0:
		polygon.append(_corners[4])
	return polygon


func _empty_moving_polygon(surface: PackedVector2Array) -> PackedVector2Array:
	var polygon := PackedVector2Array([surface[0]])
	if surface[0].y >= 0.0:
		polygon.append(_corners[4])
	polygon.append(_corners[5])
	polygon.append(_corners[0])
	if surface[2].y > 0.0:
		polygon.append(_corners[1])
	polygon.append(surface[2])
	polygon.append(surface[1])
	return polygon


func _append_hex_polygon(layer: int, col: int, row: int, cell_id: int, polygon: PackedVector2Array) -> void:
	var vertices: Array[Vector3]
	var colors: Array[Color]
	var uvs: Array[Vector2]
	var indices: Array[int]
	var uv_scale := 64.0
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
		var material_index := int(metadata.material_index_by_id[cell_id])
		if material_index > 0:
			var mesh_arrays := _static_material_mesh(material_index)
			vertices = mesh_arrays.vertices
			colors = mesh_arrays.colors
			uvs = mesh_arrays.uvs
			indices = mesh_arrays.indices
			uv_scale = maxf(metadata.fill_texture_world_scale_by_id[cell_id], 1.0)
		else:
			vertices = _static_vertices
			colors = _static_colors
			uvs = _static_uvs
			indices = _static_indices
	var center := _cell_center(col, row)
	var base := vertices.size()
	var polygon_center := _polygon_centroid(polygon)
	var fan_center := center + polygon_center
	var vertex_color := metadata.fill_color_by_id[cell_id]
	vertices.append(Vector3(fan_center.x, fan_center.y, 0.0))
	colors.append(vertex_color)
	uvs.append(fan_center / uv_scale)
	for corner in polygon:
		var point := center + corner
		vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append(vertex_color)
		uvs.append(point / uv_scale)
	for corner_index in range(polygon.size()):
		indices.append(base)
		indices.append(base + 1 + corner_index)
		indices.append(base + 1 + ((corner_index + 1) % polygon.size()))


func _static_material_mesh(material_index: int) -> ChunkMeshArrays:
	if not _static_material_meshes.has(material_index):
		_static_material_meshes[material_index] = ChunkMeshArrays.new()
	return _static_material_meshes[material_index] as ChunkMeshArrays


func _append_static_edges(col: int, row: int, cell_id: int, fill: int) -> void:
	var edge_width := metadata.edge_width_by_id[cell_id]
	var edge_color := metadata.edge_color_by_id[cell_id]
	if edge_width <= 0.0 or edge_color.a <= 0.0 or not metadata.is_solid(cell_id, fill):
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
	var material_index := int(metadata.material_index_by_id[cell_id])
	for direction in range(6):
		var neighbor := neighbor_offsets[direction]
		if not _should_draw_static_edge(col, row, cell_id, fill, neighbor):
			continue
		var edge := HexMetrics.edge_corner_indices_for_direction(direction)
		_append_edge_quad(
			_static_edge_mesh(material_index),
			center,
			center + _corners[edge.x],
			center + _corners[edge.y],
			edge_width,
			edge_color
		)


func _should_draw_static_edge(col: int, row: int, cell_id: int, fill: int, neighbor: Vector2i) -> bool:
	if not _contains_snapshot(neighbor.x, neighbor.y):
		return true
	var neighbor_id := _cell_at(neighbor.x, neighbor.y)
	var neighbor_fill := _fill_at(neighbor.x, neighbor.y)
	if not metadata.is_solid(neighbor_id, neighbor_fill):
		return true
	if metadata.visual_layer(neighbor_id) != TerrainLayerMask.STATIC_VISUAL:
		return true
	var material_index := int(metadata.material_index_by_id[cell_id])
	var neighbor_material_index := int(metadata.material_index_by_id[neighbor_id])
	if material_index == neighbor_material_index:
		return false
	return row * world_width + col < neighbor.y * world_width + neighbor.x


func _append_edge_quad(mesh_arrays: ChunkMeshArrays, center: Vector2, start: Vector2, end: Vector2, edge_width: float, edge_color: Color) -> void:
	var outward := ((start + end) * 0.5 - center).normalized()
	if outward == Vector2.ZERO:
		return
	var base := mesh_arrays.vertices.size()
	var outer_start := start + outward * edge_width
	var outer_end := end + outward * edge_width
	mesh_arrays.vertices.append(Vector3(start.x, start.y, 0.0))
	mesh_arrays.vertices.append(Vector3(end.x, end.y, 0.0))
	mesh_arrays.vertices.append(Vector3(outer_end.x, outer_end.y, 0.0))
	mesh_arrays.vertices.append(Vector3(outer_start.x, outer_start.y, 0.0))
	for _index in range(4):
		mesh_arrays.colors.append(edge_color)
		mesh_arrays.uvs.append(Vector2.ZERO)
	mesh_arrays.indices.append(base)
	mesh_arrays.indices.append(base + 1)
	mesh_arrays.indices.append(base + 2)
	mesh_arrays.indices.append(base)
	mesh_arrays.indices.append(base + 2)
	mesh_arrays.indices.append(base + 3)


func _static_edge_mesh(material_index: int) -> ChunkMeshArrays:
	if not _static_edge_meshes.has(material_index):
		_static_edge_meshes[material_index] = ChunkMeshArrays.new()
	return _static_edge_meshes[material_index] as ChunkMeshArrays


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
		var exposed := metadata.is_solid(_cell_at(col, row), _fill_at(col, row)) and (not _contains_snapshot(neighbor.x, neighbor.y) or not metadata.is_solid(_cell_at(neighbor.x, neighbor.y), _fill_at(neighbor.x, neighbor.y)))
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


func _fill_at(col: int, row: int) -> int:
	if not _contains_snapshot(col, row):
		return 0
	var local_col := col - snapshot_rect.position.x
	var local_row := row - snapshot_rect.position.y
	return int(snapshot_fill[local_row * snapshot_rect.size.x + local_col])


func _contains_snapshot(col: int, row: int) -> bool:
	return snapshot_rect.has_point(Vector2i(col, row))


func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		hex_radius * 1.5 * float(col),
		hex_radius * sqrt(3.0) * (float(row) + float(col & 1) * 0.5)
	)


func _fill_line_y(fill: int) -> float:
	var half_height := _half_height()
	return lerpf(half_height, -half_height, float(fill) / 255.0)


func _half_height() -> float:
	return hex_radius * sqrt(3.0) * 0.5


func _left_boundary_x(local_y: float) -> float:
	return -hex_radius + absf(local_y) / sqrt(3.0)


func _right_boundary_x(local_y: float) -> float:
	return hex_radius - absf(local_y) / sqrt(3.0)


func _polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in polygon:
		total += point
	return total / float(maxi(1, polygon.size()))
