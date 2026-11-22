## Resource factory for a temporary illuminated thrown flare.
class_name FlareItemActionFactory
extends ItemActionFactory


const FlareItemActionScript = preload("res://src/items/flare_item_action.gd")

@export var light_definition: WorldLightSourceDefinition
@export var throw_distance_hint := 150.0
@export var fuse_seconds := 10.0
@export var gravity := 850.0
@export var thrower_velocity_influence := 0.15
@export var bounce_damping := 0.55
@export var horizontal_bounce_damping := 0.72
@export var projectile_color := Color(1.0, 0.72, 0.2, 1.0)
@export var projectile_outline_color := Color(0.2, 0.08, 0.02, 1.0)
@export var projectile_points := PackedVector2Array([-4, -8, 4, -8, 6, 7, -6, 7])
## Mirrors the flying icon when it heads left, so its up side stays on top.
@export var projectile_sprite_mirrors_with_heading := true
## Speed in px/s below which the icon keeps its flight orientation instead of turning with
## every small bounce.
@export_range(0.0, 1000.0, 1.0) var projectile_sprite_settle_speed := 90.0


func _init() -> void:
	action_name = "flare"


func create_action(definition: ItemDefinition):
	return FlareItemActionScript.new(definition, self)


func validate() -> PackedStringArray:
	return light_definition.validate() if light_definition != null else PackedStringArray(["flare action factory requires a light definition"])
