extends GutTest


func test_explosion_applies_registered_blast_reactions_and_marks_dirty_chunks() -> void:
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
	var chunks := ChunkActivityIndex.new(world.dimensions, 4, 4)
	var service := ExplosionService.new()

	var dirty_rect := service.explode(
		world,
		registry,
		chunks,
		HexMetrics.center_for_offset(3, 3, 16.0),
		16.0,
		2
	)

	assert_eq(world.get_committed_by_offset(3, 3), dirt_id)
	assert_eq(world.get_committed_by_offset(4, 3), sand_id)
	assert_eq(world.get_committed_by_offset(5, 3), 0)
	assert_eq(world.get_committed_by_offset(3, 4), water_id)
	assert_true(dirty_rect.has_point(Vector2i(3, 3)))
	assert_gt(chunks.consume_dirty_chunks().size(), 0)


func test_explosion_vaporizes_terrain_within_lethal_radius_regardless_of_type() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), 1)
	var chunks := ChunkActivityIndex.new(world.dimensions, 4, 4)
	var service := ExplosionService.new()

	world.set_committed_by_offset(3, 3, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(4, 3, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(3, 4, FixtureLoader.terrain_id("Lava"))
	world.set_committed_by_offset(2, 3, FixtureLoader.terrain_id("Sand"))

	service.explode(
		world,
		registry,
		chunks,
		HexMetrics.center_for_offset(3, 3, 16.0),
		16.0,
		3,
		1
	)

	assert_eq(world.get_committed_by_offset(3, 3), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(4, 3), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(3, 4), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(2, 3), FixtureLoader.terrain_id("Air"))
