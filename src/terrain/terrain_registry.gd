class_name TerrainRegistry
extends RefCounted


var _definitions_by_id: Dictionary = {}
var _definitions_by_name: Dictionary = {}
var _ordered_definitions: Array[TerrainDefinition] = []
var validation_errors := PackedStringArray()


func try_configure(catalog: TerrainCatalog) -> bool:
	_definitions_by_id.clear()
	_definitions_by_name.clear()
	_ordered_definitions.clear()
	validation_errors = PackedStringArray()

	if catalog == null:
		validation_errors.append("terrain catalog is required")
		return false
	if catalog.definitions.is_empty():
		validation_errors.append("terrain catalog must contain definitions")
		return false

	for definition in catalog.definitions:
		if definition == null:
			validation_errors.append("terrain catalog contains a null definition")
			continue
		for error in definition.validate():
			validation_errors.append(error)
		if _definitions_by_id.has(definition.stable_id):
			validation_errors.append("duplicate terrain stable_id %d" % definition.stable_id)
			continue
		_definitions_by_id[definition.stable_id] = definition
		_definitions_by_name[definition.display_name] = definition
		_ordered_definitions.append(definition)

	_ordered_definitions.sort_custom(func(a: TerrainDefinition, b: TerrainDefinition) -> bool:
		return a.stable_id < b.stable_id
	)
	var empty_count := 0
	var contact_product_count := 0
	for definition in _ordered_definitions:
		if definition.is_empty_space:
			empty_count += 1
		if definition.is_liquid_contact_product:
			contact_product_count += 1
	if empty_count != 1:
		validation_errors.append("terrain catalog must define exactly one empty-space terrain")
	if contact_product_count != 1:
		validation_errors.append("terrain catalog must define exactly one liquid-contact product")

	return validation_errors.is_empty()


func is_valid() -> bool:
	return validation_errors.is_empty()


func get_definition(stable_id: int) -> TerrainDefinition:
	return _definitions_by_id.get(stable_id) as TerrainDefinition


func stable_id_for_name(terrain_name: String) -> int:
	var definition := _definitions_by_name.get(terrain_name) as TerrainDefinition
	return definition.stable_id if definition != null else -1


func has_definition(stable_id: int) -> bool:
	return _definitions_by_id.has(stable_id)


func all_definitions() -> Array[TerrainDefinition]:
	return _ordered_definitions.duplicate()


func count() -> int:
	return _ordered_definitions.size()
