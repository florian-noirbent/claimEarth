## Resource factory for bomb item actions and projectile tuning.
class_name BombItemActionFactory
extends ItemActionFactory

const BombItemActionScript = preload("res://src/items/bomb_item_action.gd")

@export var explosion_definition: ExplosionDefinition
@export var throw_distance_hint := 0.0
@export var fuse_seconds := 0.8
@export var gravity := 850.0
@export var thrower_velocity_influence := 0.15
@export var bounce_damping := 0.55
@export var horizontal_bounce_damping := 0.72
@export var projectile_color := Color(0.92, 0.48, 0.18, 1)
@export var projectile_outline_color := Color(0.16, 0.08, 0.04, 1)
@export var projectile_points := PackedVector2Array([-7, -7, 7, -7, 7, 7, -7, 7])
## World scale of the item icon drawn as the projectile.
@export_range(0.01, 2.0, 0.01) var projectile_sprite_scale := 0.3
## Mirrors the flying icon when it heads left, so its up side stays on top.
@export var projectile_sprite_mirrors_with_heading := true
## Speed in px/s below which the icon keeps its flight orientation instead of turning with
## every small bounce.
@export_range(0.0, 1000.0, 1.0) var projectile_sprite_settle_speed := 90.0


func _init() -> void:
	action_name = "bomb"


func create_action(definition: ItemDefinition):
	return BombItemActionScript.new(definition, self)


func validate() -> PackedStringArray:
	if explosion_definition == null:
		return PackedStringArray(["bomb action factory requires an explosion definition"])
	return explosion_definition.validate()
