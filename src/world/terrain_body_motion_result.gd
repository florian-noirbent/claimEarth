## Result returned by grid-based circular terrain body movement.
class_name TerrainBodyMotionResult
extends RefCounted


var position := Vector2.ZERO
var velocity := Vector2.ZERO
var grounded := false
var collided := false
var floor_normal := Vector2.UP
var hit_normals: Array[Vector2] = []


func _init(
	position_value: Vector2 = Vector2.ZERO,
	velocity_value: Vector2 = Vector2.ZERO,
	grounded_value: bool = false
) -> void:
	position = position_value
	velocity = velocity_value
	grounded = grounded_value
