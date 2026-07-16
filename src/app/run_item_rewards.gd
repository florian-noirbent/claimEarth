## Owns the single pending item or perk reward selection for a run.
class_name RunItemRewards
extends RefCounted


enum BeginResult {
	STARTED,
	INVALID,
	EMPTY,
}


var _item_registry: ItemRegistry
var _perk_controller: RunPerkController
var _tuning: RunItemRuntimeTuning
var _pending_chest: ItemChest
var _pending_choices: Array[ItemChestOption] = []
var _pending_perk_choices: Array[PerkDefinition] = []
var _request_title := ""
var _request_choices: Array[RewardChoiceViewData] = []
var _last_item_reward: ItemDefinition


func configure(item_registry: ItemRegistry, perk_controller: RunPerkController) -> void:
	_item_registry = item_registry
	_perk_controller = perk_controller


func set_tuning(tuning: RunItemRuntimeTuning) -> void:
	_tuning = tuning


func reset() -> void:
	_pending_chest = null
	_pending_choices.clear()
	_pending_perk_choices.clear()
	_request_title = ""
	_request_choices.clear()
	_last_item_reward = null


func begin(chest: ItemChest) -> BeginResult:
	if chest == null or chest.spawn_data == null or chest.spawn_data.definition == null:
		return BeginResult.INVALID
	reset()
	_pending_chest = chest
	var definition := chest.spawn_data.definition
	var choice_count := _choice_count(definition)
	if definition.reward_kind == ItemChestDefinition.RewardKind.PERKS:
		if _perk_controller == null:
			reset()
			return BeginResult.INVALID
		_pending_perk_choices = _perk_controller.draw_choices(chest.spawn_data.choice_seed, choice_count)
		if _pending_perk_choices.is_empty():
			_pending_chest = null
			return BeginResult.EMPTY
		_request_title = "Choose a perk"
		for perk in _pending_perk_choices:
			_request_choices.append(RewardChoiceViewData.new(perk.display_name, perk.description, perk.icon, ""))
		return BeginResult.STARTED
	_pending_choices = definition.draw_choices(chest.spawn_data.choice_seed, choice_count)
	if _pending_choices.size() != choice_count:
		reset()
		return BeginResult.INVALID
	_request_title = "Choose an item"
	for option in _pending_choices:
		if option == null or option.item == null:
			reset()
			return BeginResult.INVALID
		_request_choices.append(RewardChoiceViewData.new(option.item.display_name, option.item.description, option.item.icon, "+%d" % option.quantity))
	return BeginResult.STARTED


func request_title() -> String:
	return _request_title


func request_choices() -> Array[RewardChoiceViewData]:
	return _request_choices.duplicate()


func pending_chest() -> ItemChest:
	return _pending_chest


func is_pending(chest: ItemChest) -> bool:
	return chest != null and chest == _pending_chest


func apply(choice_index: int, inventory: ItemInventory) -> ItemChest:
	if _pending_chest == null:
		return null
	_last_item_reward = null
	if not _pending_perk_choices.is_empty():
		if choice_index < 0 or choice_index >= _pending_perk_choices.size() or _perk_controller == null:
			return null
		if not _perk_controller.select_perk(_pending_perk_choices[choice_index]):
			return null
	else:
		if choice_index < 0 or choice_index >= _pending_choices.size() or inventory == null or _item_registry == null:
			return null
		var option := _pending_choices[choice_index]
		if option == null or option.item == null:
			return null
		var registered_item := _item_registry.get_definition(option.item.stable_id)
		if registered_item == null or not inventory.add(registered_item, option.quantity):
			return null
		_last_item_reward = registered_item
	var claimed_chest := _pending_chest
	var granted_item := _last_item_reward
	reset()
	_last_item_reward = granted_item
	return claimed_chest


func cancel() -> void:
	reset()


func invalidate() -> bool:
	if _pending_chest == null:
		return false
	reset()
	return true


func last_item_reward() -> ItemDefinition:
	return _last_item_reward


func _choice_count(definition: ItemChestDefinition) -> int:
	if definition == null:
		return 0
	var count := definition.choice_count
	if _tuning != null:
		count += _tuning.reward_choice_count_add
	return clampi(count, 1, 3)
