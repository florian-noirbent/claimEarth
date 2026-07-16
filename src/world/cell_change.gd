## Describes one terrain ID and quantity change at a world index.
class_name CellChange
extends RefCounted


var index: int
var previous_id: int
var next_id: int
var previous_quantity: int
var next_quantity: int
var previous_secondary_id: int
var next_secondary_id: int
var previous_secondary_quantity: int
var next_secondary_quantity: int


func _init(
	index_value: int = -1,
	previous_id_value: int = -1,
	next_id_value: int = -1,
	previous_quantity_value: int = 127,
	next_quantity_value: int = 127,
	previous_secondary_id_value: int = 0,
	next_secondary_id_value: int = 0,
	previous_secondary_quantity_value: int = 0,
	next_secondary_quantity_value: int = 0
) -> void:
	index = index_value
	previous_id = previous_id_value
	next_id = next_id_value
	previous_quantity = previous_quantity_value
	next_quantity = next_quantity_value
	previous_secondary_id = previous_secondary_id_value
	next_secondary_id = next_secondary_id_value
	previous_secondary_quantity = previous_secondary_quantity_value
	next_secondary_quantity = next_secondary_quantity_value
