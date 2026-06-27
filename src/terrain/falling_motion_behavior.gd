## Motion behavior defaults for falling granular terrain.
class_name FallingMotionBehavior
extends TerrainMotionBehavior


func _init() -> void:
	behavior_name = "falling"
	can_fall = true
	can_side_down = true
	can_side_up = false
	displaces_passable_moving_on_fall = true
	fall_rate = 255
	side_down_rate = 48
	side_up_rate = 0
	min_fill_difference = 0
