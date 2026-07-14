## Tracks item counts and current selection for a run.
class_name ItemInventory
extends RefCounted


var _counts := {}
var _ordered_definitions: Array[ItemDefinition] = []
var _selected_index := 0


func configure(item_registry: ItemRegistry) -> void:
	_ordered_definitions = item_registry.all_definitions()
	reset()


func reset() -> void:
	_counts.clear()
	for definition in _ordered_definitions:
		_counts[definition.stable_id] = definition.starting_inventory
	_selected_index = 0


func definitions() -> Array[ItemDefinition]:
	return _ordered_definitions.duplicate()


func selected_definition() -> ItemDefinition:
	if _ordered_definitions.is_empty():
		return null
	return _ordered_definitions[clampi(_selected_index, 0, _ordered_definitions.size() - 1)]


func select_index(index: int) -> void:
	if _ordered_definitions.is_empty():
		_selected_index = 0
		return
	_selected_index = clampi(index, 0, _ordered_definitions.size() - 1)


func count_for(definition: ItemDefinition) -> int:
	if definition == null:
		return 0
	return int(_counts.get(definition.stable_id, 0))


func can_consume(definition: ItemDefinition) -> bool:
	return count_for(definition) > 0


func consume(definition: ItemDefinition) -> bool:
	if not can_consume(definition):
		return false
	_counts[definition.stable_id] = count_for(definition) - 1
	return true


func restore(definition: ItemDefinition, amount: int = 1) -> void:
	add(definition, amount)


func add(definition: ItemDefinition, amount: int) -> bool:
	if definition == null or amount <= 0 or not _counts.has(definition.stable_id):
		return false
	_counts[definition.stable_id] = count_for(definition) + amount
	return true
