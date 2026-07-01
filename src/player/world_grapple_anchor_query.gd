## Queries hookable terrain from committed world data for grapple attachment.
class_name WorldGrappleAnchorQuery
extends GrappleAnchorQuery


var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _hex_radius := 16.0
var _probe_step := 8.0
var _max_range := 220.0
var _corners := PackedVector2Array()


func configure(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	hex_radius: float,
	probe_step: float,
	max_range: float
) -> void:
	_world = world
	_terrain_registry = terrain_registry
	_hex_radius = hex_radius
	_probe_step = probe_step
	_max_range = max_range
	_corners = HexMetrics.corners(hex_radius)


func find_anchor(origin: Vector2, target: Vector2) -> GrappleAnchor:
	if _world == null or _terrain_registry == null:
		return null

	var delta := target - origin
	var distance := delta.length()
	if distance <= 0.001:
		return null

	var direction := delta / distance
	var probe_distance := minf(distance, _max_range)
	var previous_position := origin
	var travel := _probe_step
	while travel <= probe_distance:
		var sample_position := origin + direction * travel
		var cell := HexMetrics.offset_for_world(sample_position, _hex_radius)
		var anchor := _anchor_for_cell(cell, previous_position, sample_position)
		if anchor != null:
			return anchor
		previous_position = sample_position
		travel += _probe_step

	var final_position := origin + direction * probe_distance
	return _anchor_for_cell(
		HexMetrics.offset_for_world(final_position, _hex_radius),
		previous_position,
		final_position
	)


func is_anchor_valid(anchor: GrappleAnchor) -> bool:
	if anchor == null or _world == null or _terrain_registry == null:
		return false
	return _is_hookable_cell(anchor.cell)


func _anchor_for_cell(cell: Vector2i, segment_start: Vector2, segment_end: Vector2) -> GrappleAnchor:
	if not _is_hookable_cell(cell):
		return null
	return GrappleAnchor.new(cell, _contact_point_for_cell(cell, segment_start, segment_end))


func _is_hookable_cell(cell: Vector2i) -> bool:
	if _world == null or _terrain_registry == null:
		return false
	if not _world.dimensions.is_in_bounds_offset(cell.x, cell.y):
		return false

	var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(cell.x, cell.y))
	if definition == null or not definition.is_hookable:
		return false

	return true


func _contact_point_for_cell(cell: Vector2i, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var center := HexMetrics.center_for_offset(cell.x, cell.y, _hex_radius)
	var best_point := Vector2.ZERO
	var best_t := INF
	for index in range(_corners.size()):
		var edge_start := center + _corners[index]
		var edge_end := center + _corners[(index + 1) % _corners.size()]
		var intersection := _segment_intersection(segment_start, segment_end, edge_start, edge_end)
		if intersection.is_empty():
			continue
		var t := float(intersection["t"])
		if t < best_t:
			best_t = t
			best_point = intersection["point"] as Vector2
	if best_t < INF:
		return best_point

	return _closest_point_on_polygon(segment_end, center)


func _segment_intersection(start_a: Vector2, end_a: Vector2, start_b: Vector2, end_b: Vector2) -> Dictionary:
	var direction_a := end_a - start_a
	var direction_b := end_b - start_b
	var denominator := direction_a.cross(direction_b)
	if absf(denominator) <= 0.000001:
		return {}

	var delta := start_b - start_a
	var t := delta.cross(direction_b) / denominator
	var u := delta.cross(direction_a) / denominator
	if t < -0.000001 or t > 1.000001 or u < -0.000001 or u > 1.000001:
		return {}

	return {
		"point": start_a + direction_a * clampf(t, 0.0, 1.0),
		"t": clampf(t, 0.0, 1.0),
	}


func _closest_point_on_polygon(point: Vector2, polygon_center: Vector2) -> Vector2:
	var best := polygon_center + _corners[0]
	var best_distance_sq := INF
	for index in range(_corners.size()):
		var start := polygon_center + _corners[index]
		var end := polygon_center + _corners[(index + 1) % _corners.size()]
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
