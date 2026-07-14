## Queries committed world terrain for grid-backed collision.
class_name TerrainCollisionQuery
extends RefCounted


var world: WorldGrid
var metadata: CompiledTerrainData
var hex_radius := 16.0
var _corners := PackedVector2Array()


func configure(world_value: WorldGrid, metadata_value: CompiledTerrainData, hex_radius_value: float) -> void:
	world = world_value
	metadata = metadata_value
	hex_radius = hex_radius_value
	_corners = HexMetrics.corners(hex_radius)


func is_configured() -> bool:
	return world != null and metadata != null


func is_solid_cell(col: int, row: int) -> bool:
	if not is_configured() or not world.dimensions.is_in_bounds_offset(col, row):
		return false
	return metadata.is_solid(
		world.get_committed_by_offset(col, row),
		world.get_committed_fill_by_offset(col, row)
	)


func circle_overlaps_solid(position: Vector2, radius: float) -> bool:
	return not circle_contacts(position, radius).is_empty()


func is_solid_at_world(position: Vector2) -> bool:
	var offset := HexMetrics.offset_for_world(position, hex_radius)
	return is_solid_cell(offset.x, offset.y)


func fill_weighted_viscosity_at_world(position: Vector2) -> float:
	if not is_configured():
		return 0.0
	var offset := HexMetrics.offset_for_world(position, hex_radius)
	if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return 0.0
	var cell_id := world.get_committed_by_offset(offset.x, offset.y)
	var fill_fraction := float(world.get_committed_fill_by_offset(offset.x, offset.y)) / 255.0
	return metadata.viscosity(cell_id) * fill_fraction


func convex_polygon_overlaps_solid(polygon: PackedVector2Array) -> bool:
	if not is_configured() or polygon.size() < 3:
		return false
	var bounds := _polygon_bounds(polygon)
	for cell in _candidate_cells_for_bounds(bounds):
		if not is_solid_cell(cell.x, cell.y):
			continue
		var hex_polygon := PackedVector2Array()
		var cell_center := HexMetrics.center_for_offset(cell.x, cell.y, hex_radius)
		for corner in _corners:
			hex_polygon.append(cell_center + corner)
		if _convex_polygons_overlap(polygon, hex_polygon):
			return true
	return false


