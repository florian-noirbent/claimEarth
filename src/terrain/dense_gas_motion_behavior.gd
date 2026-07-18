## Motion behavior for a heavy gas that settles at its normal pressure.
class_name DenseGasMotionBehavior
extends TerrainMotionBehavior


func _init() -> void:
	behavior_name = "dense_gas"
	can_fall = true
	can_side_down = true
	can_side_up = true
	fall_rate = 127
	side_down_rate = 127
	side_up_rate = 127
