class_name FlagItemActionFactory
extends ItemActionFactory


@export var ignores_water := true
@export var destroyed_by_lava := true


func _init() -> void:
	action_name = "flag"
