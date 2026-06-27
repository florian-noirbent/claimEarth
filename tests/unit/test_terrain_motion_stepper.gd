extends GutTest


const TerrainMotionStepperScript = preload("res://src/simulation/terrain_motion_stepper.gd")
const TerrainSimulationContextScript = preload("res://src/simulation/terrain_simulation_context.gd")
const TerrainTransferSolverScript = preload("res://src/simulation/terrain_transfer_solver.gd")


func test_full_fall_prevents_side_flow_after_source_empties() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	world.set_committed_by_offset(3, 3, water_id)
	var context = _context_for(world, registry)
	var stepper = TerrainMotionStepperScript.new()

	stepper.step(_index(world, 3, 3), context)

	assert_eq(world.get_working_by_offset(3, 4), water_id)
	assert_eq(world.get_working_fill_by_offset(2, 4), 0)
	assert_eq(world.get_working_fill_by_offset(4, 4), 0)


func test_partial_fall_can_be_followed_by_side_flow_in_same_cell_step() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var water_id := FixtureLoader.terrain_id("Water")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, water_id)
	world.set_committed_by_offset(3, 4, water_id, 200)
	world.set_committed_by_offset(4, 4, stone_id)
	var context = _context_for(world, registry)
	var stepper = TerrainMotionStepperScript.new()

	stepper.step(_index(world, 3, 3), context)

	assert_eq(world.get_working_fill_by_offset(3, 3), 36)
	assert_eq(world.get_working_fill_by_offset(3, 4), 255)
	assert_eq(world.get_working_by_offset(2, 4), water_id)
	assert_eq(world.get_working_fill_by_offset(2, 4), 164)


func test_side_down_can_be_followed_by_side_up_after_reread() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
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
	var context = _context_for(world, registry)
	var stepper = TerrainMotionStepperScript.new()

	stepper.step(_index(world, 3, 3), context)

	assert_eq(world.get_working_fill_by_offset(3, 3), 154)
	assert_eq(world.get_working_fill_by_offset(2, 4), 255)
	assert_eq(world.get_working_by_offset(2, 3), water_id)
	assert_eq(world.get_working_fill_by_offset(2, 3), 26)


func test_sand_never_side_up_flows() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	var stone_id := FixtureLoader.terrain_id("Stone")
	world.set_committed_by_offset(3, 3, sand_id)
	world.set_committed_by_offset(3, 4, stone_id)
	world.set_committed_by_offset(2, 4, stone_id)
	world.set_committed_by_offset(4, 4, stone_id)
	var context = _context_for(world, registry)
	var stepper = TerrainMotionStepperScript.new()

	stepper.step(_index(world, 3, 3), context)

	assert_eq(world.get_working_by_offset(3, 3), sand_id)
	assert_eq(world.get_working_fill_by_offset(2, 3), 0)
	assert_eq(world.get_working_fill_by_offset(4, 3), 0)


func test_tick_parity_changes_side_target_order_deterministically() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var even_context = _context_for(world, registry, 0)
	var odd_context = _context_for(world, registry, 1)
	var stepper = TerrainMotionStepperScript.new()

	assert_eq(stepper.side_targets(3, 3, TerrainTransferSolverScript.DIRECTION_SIDE_DOWN, even_context), [_index(world, 2, 4), _index(world, 4, 4)])
	assert_eq(stepper.side_targets(3, 3, TerrainTransferSolverScript.DIRECTION_SIDE_DOWN, odd_context), [_index(world, 4, 4), _index(world, 2, 4)])


func _context_for(world: WorldGrid, registry: TerrainRegistry, tick: int = 0):
	world.reset_working_from_committed()
	var context = TerrainSimulationContextScript.new()
	context.configure(world.dimensions, CompiledTerrainData.compile(registry), world.working_cells, world.working_fill, tick)
	return context


func _index(world: WorldGrid, col: int, row: int) -> int:
	return world.dimensions.offset_to_index(col, row)
