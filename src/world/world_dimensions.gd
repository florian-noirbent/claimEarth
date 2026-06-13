class_name WorldDimensions
extends RefCounted


var width: int
var depth: int


func _init(width_value: int, depth_value: int) -> void:
	assert(width_value > 0)
	assert(depth_value > 0)
	width = width_value
	depth = depth_value


func cell_count() -> int:
	return width * depth


func is_in_bounds_offset(col: int, row: int) -> bool:
	return col >= 0 and col < width and row >= 0 and row < depth


func is_in_bounds_axial(coord: HexCoord) -> bool:
	var offset := coord.to_offset_odd_q()
	return is_in_bounds_offset(offset.x, offset.y)


func offset_to_index(col: int, row: int) -> int:
	assert(is_in_bounds_offset(col, row), "Offset out of bounds: (%d,%d)" % [col, row])
	return row * width + col


func axial_to_index(coord: HexCoord) -> int:
	var offset := coord.to_offset_odd_q()
	return offset_to_index(offset.x, offset.y)


func index_to_offset(index: int) -> Vector2i:
	assert(index >= 0 and index < cell_count(), "Index out of bounds: %d" % index)
	return Vector2i(index % width, int(index / width))


func index_to_axial(index: int) -> HexCoord:
	var offset := index_to_offset(index)
	return HexCoord.from_offset_odd_q(offset.x, offset.y)
