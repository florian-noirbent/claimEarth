## Resource factory for bottles that deposit one configured liquid on impact.
class_name FluidBottleItemActionFactory
extends ItemActionFactory


const FluidBottleItemActionScript = preload("res://src/items/fluid_bottle_item_action.gd")

@export var deposited_terrain: TerrainDefinition
## Match the small bomb's ballistic launch while retaining bottle-on-impact resolution.
@export var throw_distance_hint := 100.0
@export var fuse_seconds := 10.0
@export var gravity := 880.0
@export var thrower_velocity_influence := 0.15
@export var projectile_color := Color(0.25, 0.62, 0.95, 1.0)
@export var projectile_outline_color := Color(0.04, 0.12, 0.25, 1.0)
@export var projectile_points := PackedVector2Array([-5, -8, 5, -8, 6, 6, 0, 9, -6, 6])


func _init() -> void:
	action_name = "fluid_bottle"


func create_action(definition: ItemDefinition):
	return FluidBottleItemActionScript.new(definition, self)


func validate() -> PackedStringArray:
	return PackedStringArray() if deposited_terrain != null else PackedStringArray(["fluid bottle action factory requires deposited terrain"])
