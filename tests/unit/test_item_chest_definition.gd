extends GutTest


func _definition() -> ItemChestDefinition:
	return load("res://config/items/item_chest.tres") as ItemChestDefinition


func test_configured_chest_definition_is_valid_and_draws_unique_deterministic_choices() -> void:
	var definition := _definition()
	assert_not_null(definition)
	assert_true(definition.validate().is_empty())
	var lava := FixtureLoader.terrain_definition_named("Lava")
	var chest_light := load("res://config/lighting/chest_light.tres") as WorldLightSourceDefinition
	assert_not_null(lava)
	assert_not_null(chest_light)
	assert_eq(chest_light.light_level, lava.emitted_light)
	var chest_explosion := definition.explosion_definition
	var small_explosion := (load("res://config/items/factory/small_bomb_factory.tres") as BombItemActionFactory).explosion_definition
	assert_not_null(chest_explosion)
	assert_not_same(chest_explosion, small_explosion)
	assert_eq(chest_explosion.blast_radius, small_explosion.blast_radius)
	assert_eq(chest_explosion.lethal_radius, small_explosion.lethal_radius)
	assert_almost_eq(chest_explosion.chain_fuse_seconds, 0.3, 0.001)

	var first := definition.draw_choices(12345)
	var repeat := definition.draw_choices(12345)
	assert_eq(first.size(), 2)
	assert_eq(repeat.size(), 2)
	assert_eq(first[0].item.stable_id, repeat[0].item.stable_id)
	assert_eq(first[1].item.stable_id, repeat[1].item.stable_id)
	assert_ne(first[0].item.stable_id, first[1].item.stable_id)
	assert_eq(first[0].quantity + first[1].quantity, 7)


func test_zero_weight_options_are_skipped_and_duplicate_items_fail_validation() -> void:
	var definition := _definition().duplicate(true) as ItemChestDefinition
	definition.options[0].selection_weight = 0.0
	assert_false(definition.validate().is_empty())
	assert_eq(definition.draw_choices(7).size(), 1)

	definition = _definition().duplicate(true) as ItemChestDefinition
	definition.options[1].item = definition.options[0].item
	var errors := definition.validate()
	assert_true("\n".join(errors).contains("duplicate item stable_id"))


func test_three_choice_table_draws_without_replacement() -> void:
	var definition := _definition().duplicate(true) as ItemChestDefinition
	var flag_option := ItemChestOption.new()
	flag_option.item = load("res://config/items/flag.tres") as ItemDefinition
	flag_option.quantity = 1
	flag_option.selection_weight = 0.5
	definition.options.append(flag_option)
	definition.choice_count = 3

	assert_true(definition.validate().is_empty())
	var choices := definition.draw_choices(991)
	var selected_ids := {}
	for choice in choices:
		selected_ids[choice.item.stable_id] = true
	assert_eq(choices.size(), 3)
	assert_eq(selected_ids.size(), 3)
