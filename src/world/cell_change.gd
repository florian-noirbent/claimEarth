## Describes one terrain ID and fill change at a world index.
class_name CellChange
extends RefCounted


var index: int
var previous_id: int
var next_id: int
var previous_fill: int
var next_fill: int


func _init(index_value: int = -1, previous_id_value: int = -1, next_id_value: int = -1, previous_fill_value: int = 255, next_fill_value: int = 255) -> void:
	index = index_value
	previous_id = previous_id_value
	next_id = next_id_value
	previous_fill = previous_fill_value
	next_fill = next_fill_value
