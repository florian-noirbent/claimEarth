extends GutTest


const TerrainCollisionQueryScript = preload("res://src/world/terrain_collision_query.gd")
const TerrainBodyMotionSolverScript = preload("res://src/world/terrain_body_motion_solver.gd")
## Rows and columns beyond every map edge that the brute-force references scan.
const REFERENCE_BORDER_CELLS := 5


func test_circle_does_not_overlap_air() -> void:
	var query = _query_for_world(WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air")))

	assert_false(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_out_of_bounds_cells_are_solid_at_the_sides_and_bottom_and_open_above() -> void:
	var query = _query_for_world(WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air")))

	assert_true(query.is_solid_cell(-1, 2))
	assert_true(query.is_solid_cell(5, 2))
	assert_true(query.is_solid_cell(2, 5))
	assert_false(query.is_solid_cell(2, -1), "The sky above the top row is open")
	assert_false(query.is_solid_cell(4, -30))
	assert_true(query.is_solid_cell(-1, -1), "The side walls continue above the map")
	assert_true(query.is_solid_cell(5, -30))


func test_body_stands_on_the_top_row_and_stays_between_the_side_walls_above_it() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Stone"))
	var query = _query_for_world(world)
	var solver = TerrainBodyMotionSolverScript.new()
	solver.configure(query)
	var above_top := HexMetrics.center_for_offset(2, -2, 16.0)

	assert_false(query.circle_overlaps_solid(above_top, 14.0))
	var landed = solver.move_circle(above_top, Vector2(0.0, 600.0), 0.5, 14.0, 14.0, 8.0, false)
	assert_true(landed.grounded)
	assert_lt(landed.position.y, HexMetrics.center_for_offset(2, 0, 16.0).y)

	var pushed = solver.move_circle(above_top, Vector2(-2000.0, 0.0), 0.5, 14.0, 14.0, 8.0, false)
	assert_gt(pushed.position.x, HexMetrics.center_for_offset(0, -2, 16.0).x - 16.0)


func test_circle_and_polygon_collide_with_virtual_map_edge_cells() -> void:
	var query = _query_for_world(WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air")))
	var outside_center := HexMetrics.center_for_offset(-1, 2, 16.0)
	var chest_polygon := PackedVector2Array([
		outside_center + Vector2(-12.0, -8.0),
		outside_center + Vector2(12.0, -8.0),
		outside_center + Vector2(12.0, 8.0),
		outside_center + Vector2(-12.0, 8.0),
	])

	assert_true(query.circle_overlaps_solid(outside_center, 8.0))
	assert_true(query.convex_polygon_overlaps_solid(chest_polygon))


func test_circle_overlaps_solid_static_terrain() -> void:
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))
	var query = _query_for_world(world)

	assert_true(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_sand_below_collision_threshold_is_passable() -> void:
	var sand_id := FixtureLoader.terrain_id("Sand")
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, sand_id, 63)
	var query = _query_for_world(world)

	assert_false(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_sand_at_collision_threshold_is_solid() -> void:
	var sand_id := FixtureLoader.terrain_id("Sand")
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, sand_id, 64)
	var query = _query_for_world(world)

	assert_true(query.circle_overlaps_solid(HexMetrics.center_for_offset(2, 2, 16.0), 14.0))


func test_quantity_weighted_viscosity_uses_committed_fluid_quantity() -> void:
	var water_id := FixtureLoader.terrain_id("Water")
	var lava_id := FixtureLoader.terrain_id("Lava")
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var water_center := HexMetrics.center_for_offset(1, 2, 16.0)
	var lava_center := HexMetrics.center_for_offset(3, 2, 16.0)
	world.set_committed_by_offset(1, 2, water_id, 127)
	world.set_committed_by_offset(3, 2, lava_id, 127)
	var query = _query_for_world(world)

	assert_almost_eq(
		query.quantity_weighted_viscosity_at_world(water_center),
		0.8,
		0.001
	)
	assert_almost_eq(query.quantity_weighted_viscosity_at_world(lava_center), 4.0, 0.001)
	assert_almost_eq(
		query.quantity_weighted_viscosity_at_world(HexMetrics.center_for_offset(2, 2, 16.0)),
		0.0,
		0.001
	)
	assert_almost_eq(query.quantity_weighted_viscosity_at_world(Vector2(-100.0, -100.0)), 0.0, 0.001)


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


func test_circle_contacts_match_brute_force_reference_inside_and_around_the_map() -> void:
	for hex_radius: float in [8.0, 16.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260511
		var world := _seeded_world(rng)
		var query = _query_for_world(world, hex_radius)
		var mismatches := PackedStringArray()
		for _sample in 250:
			var position := _seeded_position(rng, world, hex_radius)
			var radius := rng.randf_range(0.1, 2.5) * hex_radius
			var expected := _brute_force_circle_contacts(query, position, radius)
			if query.circle_contacts(position, radius) != expected:
				mismatches.append("%s r=%s" % [position, radius])

		assert_eq(mismatches, PackedStringArray(), "hex radius %s" % hex_radius)


func test_polygon_overlap_matches_brute_force_reference_inside_and_around_the_map() -> void:
	for hex_radius: float in [8.0, 16.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260512
		var world := _seeded_world(rng)
		var query = _query_for_world(world, hex_radius)
		var mismatches := PackedStringArray()
		var overlap_count := 0
		for sample in 200:
			var polygon := _seeded_polygon(rng, world, hex_radius, sample % 2 == 0)
			var expected := _brute_force_polygon_overlap(query, polygon)
			overlap_count += 1 if expected else 0
			if query.convex_polygon_overlaps_solid(polygon) != expected:
				mismatches.append(str(polygon))

		assert_eq(mismatches, PackedStringArray(), "hex radius %s" % hex_radius)
		assert_between(overlap_count, 20, 180, "The sample must exercise both outcomes")


func test_cells_touching_rect_covers_every_cell_overlapping_the_rectangle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260513
	var world := WorldGrid.new(WorldDimensions.new(10, 8), FixtureLoader.terrain_id("Air"))
	var query = _query_for_world(world)
	var corners := HexMetrics.corners(16.0)
	for _sample in 40:
		var rect := Rect2(
			_seeded_position(rng, world, 16.0),
			Vector2(rng.randf_range(0.0, 48.0), rng.randf_range(0.0, 48.0))
		)
		var rect_polygon := PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		var cells: Rect2i = query.cells_touching_rect(rect)
		for row in range(-REFERENCE_BORDER_CELLS, world.dimensions.depth + REFERENCE_BORDER_CELLS):
			for col in range(-REFERENCE_BORDER_CELLS, world.dimensions.width + REFERENCE_BORDER_CELLS):
				var hex_polygon := PackedVector2Array()
				for corner in corners:
					hex_polygon.append(HexMetrics.center_for_offset(col, row, 16.0) + corner)
				if query._convex_polygons_overlap(rect_polygon, hex_polygon) and not cells.has_point(Vector2i(col, row)):
					fail_test("Cell (%d, %d) overlaps %s but is outside %s" % [col, row, rect, cells])
					return
	pass_test("Every overlapping cell is inside the reported range")


func test_cell_states_flag_solid_air_and_virtual_edge_cells() -> void:
	var world := WorldGrid.new(WorldDimensions.new(4, 3), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(1, 0, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(2, 0, FixtureLoader.terrain_id("Water"))
	var query = _query_for_world(world)
	var cells := Rect2i(-1, 0, 4, 1)
	var solid: int = TerrainCollisionQueryScript.CELL_STATE_SOLID
	var air: int = TerrainCollisionQueryScript.CELL_STATE_AIR

	assert_eq(query.cell_states(cells), PackedByteArray([solid, 0, solid, 0]))
	assert_eq(query.cell_states(cells, true), PackedByteArray([solid, air, solid, 0]))
	assert_eq(query.cell_states(Rect2i(0, 0, 0, 0)), PackedByteArray())
	assert_eq(
		query.cell_states(Rect2i(0, -1, 2, 5)),
		PackedByteArray([0, 0, 0, solid, 0, 0, 0, 0, solid, solid]),
		"The row above the world is open sky and the row below is virtual solid cells"
	)

	query.set_ignored_solid_ids(PackedInt32Array([FixtureLoader.terrain_id("Stone")]))
	assert_eq(query.cell_states(cells, true), PackedByteArray([solid, air, 0, 0]))


func _seeded_world(rng: RandomNumberGenerator) -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(10, 8), FixtureLoader.terrain_id("Air"))
	var stone_id := FixtureLoader.terrain_id("Stone")
	var water_id := FixtureLoader.terrain_id("Water")
	for row in world.dimensions.depth:
		for col in world.dimensions.width:
			var roll := rng.randf()
			if roll < 0.3:
				world.set_committed_by_offset(col, row, stone_id)
			elif roll < 0.4:
				world.set_committed_by_offset(col, row, water_id)
	return world


## Samples positions inside the map and up to three hexes beyond every edge, including negative coordinates.
func _seeded_position(rng: RandomNumberGenerator, world: WorldGrid, hex_radius: float) -> Vector2:
	var far_corner := HexMetrics.center_for_offset(world.dimensions.width - 1, world.dimensions.depth - 1, hex_radius)
	var slack := hex_radius * 3.0
	return Vector2(
		rng.randf_range(-slack, far_corner.x + slack),
		rng.randf_range(-slack, far_corner.y + slack)
	)


func _seeded_polygon(
	rng: RandomNumberGenerator,
	world: WorldGrid,
	hex_radius: float,
	rectangle: bool
) -> PackedVector2Array:
	var center := _seeded_position(rng, world, hex_radius)
	var polygon := PackedVector2Array()
	if rectangle:
		var half_size := Vector2(rng.randf_range(0.1, 2.0), rng.randf_range(0.1, 2.0)) * hex_radius
		var transform := Transform2D(rng.randf_range(-PI, PI), center)
		for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
			polygon.append(transform * (corner * half_size))
	else:
		var start_angle := rng.randf_range(-PI, PI)
		for corner_index in 3:
			var angle := start_angle + TAU * float(corner_index) / 3.0 + rng.randf_range(-0.5, 0.5)
			polygon.append(center + Vector2.from_angle(angle) * rng.randf_range(0.1, 2.0) * hex_radius)
	return polygon


## Tests every cell of the map and its border row by row, without any candidate range.
func _brute_force_circle_contacts(query, position: Vector2, radius: float) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	var dimensions: WorldDimensions = query.world.dimensions
	for row in range(-REFERENCE_BORDER_CELLS, dimensions.depth + REFERENCE_BORDER_CELLS):
		for col in range(-REFERENCE_BORDER_CELLS, dimensions.width + REFERENCE_BORDER_CELLS):
			if not query.is_solid_cell(col, row):
				continue
			var contact: Dictionary = query._circle_hex_contact(position, radius, Vector2i(col, row))
			if bool(contact.get("colliding", false)):
				contacts.append(contact)
	return contacts


## Tests every cell of the map and its border, using the axial hex path for cell centers.
func _brute_force_polygon_overlap(query, polygon: PackedVector2Array) -> bool:
	var dimensions: WorldDimensions = query.world.dimensions
	var corners := HexMetrics.corners(query.hex_radius)
	for row in range(-REFERENCE_BORDER_CELLS, dimensions.depth + REFERENCE_BORDER_CELLS):
		for col in range(-REFERENCE_BORDER_CELLS, dimensions.width + REFERENCE_BORDER_CELLS):
			if not query.is_solid_cell(col, row):
				continue
			var center := HexCoord.from_offset_odd_q(col, row).to_world_position(query.hex_radius)
			var hex_polygon := PackedVector2Array()
			for corner in corners:
				hex_polygon.append(center + corner)
			if query._convex_polygons_overlap(polygon, hex_polygon):
				return true
	return false


func _query_for_world(world: WorldGrid, hex_radius: float = 16.0):
	var query = TerrainCollisionQueryScript.new()
	query.configure(world, CompiledTerrainData.compile(FixtureLoader.terrain_registry()), hex_radius)
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
