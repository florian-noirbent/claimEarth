## Owns the selected perk set and exposes compiled runtime modifiers for one run.
class_name RunPerkController
extends Node


signal perks_changed(perks: Array)
signal modifiers_changed(modifiers: PerkModifierSnapshot)

@export var perk_catalog: PerkCatalog

var _registry := PerkRegistry.new()
var _pool := PerkPool.new()


func configure(catalog: PerkCatalog = perk_catalog) -> bool:
	perk_catalog = catalog
	if not _registry.try_configure(perk_catalog):
		return false
	_pool.configure(_registry)
	_emit_changed()
	return true


func reset() -> void:
	if perk_catalog != null:
		configure(perk_catalog)


func draw_choices(seed_value: int, count: int) -> Array[PerkDefinition]:
	return _pool.draw_choices(seed_value, maxi(1, count))


func select_perk(perk: PerkDefinition) -> bool:
	if perk == null or not _pool.select(perk.stable_id):
		return false
	_emit_changed()
	return true


func selected_perks() -> Array[PerkDefinition]:
	return _pool.selected_definitions()


func modifiers() -> PerkModifierSnapshot:
	return _pool.modifiers()


func remaining_count() -> int:
	return _pool.remaining_count()


## Debug tooling deliberately goes through the same unique-pool selection path as
## geodes, so it cannot create an impossible run state.
func debug_perk_picker_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in _pool.draw_choices(0, _pool.remaining_count()):
		result.append({"stable_id": definition.stable_id, "name": definition.display_name})
	return result


func debug_grant_perk(stable_id: int) -> bool:
	if _registry == null:
		return false
	return select_perk(_registry.get_definition(stable_id))


func _emit_changed() -> void:
	perks_changed.emit(selected_perks())
	modifiers_changed.emit(modifiers())
