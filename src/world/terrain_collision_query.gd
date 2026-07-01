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


func nearest_air_cell_center(position: Vector2, max_ring: int):
	if not is_configured() or max_ring < 0:
		return null
	var origin := HexMetrics.offset_for_world(position, hex_radius)
	var best_cell := Vector2i(-1, -1)
	var best_distance_sq := INF
	for ring in range(0, max_ring + 1):
		for row in range(origin.y - ring, origin.y + ring + 1):
			for col in range(origin.x - ring, origin.x + ring + 1):
				if maxi(absi(col - origin.x), absi(row - origin.y)) != ring:
					continue
				if not world.dimensions.is_in_bounds_offset(col, row):
					continue
				if world.get_committed_by_offset(col, row) != metadata.air_id:
					continue
				var center := HexMetrics.center_for_offset(col, row, hex_radius)
				var distance_sq := position.distance_squared_to(center)
				if distance_sq < best_distance_sq:
					best_distance_sq = distance_sq
					best_cell = Vector2i(col, row)
		if best_cell != Vector2i(-1, -1):
			return HexMetrics.center_for_offset(best_cell.x, best_cell.y, hex_radius)
	return null


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
