## Position and velocity returned by the shared terrain unstuck solver.
class_name TerrainBodyUnstuckResult
extends RefCounted


var position := Vector2.ZERO
var velocity := Vector2.ZERO
var velocity_change := Vector2.ZERO
## True when the body overlapped solid terrain, whether or not an escape was found.
var overlapping := false
var moved := false


func _init(position_value := Vector2.ZERO, velocity_value := Vector2.ZERO) -> void:
	position = position_value
	velocity = velocity_value
