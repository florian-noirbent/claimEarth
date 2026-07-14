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


func test_fill_weighted_viscosity_uses_committed_fluid_fill() -> void:
	var water_id := FixtureLoader.terrain_id("Water")
	var lava_id := FixtureLoader.terrain_id("Lava")
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var water_center := HexMetrics.center_for_offset(1, 2, 16.0)
	var lava_center := HexMetrics.center_for_offset(3, 2, 16.0)
	world.set_committed_by_offset(1, 2, water_id, 128)
	world.set_committed_by_offset(3, 2, lava_id, 255)
	var query = _query_for_world(world)

	assert_almost_eq(
		query.fill_weighted_viscosity_at_world(water_center),
		0.8 * 128.0 / 255.0,
		0.001
	)
	assert_almost_eq(query.fill_weighted_viscosity_at_world(lava_center), 4.0, 0.001)
	assert_almost_eq(
		query.fill_weighted_viscosity_at_world(HexMetrics.center_for_offset(2, 2, 16.0)),
		0.0,
		0.001
	)
	assert_almost_eq(query.fill_weighted_viscosity_at_world(Vector2(-100.0, -100.0)), 0.0, 0.001)


func test_nearest_clear_circle_air_center_skips_cramped_current_cell_and_prefers_up() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var origin_cell := Vector2i(3, 3)
	var origin_hex := HexCoord.from_offset_odd_q(origin_cell.x, origin_cell.y)
	for direction in [0, 4, 5]:
		var wall := origin_hex.neighbor(direction).to_offset_odd_q()
		world.set_committed_by_offset(wall.x, wall.y, FixtureLoader.terrain_id("Stone"))
	var query = _query_for_world(world)
	var origin := HexMetrics.center_for_offset(origin_cell.x, origin_cell.y, 16.0)
	var above := origin_hex.neighbor(2).to_offset_odd_q()

	var center = query.nearest_clear_circle_air_center(origin, 14.0, 3)

	assert_true(query.circle_overlaps_solid(origin, 14.0))
	assert_eq(center, HexMetrics.center_for_offset(above.x, above.y, 16.0))


func test_nearest_clear_circle_air_center_uses_left_tie_break_after_distance_and_height() -> void:
	var world := WorldGrid.new(WorldDimensions.new(15, 15), FixtureLoader.terrain_id("Stone"))
	var origin_cell := Vector2i(7, 7)
	var origin_hex := HexCoord.from_offset_odd_q(origin_cell.x, origin_cell.y)
	var left_hex := origin_hex.add(HexCoord.new(-2, 1))
	var right_hex := origin_hex.add(HexCoord.new(2, -1))
	_set_air_hex_radius(world, left_hex, 1)
	_set_air_hex_radius(world, right_hex, 1)
	var query = _query_for_world(world)
	var origin := HexMetrics.center_for_offset(origin_cell.x, origin_cell.y, 16.0)

	var center = query.nearest_clear_circle_air_center(origin, 14.0, 3)
	var left_cell := left_hex.to_offset_odd_q()

	assert_eq(center, HexMetrics.center_for_offset(left_cell.x, left_cell.y, 16.0))


func test_nearest_clear_circle_air_center_returns_null_when_air_has_no_body_clearance() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Stone"))
	var origin_cell := Vector2i(2, 2)
	world.set_committed_by_offset(origin_cell.x, origin_cell.y, FixtureLoader.terrain_id("Air"))
	var query = _query_for_world(world)
	var origin := HexMetrics.center_for_offset(origin_cell.x, origin_cell.y, 16.0)

	assert_true(query.circle_overlaps_solid(origin, 14.0))
	assert_null(query.nearest_clear_circle_air_center(origin, 14.0, 2))


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
	assert_almost_eq(result.velocity_change.length(), 220.0, 0.01)


func test_collision_reports_complete_before_after_velocity_change() -> void:
	var world := WorldGrid.new(WorldDimensions.new(7, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Stone"))
	var solver = _solver_for_world(world)
	var start := HexMetrics.center_for_offset(2, 2, 16.0) + Vector2(-4.0, 0.0)
	var incoming_velocity := Vector2(600.0, 80.0)

	var result = solver.move_circle(start, incoming_velocity, 0.1, 14.0, 0.0, 0.0)

	assert_true(result.collided)
	assert_eq(result.velocity_change, result.velocity - incoming_velocity)
	assert_gt(result.velocity_change.length(), 300.0)


func test_support_probe_does_not_ground_a_falling_body_before_contact() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 6), FixtureLoader.terrain_id("Air"))
	var floor_cell := Vector2i(2, 3)
	world.set_committed_by_offset(floor_cell.x, floor_cell.y, FixtureLoader.terrain_id("Stone"))
	var solver = _solver_for_world(world)
	var floor_center := HexMetrics.center_for_offset(floor_cell.x, floor_cell.y, 16.0)
	var start := floor_center + Vector2(0.0, -(16.0 * sqrt(3.0) * 0.5 + 16.0))

	var falling = solver.move_circle(start, Vector2(0.0, 10.0), 0.001, 14.0, 0.0, 8.0)
	var supported = solver.move_circle(start, Vector2.ZERO, 0.001, 14.0, 0.0, 8.0, true)

	assert_false(falling.collided)
	assert_false(falling.grounded)
	assert_false(supported.collided)
	assert_true(supported.grounded)


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


func _set_air_hex_radius(world: WorldGrid, center: HexCoord, radius: int) -> void:
	for delta_q in range(-radius, radius + 1):
		var min_delta_r := maxi(-radius, -delta_q - radius)
		var max_delta_r := mini(radius, -delta_q + radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var cell := center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q()
			if world.dimensions.is_in_bounds_offset(cell.x, cell.y):
				world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Air"))
