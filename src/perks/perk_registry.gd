## Validates and indexes perk definitions by stable ID.
class_name PerkRegistry
extends RefCounted


var _definitions_by_id: Dictionary = {}
var _ordered_definitions: Array[PerkDefinition] = []
var validation_errors := PackedStringArray()


func try_configure(catalog: PerkCatalog) -> bool:
	_definitions_by_id.clear()
	_ordered_definitions.clear()
	validation_errors = PackedStringArray()
	if catalog == null:
		validation_errors.append("perk catalog is required")
		return false
	if catalog.definitions.is_empty():
		validation_errors.append("perk catalog must contain definitions")
		return false
	for definition in catalog.definitions:
		if definition == null:
			validation_errors.append("perk catalog contains a null definition")
			continue
		for error in definition.validate():
			validation_errors.append(error)
		if _definitions_by_id.has(definition.stable_id):
			validation_errors.append("duplicate perk stable_id %d" % definition.stable_id)
			continue
		_definitions_by_id[definition.stable_id] = definition
		_ordered_definitions.append(definition)
	_ordered_definitions.sort_custom(func(a: PerkDefinition, b: PerkDefinition) -> bool: return a.stable_id < b.stable_id)
	return validation_errors.is_empty()


func get_definition(stable_id: int) -> PerkDefinition:
	return _definitions_by_id.get(stable_id) as PerkDefinition


func all_definitions() -> Array[PerkDefinition]:
	return _ordered_definitions.duplicate()
