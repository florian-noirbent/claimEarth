extends GutTest


const CooperativeChunkBackendScript = preload("res://src/simulation/cooperative_chunk_backend.gd")


func test_sand_falls_down_as_fill_into_empty_cell() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(5, 5), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	world.set_committed_by_offset(2, 1, FixtureLoader.terrain_id("Sand"))

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(2, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(2, 2), FixtureLoader.terrain_id("Sand"))
	assert_eq(world.get_committed_fill_by_offset(2, 2), 255)


func test_sand_displaces_full_water_below_without_mixing_cells() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var sand_id := FixtureLoader.terrain_id("Sand")
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(2, 1, sand_id)
	world.set_committed_by_offset(2, 2, water_id)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(1, 1, stone_id)
	world.set_committed_by_offset(3, 1, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	world.set_committed_by_offset(3, 2, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(2, 1), water_id)
	assert_eq(world.get_committed_fill_by_offset(2, 1), 255)
	assert_eq(world.get_committed_by_offset(2, 2), sand_id)
	assert_eq(world.get_committed_fill_by_offset(2, 2), 255)


func test_partial_sand_displaces_water_below_without_mixing_cells() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var sand_id := FixtureLoader.terrain_id("Sand")
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(2, 1, sand_id, 96)
	world.set_committed_by_offset(2, 2, water_id, 192)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(1, 1, stone_id)
	world.set_committed_by_offset(3, 1, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	world.set_committed_by_offset(3, 2, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(2, 1), water_id)
	assert_eq(world.get_committed_fill_by_offset(2, 1), 192)
	assert_eq(world.get_committed_by_offset(2, 2), sand_id)
	assert_eq(world.get_committed_fill_by_offset(2, 2), 96)


func test_water_and_lava_turn_to_stone_on_contact() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(5, 5), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	world.set_committed_by_offset(2, 1, 4)
	world.set_committed_by_offset(2, 2, 5)

	for _step in range(3):
		backend.advance(1000)
		backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(2, 1), 0)
	assert_eq(world.get_committed_by_offset(2, 2), 1)


func test_liquid_transfers_fill_to_a_downward_neighbor_when_blocked_below() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(5, 5), 0)
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	world.set_committed_by_offset(2, 1, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_true(commit.did_commit)
	assert_eq(world.get_committed_by_offset(2, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_fill_by_offset(2, 1), 0)
	assert_eq(world.get_committed_by_offset(1, 1), FixtureLoader.terrain_id("Water"))
	assert_eq(world.get_committed_fill_by_offset(1, 1), 128)
	assert_eq(world.get_committed_by_offset(3, 1), FixtureLoader.terrain_id("Water"))
	assert_eq(world.get_committed_fill_by_offset(3, 1), 127)


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

	var spread_fill := 0
	for row in range(3, 6):
		spread_fill += world.get_committed_fill_by_offset(2, row)
		spread_fill += world.get_committed_fill_by_offset(4, row)
	assert_gt(spread_fill, 0)


func test_partial_fall_spreads_remaining_liquid_sideways_in_same_tick() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id)
	world.set_committed_by_offset(3, 4, water_id, 127)
	world.set_committed_by_offset(3, 5, stone_id)
	world.set_committed_by_offset(2, 5, stone_id)
	world.set_committed_by_offset(4, 5, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(3, 3), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_fill_by_offset(3, 4), 255)
	assert_eq(world.get_committed_by_offset(2, 4), water_id)
	assert_eq(world.get_committed_fill_by_offset(2, 4), 127)


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

	for _step in range(20):
		backend.advance(1000)
		backend.commit_if_ready()

	var settled_hash := world.committed_hash()
	backend.advance(1000)
	var no_op_commit = backend.commit_if_ready()
	backend.advance(1000)
	var rescan_commit = backend.commit_if_ready()

	assert_false(no_op_commit.did_commit)
	assert_false(rescan_commit.did_commit)
	assert_eq(world.committed_hash(), settled_hash)


func test_side_up_overflow_clamps_at_offset_equilibrium() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(2, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 192)
	assert_eq(world.get_committed_fill_by_offset(2, 3), 63)


func test_side_down_flow_clamps_at_offset_equilibrium() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 5, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 4, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 64)
	assert_eq(world.get_committed_by_offset(2, 4), water_id)
	assert_eq(world.get_committed_fill_by_offset(2, 4), 191)


