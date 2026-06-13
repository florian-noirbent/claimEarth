class_name CellChange
extends RefCounted


var index: int
var previous_id: int
var next_id: int


func _init(index_value: int = -1, previous_id_value: int = -1, next_id_value: int = -1) -> void:
	index = index_value
	previous_id = previous_id_value
	next_id = next_id_value
