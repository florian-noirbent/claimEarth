class_name FlagItemActionFactory
extends ItemActionFactory

const FlagItemActionScript = preload("res://src/items/flag_item_action.gd")

@export var ignores_water := true
@export var destroyed_by_lava := true
@export var throw_distance_hint := 5.0
@export var gravity := 850.0
@export var thrower_velocity_influence := 0.15
@export var projectile_color := Color(0.96, 0.85, 0.22, 1)
@export var projectile_outline_color := Color(0.16, 0.08, 0.04, 1)
@export var projectile_points := PackedVector2Array([-4, -10, 4, -10, 4, 10, -4, 10])


func _init() -> void:
	action_name = "flag"


func create_action(definition: ItemDefinition):
	return FlagItemActionScript.new(definition, self)
