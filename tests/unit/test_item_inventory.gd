extends GutTest


func test_inventory_uses_starting_counts_and_selection_order() -> void:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.item_catalog()))
	var inventory := ItemInventory.new()
	inventory.configure(registry)

	var definitions := inventory.definitions()
	assert_eq(definitions.size(), 7)
	assert_eq(inventory.count_for(definitions[0]), 10)
	assert_eq(inventory.count_for(definitions[1]), 2)
	assert_eq(inventory.count_for(definitions[2]), 1)
	for index in range(3, 7):
		assert_eq(inventory.count_for(definitions[index]), 0.0)
	assert_eq(inventory.selected_definition().display_name, "Small Bomb")

	inventory.select_index(2)
	assert_eq(inventory.selected_definition().display_name, "Flag")


func test_consuming_item_reduces_count_and_blocks_at_zero() -> void:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.item_catalog()))
	var inventory := ItemInventory.new()
	inventory.configure(registry)
	var large_bomb := inventory.definitions()[1]

	assert_true(inventory.consume(large_bomb))
	assert_true(inventory.consume(large_bomb))
	assert_false(inventory.consume(large_bomb))
	assert_eq(inventory.count_for(large_bomb), 0)


func test_reset_restores_starting_counts_and_selection() -> void:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.item_catalog()))
	var inventory := ItemInventory.new()
	inventory.configure(registry)
	var definitions := inventory.definitions()
	inventory.select_index(2)
	assert_true(inventory.consume(definitions[0]))

	inventory.reset()

	assert_eq(inventory.count_for(definitions[0]), 10)
	assert_eq(inventory.count_for(definitions[1]), 2)
	assert_eq(inventory.count_for(definitions[2]), 1)
	for index in range(3, 7):
		assert_eq(inventory.count_for(definitions[index]), 0.0)
	assert_eq(inventory.selected_definition(), definitions[0])


func test_add_rejects_invalid_amounts_and_preserves_selection() -> void:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.item_catalog()))
	var inventory := ItemInventory.new()
	inventory.configure(registry)
	var definitions := inventory.definitions()
	inventory.select_index(1)
	var selected_before := inventory.selected_definition()
	var small_before := inventory.count_for(definitions[0])

	assert_false(inventory.add(null, 5))
	assert_false(inventory.add(definitions[0], 0))
	assert_true(inventory.add(definitions[0], 5))
	assert_eq(inventory.count_for(definitions[0]), small_before + 5)
	assert_same(inventory.selected_definition(), selected_before)


func test_partial_consumption_uses_the_remaining_fraction_and_clamps_to_zero() -> void:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.item_catalog()))
	var inventory := ItemInventory.new()
	inventory.configure(registry)
	var small_bomb := inventory.definitions()[0]

	assert_true(inventory.add(small_bomb, 0.25))
	assert_eq(inventory.consume_amount(small_bomb, 10.1), 0.0)
	assert_eq(inventory.consume_amount(small_bomb, 10.1, true), 10.25)
	assert_eq(inventory.count_for(small_bomb), 0.0)
	assert_eq(inventory.consume_amount(small_bomb, 1.0, true), 0.0)
