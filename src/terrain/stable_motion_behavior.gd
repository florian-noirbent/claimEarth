## Motion behavior for terrain that does not move in simulation.
class_name StableMotionBehavior
extends TerrainMotionBehavior


func _init() -> void:
	behavior_name = "stable"
	can_fall = false
	can_side_down = false
	can_side_up = false
