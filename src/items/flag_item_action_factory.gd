## Resource factory for flag item actions and projectile tuning.
class_name FlagItemActionFactory
extends ItemActionFactory

const FlagItemActionScript = preload("res://src/items/flag_item_action.gd")

@export var ignores_water := true
@export var destructive_terrain_tags := PackedStringArray(["lava", "acid"])
@export var throw_distance_hint := 5.0
@export var gravity := 850.0
@export var thrower_velocity_influence := 0.15
@export var projectile_color := Color(0.96, 0.85, 0.22, 1)
@export var projectile_outline_color := Color(0.16, 0.08, 0.04, 1)
@export var projectile_points := PackedVector2Array([-4, -10, 4, -10, 4, 10, -4, 10])
## World scale of the item icon drawn as the projectile.
@export_range(0.01, 2.0, 0.01) var projectile_sprite_scale := 0.3
## Turns the upright icon so the pole tip leads the flight direction.
@export_range(-180.0, 180.0, 1.0) var projectile_sprite_rotation_degrees := -90.0
## Icon-pixel offset that puts the pole, not the banner, on the flight path.
@export var projectile_sprite_offset := Vector2(26.0, 0.0)
## Mirrors the flying icon when it heads left, so its up side stays on top.
@export var projectile_sprite_mirrors_with_heading := true


func _init() -> void:
	action_name = "flag"


func create_action(definition: ItemDefinition):
	return FlagItemActionScript.new(definition, self)
