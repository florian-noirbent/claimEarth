## Resource factory for a one-hex terrain transformation tool.
class_name TerrainToolItemActionFactory
extends ItemActionFactory


const TerrainToolItemActionScript = preload("res://src/items/terrain_tool_item_action.gd")

@export var transformations: Array[TerrainTransformRule] = []


func _init() -> void:
	action_name = "terrain_tool"


func create_action(definition: ItemDefinition):
	return TerrainToolItemActionScript.new(definition, self)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if transformations.is_empty():
		errors.append("terrain tool action factory requires at least one transform")
	for rule in transformations:
		if rule == null:
			errors.append("terrain tool action factory contains a null transform")
		else:
			for error in rule.validate():
				errors.append(error)
	return errors
