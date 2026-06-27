## Motion behavior defaults for liquids that flow through fill transfer.
class_name LiquidMotionBehavior
extends TerrainMotionBehavior


func _init() -> void:
	behavior_name = "liquid"
	can_fall = true
	can_side_down = true
	can_side_up = true
	fall_rate = 255
	side_down_rate = 255
	side_up_rate = 255
	min_fill_difference = 0
