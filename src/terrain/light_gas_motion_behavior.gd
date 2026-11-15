## Motion behavior for a buoyant gas that rises and pools under ceilings.
class_name LightGasMotionBehavior
extends TerrainMotionBehavior


func _init() -> void:
	behavior_name = "light_gas"
	# Light gases run the liquid rules upside down. Flags and rates keep their world
	# direction: side-up is the free diagonal rise, side-down the pressured descent.
	can_side_down = true
	can_side_up = true
	# The packed vertical transfer-rate channel is shared by falling and rising media.
	fall_rate = 127
	side_down_rate = 127
	side_up_rate = 127
