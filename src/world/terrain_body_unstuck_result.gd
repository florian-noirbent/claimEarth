## Position and velocity returned by the shared terrain unstuck solver.
class_name TerrainBodyUnstuckResult
extends RefCounted


var position := Vector2.ZERO
var velocity := Vector2.ZERO
var moved := false


func _init(position_value := Vector2.ZERO, velocity_value := Vector2.ZERO) -> void:
	position = position_value
	velocity = velocity_value
