class_name BombItemActionFactory
extends ItemActionFactory


@export var blast_radius := 0
@export var throw_distance_hint := 0.0


func _init() -> void:
	action_name = "bomb"
