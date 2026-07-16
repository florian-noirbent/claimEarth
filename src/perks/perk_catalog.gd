@tool
## Resource catalog of perks available to a run.
class_name PerkCatalog
extends Resource


@export var definitions: Array[PerkDefinition] = []


func validate() -> PackedStringArray:
	var registry := PerkRegistry.new()
	registry.try_configure(self)
	return registry.validation_errors
