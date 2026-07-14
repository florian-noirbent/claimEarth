extends GutTest


func test_explosion_applies_registered_blast_reactions_and_reports_changed_region() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), 0)
	var stone_id := registry.get_definition(1).stable_id
	var dirt_id := registry.get_definition(2).stable_id
	var sand_id := registry.get_definition(3).stable_id
	var water_id := registry.get_definition(4).stable_id
	world.set_committed_by_offset(3, 3, stone_id)
	world.set_committed_by_offset(4, 3, dirt_id)
	world.set_committed_by_offset(5, 3, sand_id)
	world.set_committed_by_offset(3, 4, water_id)
	var service := ExplosionService.new()

	var dirty_rect := service.explode(
		world,
		registry,
		HexMetrics.center_for_offset(3, 3, 16.0),
		16.0,
		2
	)

	assert_eq(world.get_committed_by_offset(3, 3), dirt_id)
	assert_eq(world.get_committed_by_offset(4, 3), sand_id)
	assert_eq(world.get_committed_by_offset(5, 3), 0)
	assert_eq(world.get_committed_by_offset(3, 4), water_id)
	assert_true(dirty_rect.has_point(Vector2i(3, 3)))


func test_explosion_vaporizes_terrain_within_lethal_radius_regardless_of_type() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), 1)
	var service := ExplosionService.new()

	world.set_committed_by_offset(3, 3, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(4, 3, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(3, 4, FixtureLoader.terrain_id("Lava"))
	world.set_committed_by_offset(2, 3, FixtureLoader.terrain_id("Sand"))

	service.explode(
		world,
		registry,
		HexMetrics.center_for_offset(3, 3, 16.0),
		16.0,
		3,
		1
	)

	assert_eq(world.get_committed_by_offset(3, 3), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(4, 3), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(3, 4), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(2, 3), FixtureLoader.terrain_id("Air"))


func test_explosion_above_top_row_propagates_into_world() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var stone_id := FixtureLoader.terrain_id("Stone")
	var air_id := FixtureLoader.terrain_id("Air")
	var world := WorldGrid.new(WorldDimensions.new(7, 7), stone_id)
	var service := ExplosionService.new()

	var change_set := service.explode_with_changes(
		world,
		registry,
		HexMetrics.center_for_offset(3, -1, 16.0),
		16.0,
		2,
		1
	)

	assert_eq(world.get_committed_by_offset(3, 0), air_id)
	assert_gt(change_set.changed_cell_count(), 0)


func test_explosion_result_reports_inclusive_lethal_core_cells() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 12), FixtureLoader.terrain_id("Air"))
	var service := ExplosionService.new()
	var origin := Vector2i(5, 5)

	var result := service.resolve(
		world,
		registry,
		HexMetrics.center_for_offset(origin.x, origin.y, 16.0),
		16.0,
		5,
		3
	)

	assert_eq(result.lethal_cells.size(), 37)
	assert_true(result.lethal_cells.has(origin))
	assert_true(result.lethal_cells.has(HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(3, 0)).to_offset_odd_q()))
	assert_false(result.lethal_cells.has(HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(4, 0)).to_offset_odd_q()))
