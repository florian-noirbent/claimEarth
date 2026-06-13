extends GutTest


const CooperativeChunkBackendScript = preload("res://src/simulation/cooperative_chunk_backend.gd")


func test_sand_falls_down_or_swaps_with_liquid() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(5, 5), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	world.set_committed_by_offset(2, 1, 3)
	world.set_committed_by_offset(2, 2, 4)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(2, 1), 4)
	assert_eq(world.get_committed_by_offset(2, 2), 3)


func test_water_and_lava_turn_to_stone_on_contact() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(5, 5), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	world.set_committed_by_offset(2, 1, 4)
	world.set_committed_by_offset(2, 2, 5)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(2, 1), 0)
	assert_eq(world.get_committed_by_offset(2, 2), 1)


func test_liquid_spreads_sideways_when_blocked_below() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(5, 5), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	world.set_committed_by_offset(2, 1, 4)
	world.set_committed_by_offset(2, 2, 1)

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_true(commit.did_commit)
	assert_eq(world.get_committed_by_offset(2, 1), 0)
	assert_true(world.get_committed_by_offset(1, 1) == 4 or world.get_committed_by_offset(3, 1) == 4)


func test_backend_exposes_deterministic_stats_for_advances_and_commits() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(5, 5), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	backend.schedule([Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)])
	world.set_committed_by_offset(2, 1, 4)
	world.set_committed_by_offset(2, 2, 1)

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_true(commit.did_commit)
	assert_eq(backend.scheduled_chunk_count(), 3)
	assert_eq(backend.advances_performed(), 1)
	assert_eq(backend.commits_performed(), 1)
	assert_eq(backend.last_commit_rect(), commit.dirty_rect)
	assert_gt(backend.last_commit_cell_count(), 0)
