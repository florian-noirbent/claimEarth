## Owns a run's remaining unique perk pool and compiled selected-perk modifiers.
class_name PerkPool
extends RefCounted


var _registry: PerkRegistry
var _remaining_ids: Array[int] = []
var _selected_ids: Array[int] = []
var _snapshot := PerkModifierSnapshot.new()


func configure(registry: PerkRegistry) -> void:
	_registry = registry
	_remaining_ids.clear()
	_selected_ids.clear()
	if registry != null:
		for definition in registry.all_definitions():
			_remaining_ids.append(definition.stable_id)
	_recompile()


func draw_choices(seed_value: int, requested_count: int) -> Array[PerkDefinition]:
	var candidates := _remaining_ids.duplicate()
	var result: Array[PerkDefinition] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	while result.size() < requested_count and not candidates.is_empty():
		var index := rng.randi_range(0, candidates.size() - 1)
		result.append(_registry.get_definition(candidates[index]))
		candidates.remove_at(index)
	return result


func select(stable_id: int) -> bool:
	if _registry == null or not _remaining_ids.has(stable_id):
		return false
	var selected := _registry.get_definition(stable_id)
	if selected == null:
		return false
	_remaining_ids.erase(stable_id)
	_selected_ids.append(stable_id)
	if not selected.exclusion_group.is_empty():
		for candidate_id in _remaining_ids.duplicate():
			var candidate := _registry.get_definition(candidate_id)
			if candidate != null and candidate.exclusion_group == selected.exclusion_group:
				_remaining_ids.erase(candidate_id)
	_recompile()
	return true


func selected_definitions() -> Array[PerkDefinition]:
	var result: Array[PerkDefinition] = []
	for stable_id in _selected_ids:
		var definition := _registry.get_definition(stable_id)
		if definition != null:
			result.append(definition)
	return result


func modifiers() -> PerkModifierSnapshot:
	return _snapshot


func remaining_count() -> int:
	return _remaining_ids.size()


func _recompile() -> void:
	var builder := PerkModifierBuilder.new()
	var cancelled := {}
	for definition in selected_definitions():
		for effect in definition.effects:
			if effect != null:
				for tag in effect.cancellation_tags():
					cancelled[tag] = true
	for definition in selected_definitions():
		for effect in definition.effects:
			if effect != null and not cancelled.has(effect.contribution_tag):
				effect.apply(builder)
	_snapshot = builder.build()
