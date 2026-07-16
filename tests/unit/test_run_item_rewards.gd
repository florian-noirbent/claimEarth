extends GutTest


var _chests: Array[ItemChest] = []


func after_each() -> void:
	for chest in _chests:
		chest.free()
	_chests.clear()


func test_item_reward_draws_and_applies_one_registered_choice() -> void:
	var registry := _item_registry()
	var inventory := ItemInventory.new()
	inventory.configure(registry)
	var rewards := RunItemRewards.new()
	rewards.configure(registry, null)
	rewards.set_tuning(RunItemRuntimeTuning.compile(null))
	var chest := _chest(load("res://config/items/item_chest.tres") as ItemChestDefinition, 17)

	assert_eq(rewards.begin(chest), RunItemRewards.BeginResult.STARTED)
	assert_eq(rewards.request_title(), "Choose an item")
	assert_eq(rewards.request_choices().size(), 2)
	var claimed := rewards.apply(0, inventory)

	assert_eq(claimed, chest)
	assert_null(rewards.pending_chest())
	assert_not_null(rewards.last_item_reward())
	assert_gt(inventory.count_for(rewards.last_item_reward()), 0.0)
	assert_null(rewards.apply(0, inventory))


func test_reward_choice_count_uses_compiled_tuning_and_clamps() -> void:
	var rewards := RunItemRewards.new()
	var registry := _item_registry()
	rewards.configure(registry, null)
	var modifiers := PerkModifierSnapshot.new()
	modifiers.rewards._set_value("choice_count_add", 4)
	rewards.set_tuning(RunItemRuntimeTuning.compile(modifiers))
	var chest := _chest(load("res://config/items/item_chest.tres") as ItemChestDefinition, 17)

	assert_eq(rewards.begin(chest), RunItemRewards.BeginResult.STARTED)
	assert_eq(rewards.request_choices().size(), 3)


func test_perk_reward_requires_a_configured_perk_controller() -> void:
	var rewards := RunItemRewards.new()
	rewards.configure(_item_registry(), null)
	rewards.set_tuning(RunItemRuntimeTuning.compile(null))
	var chest := _chest(load("res://config/items/perk_geode.tres") as PerkGeodeDefinition, 41)

	assert_eq(rewards.begin(chest), RunItemRewards.BeginResult.INVALID)
	assert_null(rewards.pending_chest())


func test_perk_reward_selects_one_drawn_perk() -> void:
	var perks := RunPerkController.new()
	assert_true(perks.configure(load("res://config/perks/catalog.tres") as PerkCatalog))
	var rewards := RunItemRewards.new()
	var registry := _item_registry()
	var inventory := ItemInventory.new()
	inventory.configure(registry)
	rewards.configure(registry, perks)
	rewards.set_tuning(RunItemRuntimeTuning.compile(null))
	var chest := _chest(load("res://config/items/perk_geode.tres") as PerkGeodeDefinition, 41)

	assert_eq(rewards.begin(chest), RunItemRewards.BeginResult.STARTED)
	assert_eq(rewards.request_title(), "Choose a perk")
	assert_eq(rewards.apply(0, inventory), chest)
	assert_eq(perks.selected_perks().size(), 1)
	perks.free()


func test_cancel_and_invalidate_clear_the_pending_transaction() -> void:
	var rewards := RunItemRewards.new()
	rewards.configure(_item_registry(), null)
	rewards.set_tuning(RunItemRuntimeTuning.compile(null))
	var chest := _chest(load("res://config/items/item_chest.tres") as ItemChestDefinition, 17)

	assert_eq(rewards.begin(chest), RunItemRewards.BeginResult.STARTED)
	rewards.cancel()
	assert_null(rewards.pending_chest())
	assert_false(rewards.invalidate())
	assert_eq(rewards.begin(chest), RunItemRewards.BeginResult.STARTED)
	assert_true(rewards.invalidate())
	assert_null(rewards.pending_chest())


func _item_registry() -> ItemRegistry:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(load("res://config/items/catalog.tres")))
	return registry


func _chest(definition: ItemChestDefinition, seed_value: int) -> ItemChest:
	var chest := ItemChest.new()
	chest.spawn_data = GeneratedItemChestSpawn.new(Vector2i.ZERO, definition, seed_value)
	_chests.append(chest)
	return chest