func test_supported_equal_raw_water_slope_continues_leveling_side_down() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id, 128)
	world.set_committed_by_offset(2, 4, water_id, 128)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 5, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 4, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 64)
	assert_eq(world.get_committed_fill_by_offset(2, 4), 192)


func test_side_flow_does_not_move_when_already_at_offset_equilibrium() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id, 50)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 4, water_id, 178)
	world.set_committed_by_offset(2, 5, stone_id)
	world.set_committed_by_offset(1, 4, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_false(commit.did_commit)
	assert_eq(world.get_committed_fill_by_offset(3, 3), 50)
	assert_eq(world.get_committed_fill_by_offset(2, 4), 178)


func test_side_down_transfer_never_overshoots_offset_equilibrium() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id, 170)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 4, water_id, 100)
	world.set_committed_by_offset(2, 5, stone_id)
	world.set_committed_by_offset(1, 4, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 71)
	assert_eq(world.get_committed_fill_by_offset(2, 4), 199)


func test_side_up_flow_requires_source_threshold() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id, 100)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(2, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_false(commit.did_commit)
	assert_eq(world.get_committed_fill_by_offset(3, 3), 100)
	assert_eq(world.get_committed_fill_by_offset(2, 3), 0)


func test_side_down_and_side_up_can_both_apply_in_one_cell_step() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id, 255)
	world.set_committed_by_offset(2, 4, water_id, 180)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 5, stone_id)
	world.set_committed_by_offset(1, 4, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 154)
	assert_eq(world.get_committed_fill_by_offset(2, 4), 255)
	assert_eq(world.get_committed_by_offset(2, 3), water_id)
	assert_eq(world.get_committed_fill_by_offset(2, 3), 26)


func test_side_up_transfer_never_overshoots_offset_equilibrium() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id, 255)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(2, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 3, water_id, 100)
	world.set_committed_by_offset(1, 2, stone_id)
	world.set_committed_by_offset(3, 2, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 242)
	assert_eq(world.get_committed_fill_by_offset(2, 3), 113)


func test_side_up_flow_splits_between_both_targets_when_possible() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(2, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 129)
	assert_eq(world.get_committed_by_offset(2, 3), water_id)
	assert_eq(world.get_committed_fill_by_offset(2, 3), 63)
	assert_eq(world.get_committed_by_offset(4, 3), water_id)
	assert_eq(world.get_committed_fill_by_offset(4, 3), 63)


func test_lava_does_not_flow_below_minimum_fill_difference() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var lava_id := FixtureLoader.terrain_id("Lava")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, lava_id, 128)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(2, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 3, lava_id, 100)
	world.set_committed_by_offset(1, 2, stone_id)
	world.set_committed_by_offset(3, 2, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_false(commit.did_commit)
	assert_eq(world.get_committed_fill_by_offset(3, 3), 128)
	assert_eq(world.get_committed_fill_by_offset(2, 3), 100)


func test_low_lava_puddle_decays_by_one_fill_per_tick() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var lava_id := FixtureLoader.terrain_id("Lava")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(2, 2, lava_id, 50)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	world.set_committed_by_offset(3, 2, stone_id)
	world.set_committed_by_offset(1, 1, stone_id)
	world.set_committed_by_offset(3, 1, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)
	world.set_committed_by_offset(3, 3, stone_id)

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_true(commit.did_commit)
	assert_eq(world.get_committed_by_offset(2, 2), lava_id)
	assert_eq(world.get_committed_fill_by_offset(2, 2), 49)


func test_low_water_puddle_decays_by_one_fill_per_tick() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(2, 2, water_id, 12)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	world.set_committed_by_offset(3, 2, stone_id)
	world.set_committed_by_offset(1, 1, stone_id)
	world.set_committed_by_offset(3, 1, stone_id)
	world.set_committed_by_offset(1, 3, stone_id)
	world.set_committed_by_offset(3, 3, stone_id)

	backend.advance(1000)
	var commit = backend.commit_if_ready()

	assert_true(commit.did_commit)
	assert_eq(world.get_committed_by_offset(2, 2), water_id)
	assert_eq(world.get_committed_fill_by_offset(2, 2), 11)


func test_lava_side_down_uses_same_equilibrium_when_difference_is_large_enough() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var lava_id := FixtureLoader.terrain_id("Lava")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, lava_id)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	world.set_committed_by_offset(2, 5, stone_id)
	world.set_committed_by_offset(2, 3, stone_id)
	world.set_committed_by_offset(4, 3, stone_id)
	world.set_committed_by_offset(1, 4, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_fill_by_offset(3, 3), 223)
	assert_eq(world.get_committed_by_offset(2, 4), lava_id)
	assert_eq(world.get_committed_fill_by_offset(2, 4), 32)


