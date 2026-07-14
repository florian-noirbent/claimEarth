extends GutTest


func test_pickaxe_changes_three_aimed_hexes_and_caps_charge_at_three() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var player := PlayerController.new()
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)
	var targets := [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]
	for target in targets:
		world.set_committed_by_offset(target.x, target.y, FixtureLoader.terrain_id("Stone"), 255)
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(player, world, registry, 16.0)
	var factory := load("res://config/items/factory/pickaxe_factory.tres") as TerrainToolItemActionFactory

	var cost := controller.resolve_terrain_tool_use(factory.transformations, HexMetrics.center_for_offset(targets[0].x, targets[0].y, 16.0))

	assert_eq(cost, 3.0)
	for target in targets:
		assert_eq(world.get_committed_by_offset(target.x, target.y), FixtureLoader.terrain_id("Dirt"))
		assert_eq(world.get_committed_fill_by_offset(target.x, target.y), 255)


func test_water_bottle_fills_nearest_air_hexes() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Stone"))
	var origin := Vector2i(3, 3)
	world.set_committed_by_offset(origin.x, origin.y, FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 3, FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(3, 4, FixtureLoader.terrain_id("Air"))
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(PlayerController.new(), world, registry, 16.0)

	controller.resolve_fluid_bottle_impact(registry.get_definition(FixtureLoader.terrain_id("Water")), HexMetrics.center_for_offset(origin.x, origin.y, 16.0))

	assert_eq(world.count_committed(FixtureLoader.terrain_id("Water")), 3)


func _item_registry() -> ItemRegistry:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(load("res://config/items/catalog.tres")))
	return registry
