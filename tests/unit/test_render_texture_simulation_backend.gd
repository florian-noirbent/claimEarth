extends GutTest


const RenderTextureSimulationBackendScript = preload("res://src/simulation/render_texture_simulation_backend.gd")


func test_six_advances_complete_one_logical_tick() -> void:
	var world := WorldGrid.new(WorldDimensions.new(3, 4), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(1, 1, FixtureLoader.terrain_id("Sand"))
	var backend = _backend(world, 1)

	for pass_index in range(5):
		var progress = backend.advance(0)
		assert_false(progress.step_completed, "pass %d completed too early" % pass_index)
		assert_true(backend.is_tick_in_progress())

	var final_progress = backend.advance(0)
	assert_true(final_progress.step_completed)
	assert_false(backend.is_tick_in_progress())
	assert_eq(backend.ticks_completed(), 1)


func test_gpu_backend_keeps_two_even_phase_targets_and_one_final_target() -> void:
	var world := WorldGrid.new(WorldDimensions.new(3, 4), FixtureLoader.terrain_id("Air"))
	var backend = _backend(world, 40)

	assert_eq(backend.render_root().get_child_count(), RenderTextureSimulationBackendScript.RENDER_TARGET_COUNT)


func test_falling_uses_density_to_displace_lighter_passable_material() -> void:
	var world := WorldGrid.new(WorldDimensions.new(1, 2), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	var lava_id := FixtureLoader.terrain_id("Lava")
	world.set_committed_by_offset(0, 0, sand_id)
	world.set_committed_by_offset(0, 1, lava_id)
	var backend = _backend(world, 2)

	_run_tick(backend)

	assert_eq(world.get_committed_by_offset(0, 0), lava_id)
	assert_eq(world.get_committed_by_offset(0, 1), sand_id)


func test_water_lava_contact_creates_stone_without_duplicate_liquid() -> void:
	var world := WorldGrid.new(WorldDimensions.new(1, 2), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var lava_id := FixtureLoader.terrain_id("Lava")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(0, 0, water_id)
	world.set_committed_by_offset(0, 1, lava_id)
	var backend = _backend(world, 3)

	_run_tick(backend)

	assert_eq(world.get_committed_by_offset(0, 0), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(0, 1), stone_id)
	assert_eq(world.count_committed(water_id), 0)
	assert_eq(world.count_committed(lava_id), 0)


func test_commit_updates_cpu_buffer_after_sixth_pass() -> void:
	var world := WorldGrid.new(WorldDimensions.new(3, 4), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(1, 1, FixtureLoader.terrain_id("Sand"))
	var original_bytes := world.copy_rgba_bytes()
	var backend = _backend(world, 4)

	_run_tick(backend)
	var commit: SimulationCommit = backend.commit_if_ready()

	assert_true(commit.did_commit)
	assert_ne(world.copy_rgba_bytes(), original_bytes)
	assert_gt(commit.changed_cell_count(), 0)


func test_even_phase_retains_water_before_odd_vertical_fall() -> void:
	var world := WorldGrid.new(WorldDimensions.new(1, 4), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(0, 0, water_id)
	var backend = _backend(world, 41)

	for _pass in range(RenderTextureSimulationBackendScript.EVEN_PHASE_PASS_COUNT):
		backend.advance(0)

	assert_eq(_texture_terrain_id(backend.presentation_even_texture(), 0, 0), FixtureLoader.terrain_id("Air"))
	assert_eq(_texture_terrain_id(backend.presentation_even_texture(), 0, 1), water_id)
	for _pass in range(RenderTextureSimulationBackendScript.PASS_COUNT - RenderTextureSimulationBackendScript.EVEN_PHASE_PASS_COUNT):
		backend.advance(0)

	assert_eq(world.get_committed_by_offset(0, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(0, 2), water_id)


func test_external_mutation_resets_even_phase_presentation_texture() -> void:
	var world := WorldGrid.new(WorldDimensions.new(1, 4), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(0, 0, water_id)
	var backend = _backend(world, 42)
	for _pass in range(RenderTextureSimulationBackendScript.EVEN_PHASE_PASS_COUNT):
		backend.advance(0)
	assert_eq(_texture_terrain_id(backend.presentation_even_texture(), 0, 1), water_id)

	var change_set := TerrainChangeSet.new(world.dimensions)
	var change := world.set_committed_by_offset(0, 0, stone_id)
	change_set.add_change(change.index, change.previous_id, change.next_id, null, change.previous_fill, change.next_fill)
	backend.notify_external_changes(change_set)

	assert_eq(backend.presentation_even_texture(), world.texture())


func test_settled_liquid_has_no_even_phase_difference() -> void:
	var world := WorldGrid.new(WorldDimensions.new(1, 2), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(0, 0, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(0, 1, FixtureLoader.terrain_id("Stone"))
	var backend = _backend(world, 43)

	_run_tick(backend)

	assert_eq(
		backend.presentation_even_texture().get_image().get_data(),
		backend.presentation_texture().get_image().get_data()
	)


func test_gameplay_mutation_cancels_unfinished_tick_and_patches_texture() -> void:
	var world := WorldGrid.new(WorldDimensions.new(4, 5), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(1, 1, sand_id)
	var backend = _backend(world, 5)
	backend.advance(0)
	assert_true(backend.is_tick_in_progress())

	var change_set := TerrainChangeSet.new(world.dimensions)
	var change := world.set_committed_by_offset(2, 2, stone_id)
	change_set.add_change(change.index, change.previous_id, change.next_id, null, change.previous_fill, change.next_fill)
	backend.notify_external_changes(change_set)

	assert_false(backend.is_tick_in_progress())
	assert_eq(roundi(world.cell_image.get_pixel(2, 2).r * 255.0), stone_id)


func test_pair_passes_preserve_material_fill_without_contact() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(2, 1, water_id, 128)
	world.set_committed_by_offset(3, 2, water_id, 64)
	var before_fill := _total_fill(world, water_id)
	var backend = _backend(world, 6)

	_run_tick(backend)

	assert_eq(_total_fill(world, water_id), before_fill)


func test_water_over_open_air_falls_vertically_without_leaf_swinging() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 8), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(3, 0, water_id)
	var backend = _backend(world, 7)

	_run_tick(backend)
	backend.commit_if_ready()
	_run_tick(backend)

	assert_eq(world.count_committed(water_id), 1)
	for row in range(world.dimensions.depth):
		for col in range(world.dimensions.width):
			if world.get_committed_by_offset(col, row) == water_id:
				assert_eq(col, 3)


func test_water_spreads_side_down_when_direct_bottom_is_blocked() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 6), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(2, 1, water_id)
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))
	var backend = _backend(world, 8)

	_run_tick(backend)

	var side_fill := 0
	for col in [1, 3]:
		if world.get_committed_by_offset(col, 1) == water_id:
			side_fill += world.get_committed_fill_by_offset(col, 1)
	assert_gt(side_fill, 0)


func test_sand_over_open_air_prefers_vertical_fall_before_side_down_creep() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 8), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	world.set_committed_by_offset(2, 0, sand_id)
	var backend = _backend(world, 9)

	_run_tick(backend)

	assert_eq(world.count_committed(sand_id), 1)
	for row in range(world.dimensions.depth):
		for col in range(world.dimensions.width):
			if world.get_committed_by_offset(col, row) == sand_id:
				assert_eq(col, 2)


func test_full_bottom_same_material_allows_side_down_flow() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 6), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(2, 1, water_id, 255)
	world.set_committed_by_offset(2, 2, water_id, 255)
	world.set_committed_by_offset(2, 3, FixtureLoader.terrain_id("Stone"))
	var backend = _backend(world, 10)

	_run_tick(backend)

	assert_eq(world.get_committed_by_offset(3, 1), water_id)
	assert_gt(world.get_committed_fill_by_offset(3, 1), 0)


func test_sand_does_not_bounce_upward_from_diagonal_target_side() -> void:
	var world := WorldGrid.new(WorldDimensions.new(2, 3), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(1, 1, sand_id)
	world.set_committed_by_offset(0, 2, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	var backend = _backend(world, 11)

	_run_tick(backend)

	assert_eq(world.get_committed_by_offset(0, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.count_committed(sand_id), 1)


func test_liquid_side_up_restores_sideways_leveling_when_lower_cell_is_high() -> void:
	var world := WorldGrid.new(WorldDimensions.new(2, 3), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(1, 1, water_id, 255)
	world.set_committed_by_offset(0, 2, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	var backend = _backend(world, 12)

	_run_tick(backend)

	assert_eq(world.get_committed_by_offset(0, 1), water_id)
	assert_gt(world.get_committed_fill_by_offset(0, 1), 0)
	assert_eq(_total_fill(world, water_id), 255)


func test_liquid_fills_bottom_side_before_up_side() -> void:
	var world := WorldGrid.new(WorldDimensions.new(3, 3), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(1, 1, water_id, 255)
	world.set_committed_by_offset(1, 2, stone_id)
	var backend = _backend(world, 13)

	_run_tick(backend)

	assert_eq(world.get_committed_by_offset(0, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(2, 2), water_id)
	assert_gt(world.get_committed_fill_by_offset(2, 2), 0)
	assert_eq(_total_fill(world, water_id), 255)


func test_liquid_side_up_uses_top_half_equilibrium() -> void:
	var world := WorldGrid.new(WorldDimensions.new(2, 3), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(0, 1, water_id, 32)
	world.set_committed_by_offset(1, 1, water_id, 160)
	world.set_committed_by_offset(0, 2, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	var backend = _backend(world, 14)

	_run_tick(backend)

	assert_eq(world.get_committed_fill_by_offset(0, 1), 32)
	assert_eq(world.get_committed_fill_by_offset(1, 1), 160)
	assert_eq(_total_fill(world, water_id), 192)


func test_liquid_side_up_never_fills_target_above_half() -> void:
	var world := WorldGrid.new(WorldDimensions.new(2, 3), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(0, 1, water_id, 120)
	world.set_committed_by_offset(1, 1, water_id, 255)
	world.set_committed_by_offset(0, 2, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	var backend = _backend(world, 15)

	_run_ticks(backend, 6)

	assert_lte(world.get_committed_fill_by_offset(0, 1), 128)
	assert_eq(_total_fill(world, water_id), 375)


func test_lava_side_up_respects_transfer_rate() -> void:
	var world := WorldGrid.new(WorldDimensions.new(2, 3), FixtureLoader.terrain_id("Air"))
	var lava_id := FixtureLoader.terrain_id("Lava")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(1, 1, lava_id, 255)
	world.set_committed_by_offset(0, 2, stone_id)
	world.set_committed_by_offset(1, 2, stone_id)
	var backend = _backend(world, 16)

	_run_tick(backend)

	assert_eq(world.get_committed_by_offset(0, 1), lava_id)
	assert_eq(world.get_committed_fill_by_offset(0, 1), 8)
	assert_eq(world.get_committed_fill_by_offset(1, 1), 247)
	assert_eq(_total_fill(world, lava_id), 255)


func test_water_basin_reaches_known_output_after_multiple_ticks() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 4), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	for col in range(5):
		world.set_committed_by_offset(col, 3, stone_id)
	world.set_committed_by_offset(0, 2, stone_id)
	world.set_committed_by_offset(4, 2, stone_id)
	world.set_committed_by_offset(1, 1, water_id, 255)
	world.set_committed_by_offset(2, 1, water_id, 128)
	world.set_committed_by_offset(3, 1, water_id, 64)
	var backend = _backend(world, 17)

	_run_ticks(backend, 12)
	var settled_snapshot := _terrain_fill_snapshot(world)
	_run_tick(backend)

	assert_eq(_total_fill(world, water_id), 447)
	assert_eq(_terrain_fill_snapshot(world), settled_snapshot)
	assert_eq(settled_snapshot, [
		"0:000 0:000 0:000 0:000 0:000",
		"0:000 0:000 0:000 0:000 0:000",
		"1:255 4:208 4:079 4:160 1:255",
		"1:255 1:255 1:255 1:255 1:255",
	])


func _backend(world: WorldGrid, seed: int):
	var backend = RenderTextureSimulationBackendScript.new()
	backend.initialize(world, FixtureLoader.terrain_registry(), seed)
	add_child_autofree(backend.render_root())
	return backend


func _run_tick(backend) -> void:
	for _pass in range(RenderTextureSimulationBackendScript.PASS_COUNT):
		backend.advance(0)


func _run_ticks(backend, count: int) -> void:
	for _tick in range(count):
		_run_tick(backend)


func _total_fill(world: WorldGrid, cell_id: int) -> int:
	var total := 0
	for row in range(world.dimensions.depth):
		for col in range(world.dimensions.width):
			if world.get_committed_by_offset(col, row) == cell_id:
				total += world.get_committed_fill_by_offset(col, row)
	return total


func _terrain_fill_snapshot(world: WorldGrid) -> Array[String]:
	var rows: Array[String] = []
	for row in range(world.dimensions.depth):
		var cells: Array[String] = []
		for col in range(world.dimensions.width):
			cells.append("%d:%03d" % [
				world.get_committed_by_offset(col, row),
				world.get_committed_fill_by_offset(col, row),
			])
		rows.append(" ".join(cells))
	return rows


func _texture_terrain_id(texture: Texture2D, col: int, row: int) -> int:
	return roundi(texture.get_image().get_pixel(col, row).r * 255.0)
