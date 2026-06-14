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


func test_liquid_flows_to_a_downward_neighbor_when_blocked_below() -> void:
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
	assert_true(world.get_committed_by_offset(1, 1) == 4 or world.get_committed_by_offset(2, 2) == 4)


func test_liquid_rest_state_does_not_oscillate_sideways_forever() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(6, 6), 1)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	world.set_committed_by_offset(2, 1, 4)
	world.set_committed_by_offset(3, 1, 4)
	world.set_committed_by_offset(2, 2, 1)
	world.set_committed_by_offset(3, 2, 1)
	world.set_committed_by_offset(1, 1, 1)
	world.set_committed_by_offset(4, 1, 1)
	world.set_committed_by_offset(1, 2, 1)
	world.set_committed_by_offset(4, 2, 1)

	var commit_count := 0
	for _step in range(12):
		backend.advance(1000)
		var commit = backend.commit_if_ready()
		if commit.did_commit:
			commit_count += 1

	backend.advance(1000)
	var final_commit = backend.commit_if_ready()

	assert_lte(commit_count, 2)
	assert_false(final_commit.did_commit)


func test_stacked_liquid_column_spreads_diagonally_when_supported() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	for col in range(0, 7):
		world.set_committed_by_offset(col, 6, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(3, 3, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(3, 4, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(3, 5, FixtureLoader.terrain_id("Water"))

	backend.advance(1000)
	backend.commit_if_ready()

	assert_true(
		world.get_committed_by_offset(2, 5) == FixtureLoader.terrain_id("Water")
		or world.get_committed_by_offset(3, 5) == FixtureLoader.terrain_id("Water")
		or world.get_committed_by_offset(4, 5) == FixtureLoader.terrain_id("Water")
	)
	assert_true(
		world.get_committed_by_offset(2, 4) == FixtureLoader.terrain_id("Water")
		or world.get_committed_by_offset(4, 4) == FixtureLoader.terrain_id("Water")
	)


func test_liquid_can_flow_down_right_and_down_left_when_blocked_below() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")

	var left_world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var left_backend = CooperativeChunkBackendScript.new()
	left_backend.initialize(left_world, registry, 1)
	left_world.set_committed_by_offset(3, 2, water_id)
	left_world.set_committed_by_offset(3, 3, stone_id)
	left_world.set_committed_by_offset(4, 3, stone_id)
	left_backend.advance(1000)
	left_backend.commit_if_ready()
	assert_eq(left_world.get_committed_by_offset(2, 3), water_id)

	var right_world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var right_backend = CooperativeChunkBackendScript.new()
	right_backend.initialize(right_world, registry, 2)
	right_world.set_committed_by_offset(3, 2, water_id)
	right_world.set_committed_by_offset(3, 3, stone_id)
	right_world.set_committed_by_offset(2, 3, stone_id)
	right_backend.advance(1000)
	right_backend.commit_if_ready()
	assert_eq(right_world.get_committed_by_offset(4, 3), water_id)


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


func test_backend_does_not_commit_when_tick_returns_to_same_world_state() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	for col in range(0, 7):
		world.set_committed_by_offset(col, 6, 1)
	world.set_committed_by_offset(2, 3, 4)
	world.set_committed_by_offset(3, 3, 4)
	world.set_committed_by_offset(4, 3, 4)

	for _step in range(3):
		backend.advance(1000)
		backend.commit_if_ready()

	var settled_hash := world.committed_hash()
	backend.advance(1000)
	var no_op_commit = backend.commit_if_ready()

	assert_eq(world.committed_hash(), settled_hash)
	assert_false(no_op_commit.did_commit)


func test_different_time_budgets_produce_identical_tick_result() -> void:
	var registry := FixtureLoader.terrain_registry()
	var dimensions := WorldDimensions.new(30, 40)
	var fast_world := WorldGrid.new(dimensions, FixtureLoader.terrain_id("Air"))
	for col in range(1, 29):
		fast_world.set_committed_by_offset(col, 10, FixtureLoader.terrain_id("Sand"))
		fast_world.set_committed_by_offset(col, 20, FixtureLoader.terrain_id("Water"))
	var sliced_world := WorldGrid.new(dimensions, FixtureLoader.terrain_id("Air"))
	sliced_world.committed_cells = fast_world.committed_cells.duplicate()
	sliced_world.working_cells = fast_world.working_cells.duplicate()
	var fast_backend := CooperativeChunkBackendScript.new()
	var sliced_backend := CooperativeChunkBackendScript.new()
	fast_backend.initialize(fast_world, registry, 7)
	sliced_backend.initialize(sliced_world, registry, 7)
	fast_backend.advance(1000000)
	while not sliced_backend.advance(1).step_completed:
		pass
	fast_backend.commit_if_ready()
	sliced_backend.commit_if_ready()

	assert_eq(sliced_world.committed_cells, fast_world.committed_cells)


func test_settled_scheduled_region_goes_to_sleep() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(100, 96), FixtureLoader.terrain_id("Air"))
	var backend := CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	backend.schedule(ChunkActivityIndex.new(world.dimensions).visible_chunks_for_depth_window(0, 96))
	backend.advance(1000000)
	backend.commit_if_ready()
	backend.advance(1000000)

	assert_eq(backend.active_cell_count(), 0)
	assert_eq(backend.last_processed_cell_count(), 0)
