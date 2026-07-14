class_name ExcavatorItemActionFactory
extends ItemActionFactory
const Action = preload("res://src/items/excavator_item_action.gd")
@export var explosion_definition: ExplosionDefinition
@export var throw_distance_hint := 100.0
@export var gravity := 880.0
@export var duration_seconds := 10.0
@export var tick_seconds := 1.0
@export var visual_texture: Texture2D
@export var body_points := PackedVector2Array([-11, -9, 11, -9, 11, 10, -11, 10])
@export var body_color := Color(0.9, 0.55, 0.12, 1.0)
@export var body_outline_color := Color(0.16, 0.08, 0.02, 1.0)
func _init() -> void: action_name = "excavator"
func create_action(definition: ItemDefinition): return Action.new(definition, self)
func validate() -> PackedStringArray: return explosion_definition.validate() if explosion_definition != null else PackedStringArray(["excavator requires explosion"])
