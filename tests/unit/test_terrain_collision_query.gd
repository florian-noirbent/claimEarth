extends GutTest


const TerrainCollisionQueryScript = preload("res://src/world/terrain_collision_query.gd")
const TerrainBodyMotionSolverScript = preload("res://src/world/terrain_body_motion_solver.gd")


func test_circle_does_not_overlap_air() -> void:
	var query = _query_for_world(WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air")))

	assert_false(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_circle_overlaps_solid_static_terrain() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))
	var query = _query_for_world(world)

	assert_true(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_sand_below_collision_threshold_is_passable() -> void:
	var sand_id := FixtureLoader.terrain_id("Sand")
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, sand_id, 127)
	var query = _query_for_world(world)

	assert_false(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_sand_at_collision_threshold_is_solid() -> void:
	var sand_id := FixtureLoader.terrain_id("Sand")
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, sand_id, 128)
	var query = _query_for_world(world)

	assert_true(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_nearest_air_cell_center_finds_closest_air() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(4, 2, FixtureLoader.terrain_id("Air"))
	var query = _query_for_world(world)

	var center = query.nearest_air_cell_center(HexMetrics.center_for_offset(2, 2, 16.0), 3)

	assert_eq(center, HexMetrics.center_for_offset(4, 2, 16.0))


func test_nearest_air_cell_center_uses_deterministic_tie_order() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(1, 2, FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Air"))
	var query = _query_for_world(world)

	var center = query.nearest_air_cell_center(HexMetrics.center_for_offset(2, 2, 16.0), 1)

	assert_eq(center, HexMetrics.center_for_offset(1, 2, 16.0))


func test_nearest_air_cell_center_returns_null_when_no_air_is_in_range() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(4, 4, FixtureLoader.terrain_id("Air"))
	var query = _query_for_world(world)

	assert_null(query.nearest_air_cell_center(HexMetrics.center_for_offset(2, 2, 16.0), 1))


func test_motion_stops_against_wall_and_preserves_tangent_velocity() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Stone"))
	var solver = _solver_for_world(world)
	var start := HexMetrics.center_for_offset(2, 2, 16.0) + Vector2(-4.0, 0.0)

	var result = solver.move_circle(start, Vector2(240.0, 80.0), 0.2, 14.0, 0.0, 0.0)

	assert_lt(result.position.x, HexMetrics.center_for_offset(3, 2, 16.0).x)
	assert_lt(result.velocity.x, 120.0)
	assert_gt(result.velocity.length(), 1.0)
	assert_true(result.collided)


func test_downward_motion_lands_and_reports_grounded() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 6), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 3, FixtureLoader.terrain_id("Stone"))
	var solver = _solver_for_world(world)
	var start := HexMetrics.center_for_offset(2, 2, 16.0) + Vector2(0.0, -8.0)

	var result = solver.move_circle(start, Vector2(0.0, 220.0), 0.2, 14.0, 0.0, 8.0)

	assert_true(result.grounded)
	assert_lte(result.velocity.y, 1.0)


func test_step_up_raises_body_when_horizontal_motion_is_blocked() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Stone"))
	var solver = _solver_for_world(world)
	var start := HexMetrics.center_for_offset(2, 2, 16.0) + Vector2(-4.0, 0.0)

	var blocked = solver.move_circle(start, Vector2(180.0, 0.0), 0.12, 14.0, 0.0, 0.0)
	var stepped = solver.move_circle(start, Vector2(180.0, 0.0), 0.12, 14.0, 14.0, 0.0)

	assert_lt(stepped.position.y, blocked.position.y)


func test_step_up_is_skipped_when_not_allowed() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Stone"))
	var solver = _solver_for_world(world)
	var start := HexMetrics.center_for_offset(2, 2, 16.0) + Vector2(-4.0, 0.0)

	var blocked = solver.move_circle(start, Vector2(180.0, 0.0), 0.12, 14.0, 14.0, 0.0, false)
	var stepped = solver.move_circle(start, Vector2(180.0, 0.0), 0.12, 14.0, 14.0, 0.0, true)

	assert_gt(blocked.position.y, stepped.position.y)


func _query_for_world(world: WorldGrid):
	var query = TerrainCollisionQueryScript.new()
	query.configure(world, CompiledTerrainData.compile(FixtureLoader.terrain_registry()), 16.0)
	return query


func _solver_for_world(world: WorldGrid):
	var solver = TerrainBodyMotionSolverScript.new()
	solver.configure(_query_for_world(world))
	return solver
