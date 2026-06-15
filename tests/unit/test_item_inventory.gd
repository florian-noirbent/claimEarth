extends GutTest


func test_inventory_uses_starting_counts_and_selection_order() -> void:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.item_catalog()))
	var inventory := ItemInventory.new()
	inventory.configure(registry)

	var definitions := inventory.definitions()
	assert_eq(definitions.size(), 3)
	assert_eq(inventory.count_for(definitions[0]), 10)
	assert_eq(inventory.count_for(definitions[1]), 2)
	assert_eq(inventory.count_for(definitions[2]), 1)
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
	assert_eq(inventory.selected_definition(), definitions[0])
