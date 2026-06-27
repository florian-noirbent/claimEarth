## Accumulates changed indices into a rectangular dirty region.
class_name DirtyRegion
extends RefCounted


var _initialized := false
var _min_col := 0
var _min_row := 0
var _max_col := 0
var _max_row := 0


func mark_offset(col: int, row: int) -> void:
	if not _initialized:
		_initialized = true
		_min_col = col
		_max_col = col
		_min_row = row
		_max_row = row
		return

	_min_col = mini(_min_col, col)
	_max_col = maxi(_max_col, col)
	_min_row = mini(_min_row, row)
	_max_row = maxi(_max_row, row)


func mark_rect(rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	mark_offset(rect.position.x, rect.position.y)
	mark_offset(rect.end.x - 1, rect.end.y - 1)


func is_empty() -> bool:
	return not _initialized


func clear() -> void:
	_initialized = false


func as_rect() -> Rect2i:
	if is_empty():
		return Rect2i()
	return Rect2i(
		Vector2i(_min_col, _min_row),
		Vector2i(_max_col - _min_col + 1, _max_row - _min_row + 1)
	)
