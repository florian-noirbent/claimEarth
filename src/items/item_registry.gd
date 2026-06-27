## Validates and indexes item definitions by stable ID.
class_name ItemRegistry
extends RefCounted


var _definitions_by_id: Dictionary = {}
var _ordered_definitions: Array[ItemDefinition] = []
var validation_errors := PackedStringArray()


func try_configure(catalog: ItemCatalog) -> bool:
	_definitions_by_id.clear()
	_ordered_definitions.clear()
	validation_errors = PackedStringArray()

	if catalog == null:
		validation_errors.append("item catalog is required")
		return false
	if catalog.definitions.is_empty():
		validation_errors.append("item catalog must contain definitions")
		return false

	for definition in catalog.definitions:
		if definition == null:
			validation_errors.append("item catalog contains a null definition")
			continue
		for error in definition.validate():
			validation_errors.append(error)
		if _definitions_by_id.has(definition.stable_id):
			validation_errors.append("duplicate item stable_id %d" % definition.stable_id)
			continue
		_definitions_by_id[definition.stable_id] = definition
		_ordered_definitions.append(definition)

	_ordered_definitions.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool:
		return a.stable_id < b.stable_id
	)

	return validation_errors.is_empty()


func is_valid() -> bool:
	return validation_errors.is_empty()


func get_definition(stable_id: int) -> ItemDefinition:
	return _definitions_by_id.get(stable_id) as ItemDefinition


func has_definition(stable_id: int) -> bool:
	return _definitions_by_id.has(stable_id)


func all_definitions() -> Array[ItemDefinition]:
	return _ordered_definitions.duplicate()


func count() -> int:
	return _ordered_definitions.size()