func test_sand_never_flows_side_up() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var sand_id := FixtureLoader.terrain_id("Sand")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, sand_id)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(2, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)

	backend.advance(1000)
	backend.commit_if_ready()

	assert_eq(world.get_committed_by_offset(3, 3), sand_id)
	assert_eq(world.get_committed_fill_by_offset(2, 3), 0)
	assert_eq(world.get_committed_fill_by_offset(4, 3), 0)


func test_supported_irregular_water_pool_settles_with_no_remaining_ca_side_flow() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(9, 8), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	for col in range(0, 9):
		world.set_committed_by_offset(col, 6, stone_id)
	for row in range(2, 7):
		world.set_committed_by_offset(0, row, stone_id)
		world.set_committed_by_offset(8, row, stone_id)
	world.set_committed_by_offset(3, 3, water_id, 255)
	world.set_committed_by_offset(4, 3, water_id, 255)
	world.set_committed_by_offset(5, 3, water_id, 180)
	world.set_committed_by_offset(2, 4, water_id, 255)
	world.set_committed_by_offset(3, 4, water_id, 200)
	world.set_committed_by_offset(4, 4, water_id, 255)
	world.set_committed_by_offset(5, 4, water_id, 120)
	world.set_committed_by_offset(6, 4, water_id, 60)
	world.set_committed_by_offset(2, 5, water_id, 80)
	world.set_committed_by_offset(3, 5, water_id, 220)
	world.set_committed_by_offset(4, 5, water_id, 255)
	world.set_committed_by_offset(5, 5, water_id, 40)

	for _step in range(200):
		backend.advance(1000000)
		backend.commit_if_ready()
	backend.advance(1000000)
	backend.commit_if_ready()
	backend.advance(1000000)
	var final_commit = backend.commit_if_ready()

	assert_false(final_commit.did_commit)


func test_wide_supported_water_pool_settles_to_flat_visual_surface() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 8), FixtureLoader.terrain_id("Air"))
	var backend = CooperativeChunkBackendScript.new()
	backend.initialize(world, registry, 1)
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	for col in range(0, 12):
		world.set_committed_by_offset(col, 6, stone_id)
	for row in range(2, 7):
		world.set_committed_by_offset(0, row, stone_id)
		world.set_committed_by_offset(11, row, stone_id)
	for col in range(2, 10):
		world.set_committed_by_offset(col, 4, water_id, 255 if col % 3 != 0 else 80)
		world.set_committed_by_offset(col, 5, water_id, 255 if col % 2 == 0 else 120)

	var settled_tick := -1
	for step in range(80):
		backend.advance(1000000)
		var commit = backend.commit_if_ready()
		if not commit.did_commit:
			settled_tick = step
			break

	assert_ne(settled_tick, -1)
	assert_lte(settled_tick, 40)
	_assert_column_surfaces_flat(world, water_id, 2, 9)


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
	sliced_world.committed_fill = fast_world.committed_fill.duplicate()
	sliced_world.working_fill = fast_world.working_fill.duplicate()
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
	assert_eq(sliced_world.committed_fill, fast_world.committed_fill)


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


func _assert_column_surfaces_flat(world: WorldGrid, water_id: int, start_col: int, end_col: int) -> void:
	var expected_y := INF
	for col in range(start_col, end_col + 1):
		var surface_y := _top_water_surface_y(world, water_id, col)
		assert_ne(surface_y, INF)
		if expected_y == INF:
			expected_y = surface_y
		else:
			assert_almost_eq(surface_y, expected_y, 0.75)


func _top_water_surface_y(world: WorldGrid, water_id: int, col: int) -> float:
	for row in range(0, world.dimensions.depth):
		if world.get_committed_by_offset(col, row) != water_id:
			continue
		var fill := world.get_committed_fill_by_offset(col, row)
		if fill <= 0:
			continue
		return _cell_center_y(col, row) + _fill_line_y(fill)
	return INF


func _cell_center_y(col: int, row: int) -> float:
	return 16.0 * sqrt(3.0) * (float(row) + float(col & 1) * 0.5)


func _fill_line_y(fill: int) -> float:
	var half_height := 16.0 * sqrt(3.0) * 0.5
	return lerpf(half_height, -half_height, float(fill) / 255.0)
