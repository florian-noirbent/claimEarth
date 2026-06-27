@tool
## Describes one generation pass type exposed by the tuning UI.
class_name GenerationPassCatalogEntry
extends Resource


@export var label := ""
@export var pass_script: Script


func get_picker_label() -> String:
	if not label.is_empty():
		return label
	var pass_resource := instantiate_pass()
	if pass_resource != null:
		return pass_resource.get_pass_type_name()
	return "Generation Pass"


func instantiate_pass() -> Resource:
	if pass_script == null:
		return null
	var instance = pass_script.new()
	return instance as Resource
