class_name ItemDefinition
extends Resource


@export_range(0, 255) var stable_id := 0
@export var display_name := ""
@export var icon: Texture2D
@export var starting_inventory := 0
@export var action_factory: ItemActionFactory


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("item[%d] display_name is required" % stable_id)
	if icon == null:
		errors.append("item[%d:%s] icon is required" % [stable_id, display_name])
	if starting_inventory < 0:
		errors.append("item[%d] starting_inventory must be >= 0" % stable_id)
	if action_factory == null:
		errors.append("item[%d:%s] is missing action_factory" % [stable_id, display_name])
	return errors
