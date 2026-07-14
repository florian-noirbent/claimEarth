## Defines item identity, inventory tuning, UI presentation, and action factory.
class_name ItemDefinition
extends Resource


enum CountDisplay {
	INTEGER,
	CEILING,
}


@export_range(0, 255) var stable_id := 0
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var starting_inventory := 0.0
@export var count_display := CountDisplay.INTEGER
@export var action_factory: ItemActionFactory


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("item[%d] display_name is required" % stable_id)
	if description.is_empty():
		errors.append("item[%d:%s] description is required" % [stable_id, display_name])
	if icon == null:
		errors.append("item[%d:%s] icon is required" % [stable_id, display_name])
	if starting_inventory < 0:
		errors.append("item[%d] starting_inventory must be >= 0" % stable_id)
	if action_factory == null:
		errors.append("item[%d:%s] is missing action_factory" % [stable_id, display_name])
	else:
		for error in action_factory.validate():
			errors.append("item[%d:%s] action: %s" % [stable_id, display_name, error])
	return errors
