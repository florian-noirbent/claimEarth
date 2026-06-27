## Converts flat-top hex coordinates into world positions and polygon geometry.
class_name HexMetrics
extends RefCounted


static func corners(radius: float = 16.0) -> PackedVector2Array:
	var half_height := radius * sqrt(3.0) * 0.5
	return PackedVector2Array([
		Vector2(radius * 0.5, -half_height),
		Vector2(radius, 0.0),
		Vector2(radius * 0.5, half_height),
		Vector2(-radius * 0.5, half_height),
		Vector2(-radius, 0.0),
		Vector2(-radius * 0.5, -half_height),
	])


static func center_for_offset(col: int, row: int, radius: float = 16.0) -> Vector2:
	var axial := HexCoord.from_offset_odd_q(col, row)
	return axial.to_world_position(radius)


static func offset_for_world(world_position: Vector2, radius: float = 16.0) -> Vector2i:
	var q := (2.0 / 3.0 * world_position.x) / radius
	var r := ((-1.0 / 3.0 * world_position.x) + (sqrt(3.0) / 3.0 * world_position.y)) / radius
	var rounded := _cube_round(Vector3(q, r, -q - r))
	return HexCoord.new(int(rounded.x), int(rounded.y)).to_offset_odd_q()


static func edge_corner_indices_for_direction(direction: int) -> Vector2i:
	const mapping := [
		Vector2i(1, 2),
		Vector2i(0, 1),
		Vector2i(5, 0),
		Vector2i(4, 5),
		Vector2i(3, 4),
		Vector2i(2, 3),
	]
	return mapping[wrapi(direction, 0, mapping.size())]


static func _cube_round(cube: Vector3) -> Vector3i:
	var rounded_x := roundi(cube.x)
	var rounded_y := roundi(cube.y)
	var rounded_z := roundi(cube.z)

	var diff_x := absf(float(rounded_x) - cube.x)
	var diff_y := absf(float(rounded_y) - cube.y)
	var diff_z := absf(float(rounded_z) - cube.z)

	if diff_x > diff_y and diff_x > diff_z:
		rounded_x = -rounded_y - rounded_z
	elif diff_y > diff_z:
		rounded_y = -rounded_x - rounded_z
	else:
		rounded_z = -rounded_x - rounded_y

	return Vector3i(rounded_x, rounded_y, rounded_z)