func _candidate_cells_for_bounds(bounds: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if world == null:
		return cells
	var center := HexMetrics.offset_for_world(bounds.get_center(), hex_radius)
	var half_cols := ceili(bounds.size.x * 0.5 / maxf(hex_radius * 1.5, 1.0)) + 2
	var half_rows := ceili(bounds.size.y * 0.5 / maxf(hex_radius * sqrt(3.0), 1.0)) + 2
	var min_col := maxi(0, center.x - half_cols)
	var max_col := mini(world.dimensions.width - 1, center.x + half_cols)
	var min_row := maxi(0, center.y - half_rows)
	var max_row := mini(world.dimensions.depth - 1, center.y + half_rows)
	for row in range(min_row, max_row + 1):
		for col in range(min_col, max_col + 1):
			cells.append(Vector2i(col, row))
	return cells


func circle_contacts(position: Vector2, radius: float) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if not is_configured():
		return contacts
	for cell in _candidate_cells(position, radius):
		if not is_solid_cell(cell.x, cell.y):
			continue
		var contact := _circle_hex_contact(position, radius, cell)
		if bool(contact.get("colliding", false)):
			contacts.append(contact)
	return contacts


func support_contact(position: Vector2, radius: float, probe_distance: float) -> Dictionary:
	var probe_position := position + Vector2(0.0, maxf(probe_distance, 0.0))
	var best: Dictionary = {}
	for contact in circle_contacts(probe_position, radius):
		var normal := contact["normal"] as Vector2
		if normal.y >= -0.35:
			continue
		if best.is_empty() or float(contact["depth"]) > float(best["depth"]):
			best = contact
	return best


func nearest_clear_circle_air_center(position: Vector2, radius: float, max_ring: int):
	return _nearest_clear_air_center(position, max_ring, func(candidate: Vector2) -> bool:
		return not circle_overlaps_solid(candidate, radius)
	)


func nearest_clear_polygon_air_center(
	position: Vector2,
	local_polygon: PackedVector2Array,
	rotation_value: float,
	max_ring: int
):
	return _nearest_clear_air_center(position, max_ring, func(candidate: Vector2) -> bool:
		var transform := Transform2D(rotation_value, candidate)
		var world_polygon := PackedVector2Array()
		for point in local_polygon:
			world_polygon.append(transform * point)
		return not convex_polygon_overlaps_solid(world_polygon)
	)


func _nearest_clear_air_center(position: Vector2, max_ring: int, clearance_test: Callable):
	if not is_configured() or max_ring < 0 or not clearance_test.is_valid():
		return null
	var origin_offset := HexMetrics.offset_for_world(position, hex_radius)
	var origin_hex := HexCoord.from_offset_odd_q(origin_offset.x, origin_offset.y)
	for ring in range(max_ring + 1):
		var found := false
		var best_center := Vector2.ZERO
		for delta_q in range(-ring, ring + 1):
			var min_delta_r := maxi(-ring, -delta_q - ring)
			var max_delta_r := mini(ring, -delta_q + ring)
			for delta_r in range(min_delta_r, max_delta_r + 1):
				var candidate_hex := origin_hex.add(HexCoord.new(delta_q, delta_r))
				if origin_hex.distance_to(candidate_hex) != ring:
					continue
				var candidate_cell := candidate_hex.to_offset_odd_q()
				if not world.dimensions.is_in_bounds_offset(candidate_cell.x, candidate_cell.y):
					continue
				if world.get_committed_by_offset(candidate_cell.x, candidate_cell.y) != metadata.air_id:
					continue
				var candidate_center := HexMetrics.center_for_offset(candidate_cell.x, candidate_cell.y, hex_radius)
				if not bool(clearance_test.call(candidate_center)):
					continue
				if not found or _clearance_candidate_precedes(candidate_center, best_center, position):
					found = true
					best_center = candidate_center
		if found:
			return best_center
	return null


func _clearance_candidate_precedes(candidate: Vector2, current: Vector2, origin: Vector2) -> bool:
	var candidate_distance := origin.distance_squared_to(candidate)
	var current_distance := origin.distance_squared_to(current)
	if not is_equal_approx(candidate_distance, current_distance):
		return candidate_distance < current_distance
	if not is_equal_approx(candidate.y, current.y):
		return candidate.y < current.y
	return candidate.x < current.x


func _candidate_cells(position: Vector2, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if world == null:
		return cells
	var center := HexMetrics.offset_for_world(position, hex_radius)
	var search_radius := ceili((radius + hex_radius) / maxf(hex_radius * 0.75, 1.0)) + 2
	var min_col := maxi(0, center.x - search_radius)
	var max_col := mini(world.dimensions.width - 1, center.x + search_radius)
	var min_row := maxi(0, center.y - search_radius)
	var max_row := mini(world.dimensions.depth - 1, center.y + search_radius)
	for row in range(min_row, max_row + 1):
		for col in range(min_col, max_col + 1):
			cells.append(Vector2i(col, row))
	return cells


func _circle_hex_contact(position: Vector2, radius: float, cell: Vector2i) -> Dictionary:
	var center := HexMetrics.center_for_offset(cell.x, cell.y, hex_radius)
	var closest := _closest_point_on_polygon(position, center, _corners)
	var delta := position - closest
	var distance := delta.length()
	var inside := _point_in_polygon(position, center, _corners)
	if not inside and distance >= radius:
		return {"colliding": false}

	var normal := Vector2.UP
	if distance > 0.0001:
		normal = delta / distance
	else:
		var from_cell_center := position - center
		if from_cell_center.length_squared() > 0.0001:
			normal = from_cell_center.normalized()
	var depth := radius - distance
	if inside:
		depth = maxf(depth, radius)
	return {
		"colliding": true,
		"cell": cell,
		"normal": normal,
		"depth": maxf(depth, 0.0),
	}


func _closest_point_on_polygon(point: Vector2, polygon_center: Vector2, polygon: PackedVector2Array) -> Vector2:
	var best := polygon_center + polygon[0]
	var best_distance_sq := INF
	for index in range(polygon.size()):
		var start := polygon_center + polygon[index]
		var end := polygon_center + polygon[(index + 1) % polygon.size()]
		var candidate := _closest_point_on_segment(point, start, end)
		var distance_sq := point.distance_squared_to(candidate)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = candidate
	return best


func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var segment := end - start
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return start
	var t := clampf((point - start).dot(segment) / length_sq, 0.0, 1.0)
	return start + segment * t


func _point_in_polygon(point: Vector2, polygon_center: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous := polygon_center + polygon[polygon.size() - 1]
	for vertex in polygon:
		var current := polygon_center + vertex
		var crosses := (current.y > point.y) != (previous.y > point.y)
		if crosses:
			var denominator := previous.y - current.y
			if absf(denominator) <= 0.000001:
				previous = current
				continue
			var intersect_x := (previous.x - current.x) * (point.y - current.y) / denominator + current.x
			if point.x < intersect_x:
				inside = not inside
		previous = current
	return inside


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _convex_polygons_overlap(left: PackedVector2Array, right: PackedVector2Array) -> bool:
	return not _has_separating_axis(left, right) and not _has_separating_axis(right, left)


func _has_separating_axis(source: PackedVector2Array, other: PackedVector2Array) -> bool:
	for index in source.size():
		var edge := source[(index + 1) % source.size()] - source[index]
		if edge.length_squared() <= 0.000001:
			continue
		var axis := Vector2(-edge.y, edge.x).normalized()
		var source_range := _projection_range(source, axis)
		var other_range := _projection_range(other, axis)
		if source_range.y < other_range.x or other_range.y < source_range.x:
			return true
	return false


func _projection_range(polygon: PackedVector2Array, axis: Vector2) -> Vector2:
	var minimum := polygon[0].dot(axis)
	var maximum := minimum
	for index in range(1, polygon.size()):
		var projection := polygon[index].dot(axis)
		minimum = minf(minimum, projection)
		maximum = maxf(maximum, projection)
	return Vector2(minimum, maximum)
