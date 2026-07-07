extends GutTest


const TerrainSimulationContextScript = preload("res://src/simulation/terrain_simulation_context.gd")
const TerrainTransferSolverScript = preload("res://src/simulation/terrain_transfer_solver.gd")


func test_fall_transfer_moves_fill_into_air() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(2, 1, water_id)
	var context = _context_for(world, registry)
	var solver = TerrainTransferSolverScript.new()

	assert_true(solver.try_transfer(_index(world, 2, 1), _index(world, 2, 2), TerrainTransferSolverScript.DIRECTION_FALL, context))

	assert_eq(world.get_working_by_offset(2, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_working_fill_by_offset(2, 1), 0)
	assert_eq(world.get_working_by_offset(2, 2), water_id)
	assert_eq(world.get_working_fill_by_offset(2, 2), 255)


func test_side_transfer_capacity_clamps_to_offset_equilibrium() -> void:
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var solver = TerrainTransferSolverScript.new()
	var water_id := FixtureLoader.terrain_id("Water")

	assert_eq(solver.side_transfer_capacity(water_id, 170, 100, TerrainTransferSolverScript.DIRECTION_SIDE_DOWN, metadata), 99)
	assert_eq(solver.side_transfer_capacity(water_id, 230, 70, TerrainTransferSolverScript.DIRECTION_SIDE_UP, metadata), 16)


func test_side_up_capacity_respects_source_threshold() -> void:
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var solver = TerrainTransferSolverScript.new()
	var water_id := FixtureLoader.terrain_id("Water")
	metadata.side_up_source_threshold_by_id[water_id] = 200

	assert_eq(solver.side_transfer_capacity(water_id, 199, 0, TerrainTransferSolverScript.DIRECTION_SIDE_UP, metadata), 0)
	assert_eq(solver.side_transfer_capacity(water_id, 200, 0, TerrainTransferSolverScript.DIRECTION_SIDE_UP, metadata), 36)


func test_split_budget_is_even_with_deterministic_remainder() -> void:
	var solver = TerrainTransferSolverScript.new()
	var candidates: Array[Dictionary] = [
		{"capacity": 255, "amount": 0},
		{"capacity": 255, "amount": 0},
	]

	solver.allocate_split_budget(candidates, 255)

	assert_eq(candidates[0]["amount"], 128)
	assert_eq(candidates[1]["amount"], 127)


func test_lava_minimum_difference_blocks_small_side_capacity() -> void:
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var solver = TerrainTransferSolverScript.new()
	var lava_id := FixtureLoader.terrain_id("Lava")

	assert_eq(solver.side_transfer_capacity(lava_id, 128, 100, TerrainTransferSolverScript.DIRECTION_SIDE_UP, metadata), 0)


func test_opposite_liquid_contact_resolves_to_stone_generically() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 1, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Lava"))
	var context = _context_for(world, registry)
	var solver = TerrainTransferSolverScript.new()

	assert_true(solver.try_transfer(_index(world, 2, 1), _index(world, 2, 2), TerrainTransferSolverScript.DIRECTION_FALL, context))

	assert_eq(world.get_working_by_offset(2, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_working_by_offset(2, 2), FixtureLoader.terrain_id("Stone"))
	assert_eq(world.get_working_fill_by_offset(2, 2), 255)


func test_falling_material_pushes_passable_moving_terrain_sideways_first() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(2, 1, sand_id)
	world.set_committed_by_offset(2, 2, water_id)
	var context = _context_for(world, registry)
	var solver = TerrainTransferSolverScript.new()

	assert_true(solver.try_transfer(_index(world, 2, 1), _index(world, 2, 2), TerrainTransferSolverScript.DIRECTION_FALL, context))

	assert_eq(world.get_working_by_offset(2, 1), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_working_fill_by_offset(2, 1), 0)
	assert_eq(world.get_working_by_offset(2, 2), sand_id)
	assert_eq(world.get_working_fill_by_offset(2, 2), 255)
	assert_eq(world.get_working_by_offset(1, 2), water_id)
	assert_eq(world.get_working_fill_by_offset(1, 2), 128)
	assert_eq(world.get_working_by_offset(3, 2), water_id)
	assert_eq(world.get_working_fill_by_offset(3, 2), 127)


func test_falling_material_swaps_remaining_displaced_fill_after_partial_side_push() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(2, 1, sand_id)
	world.set_committed_by_offset(2, 2, water_id)
	world.set_committed_by_offset(1, 2, water_id, 250)
	world.set_committed_by_offset(3, 2, stone_id)
	var context = _context_for(world, registry)
	var solver = TerrainTransferSolverScript.new()

	assert_true(solver.try_transfer(_index(world, 2, 1), _index(world, 2, 2), TerrainTransferSolverScript.DIRECTION_FALL, context))

	assert_eq(world.get_working_by_offset(2, 1), water_id)
	assert_eq(world.get_working_fill_by_offset(2, 1), 250)
	assert_eq(world.get_working_by_offset(2, 2), sand_id)
	assert_eq(world.get_working_fill_by_offset(2, 2), 255)
	assert_eq(world.get_working_by_offset(1, 2), water_id)
	assert_eq(world.get_working_fill_by_offset(1, 2), 255)


func test_falling_material_keeps_swap_fallback_when_displaced_fill_is_trapped() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(2, 1, sand_id, 96)
	world.set_committed_by_offset(2, 2, water_id, 192)
	world.set_committed_by_offset(1, 2, stone_id)
	world.set_committed_by_offset(3, 2, stone_id)
	var context = _context_for(world, registry)
	var solver = TerrainTransferSolverScript.new()

	assert_true(solver.try_transfer(_index(world, 2, 1), _index(world, 2, 2), TerrainTransferSolverScript.DIRECTION_FALL, context))

	assert_eq(world.get_working_by_offset(2, 1), water_id)
	assert_eq(world.get_working_fill_by_offset(2, 1), 192)
	assert_eq(world.get_working_by_offset(2, 2), sand_id)
	assert_eq(world.get_working_fill_by_offset(2, 2), 96)


func _context_for(world: WorldGrid, registry: TerrainRegistry, tick: int = 0):
	world.reset_working_from_committed()
	var context = TerrainSimulationContextScript.new()
	context.configure(world.dimensions, CompiledTerrainData.compile(registry), world.working_cells, world.working_fill, tick)
	return context


func _index(world: WorldGrid, col: int, row: int) -> int:
	return world.dimensions.offset_to_index(col, row)
