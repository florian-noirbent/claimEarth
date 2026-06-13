class_name HexMetrics
extends RefCounted


static func corners(radius: float = 16.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(60.0 * index)
		result.append(Vector2(cos(angle), sin(angle)) * radius)
	return result


static func center_for_offset(col: int, row: int, radius: float = 16.0) -> Vector2:
	var axial := HexCoord.from_offset_odd_q(col, row)
	return axial.to_world_position(radius)
