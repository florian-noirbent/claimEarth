## Resource-configured source-to-target terrain mutation for a hand tool.
class_name TerrainTransformRule
extends Resource


@export var source: TerrainDefinition
@export var target: TerrainDefinition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if source == null:
		errors.append("terrain transform source is required")
	if target == null:
		errors.append("terrain transform target is required")
	return errors
