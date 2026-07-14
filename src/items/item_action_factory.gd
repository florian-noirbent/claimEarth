## Base resource contract for creating item actions from definitions.
class_name ItemActionFactory
extends Resource


@export var action_name := ""


func create_action(_definition: ItemDefinition):
	return null


func validate() -> PackedStringArray:
	return PackedStringArray()
