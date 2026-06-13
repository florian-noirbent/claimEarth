class_name GrappleAnchor
extends RefCounted


var cell := Vector2i(-1, -1)
var position := Vector2.ZERO


func _init(cell_value: Vector2i = Vector2i(-1, -1), position_value: Vector2 = Vector2.ZERO) -> void:
	cell = cell_value
	position = position_value
