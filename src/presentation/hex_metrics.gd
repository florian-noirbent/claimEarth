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
