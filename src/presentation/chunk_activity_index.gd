class_name ChunkActivityIndex
extends RefCounted


var dimensions: WorldDimensions
var chunk_width: int
var chunk_height: int
var _dirty_chunks: Dictionary = {}


func _init(dimensions_value: WorldDimensions, chunk_width_value: int = 20, chunk_height_value: int = 32) -> void:
	dimensions = dimensions_value
	chunk_width = chunk_width_value
	chunk_height = chunk_height_value


func total_chunk_columns() -> int:
	return int(ceil(float(dimensions.width) / float(chunk_width)))


func total_chunk_rows() -> int:
	return int(ceil(float(dimensions.depth) / float(chunk_height)))


func total_chunk_count() -> int:
	return total_chunk_columns() * total_chunk_rows()


func chunk_coord_for_offset(col: int, row: int) -> Vector2i:
	return Vector2i(int(col / chunk_width), int(row / chunk_height))


func chunk_rect(chunk_coord: Vector2i) -> Rect2i:
	var start := Vector2i(chunk_coord.x * chunk_width, chunk_coord.y * chunk_height)
	var size := Vector2i(
		mini(chunk_width, dimensions.width - start.x),
		mini(chunk_height, dimensions.depth - start.y)
	)
	return Rect2i(start, size)


func mark_dirty_rect(rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var start_chunk := chunk_coord_for_offset(rect.position.x, rect.position.y)
	var end_chunk := chunk_coord_for_offset(rect.end.x - 1, rect.end.y - 1)
	for chunk_row in range(start_chunk.y, end_chunk.y + 1):
		for chunk_col in range(start_chunk.x, end_chunk.x + 1):
			_dirty_chunks[Vector2i(chunk_col, chunk_row)] = true


func mark_all_dirty() -> void:
	for chunk_row in range(total_chunk_rows()):
		for chunk_col in range(total_chunk_columns()):
			_dirty_chunks[Vector2i(chunk_col, chunk_row)] = true


func consume_dirty_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for chunk_coord_variant in _dirty_chunks.keys():
		result.append(chunk_coord_variant as Vector2i)
	_dirty_chunks.clear()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return result


func visible_chunks_for_depth_window(start_row: int, row_count: int) -> Array[Vector2i]:
	var clamped_start := maxi(0, start_row)
	var end_row := mini(dimensions.depth, start_row + row_count)
	var start_chunk_row := int(clamped_start / chunk_height)
	var end_chunk_row := int(max(0, end_row - 1) / chunk_height)
	var result: Array[Vector2i] = []
	for chunk_row in range(start_chunk_row, end_chunk_row + 1):
		for chunk_col in range(total_chunk_columns()):
			result.append(Vector2i(chunk_col, chunk_row))
	return result
