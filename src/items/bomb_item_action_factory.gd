class_name BombItemActionFactory
extends ItemActionFactory

const BombItemActionScript = preload("res://src/items/bomb_item_action.gd")

@export var blast_radius := 0
@export var lethal_radius := 0
@export var throw_distance_hint := 0.0
@export var fuse_seconds := 0.8
@export var gravity := 850.0
@export var thrower_velocity_influence := 0.15
@export var projectile_color := Color(0.92, 0.48, 0.18, 1)


func _init() -> void:
	action_name = "bomb"


func create_action(definition: ItemDefinition):
	return BombItemActionScript.new(definition, self)
