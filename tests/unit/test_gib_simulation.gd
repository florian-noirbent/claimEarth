extends GutTest
## Covers the loose body parts of a death: bounce, rest, liquids, and the guarantees that a
## part never passes through terrain and never moves forever.


const STEP := 1.0 / 60.0
const HEX := 16.0
const FLOOR_ROW := 12


func test_a_dropped_gib_bounces_then_rests_on_the_floor() -> void:
	var query := _query(_room("Air"))
	var simulation := _simulation(query)
	var gib := simulation.add_gib(_above_floor(120.0), Vector2(60.0, 0.0), 0.0, 4.0, 5.0, 0.5)
	var bounced := false
	var hardest := 0.0

	for _step in 600:
		simulation.step(STEP)
		hardest = maxf(hardest, simulation.impact_speed_of(gib))
		if simulation.impact_speed_of(gib) > 100.0 and simulation.velocity_of(gib).y < -20.0:
			bounced = true
			assert_lt(simulation.impact_normal_of(gib).y, -0.3, "The floor pushes upward")
		assert_false(query.is_solid_at_world(simulation.position_of(gib)), "The gib stays out of terrain")

	assert_true(bounced, "A bouncy gib leaves the floor again")
	assert_gt(hardest, 300.0, "The landing is reported with its speed")
	assert_true(simulation.is_asleep(gib), "The gib comes to rest")
	assert_true(simulation.all_asleep())
	assert_eq(simulation.velocity_of(gib), Vector2.ZERO)
	assert_false(query.circle_overlaps_solid(simulation.position_of(gib), simulation.radius_of(gib) - 0.5))
	assert_true(query.circle_overlaps_solid(simulation.position_of(gib) + Vector2(0.0, 3.0), simulation.radius_of(gib)), "It lies on the floor")
	var rested := simulation.position_of(gib)
	for _step in 30:
		simulation.step(STEP)
	assert_eq(simulation.position_of(gib), rested, "A resting gib no longer moves")


func test_fast_gibs_never_tunnel_through_terrain() -> void:
	var query := _query(_room("Air"))
	var directions: Array[Vector2] = [Vector2.DOWN, Vector2(1.0, 0.4).normalized(), Vector2(-1.0, 0.2).normalized(), Vector2(0.6, 1.0).normalized()]
	for radius: float in [2.5, 5.0, 12.0]:
		var simulation := _simulation(query)
		for direction in directions:
			simulation.add_gib(_above_floor(60.0), direction * 9000.0, 0.0, 0.0, radius, 0.6)
		for _step in 240:
			simulation.step(STEP)
			for gib in simulation.count():
				var position := simulation.position_of(gib)
				assert_false(query.is_solid_at_world(position), "A gib of radius %s never enters terrain" % radius)
				assert_lt(position.y, HexMetrics.center_for_offset(8, FLOOR_ROW, HEX).y)


func test_equal_input_gives_equal_motion() -> void:
	var first := _thrown_handful(_query(_room("Air")))
	var second := _thrown_handful(_query(_room("Air")))

	for _step in 180:
		first.step(STEP)
		second.step(STEP)

	for gib in first.count():
		assert_eq(first.position_of(gib), second.position_of(gib))
		assert_eq(first.angle_of(gib), second.angle_of(gib))
		assert_eq(first.velocity_of(gib), second.velocity_of(gib))


func test_liquid_slows_a_gib_and_buoyancy_holds_it_up() -> void:
	var in_air := _simulation(_query(_room("Air")))
	var in_water := _simulation(_query(_room("Water")))
	var in_lava := _simulation(_query(_room("Lava")))
	var floating := _simulation(_query(_room("Water")))
	floating.buoyancy = 1.0
	var start := _above_floor(260.0)
	for simulation: GibSimulation in [in_air, in_water, in_lava, floating]:
		simulation.add_gib(start, Vector2(200.0, 0.0), 0.0, 10.0, 4.0, 0.3)
		for _step in 20:
			simulation.step(STEP)

	var air_travel := in_air.position_of(0) - start
	var water_travel := in_water.position_of(0) - start
	var lava_travel := in_lava.position_of(0) - start
	assert_lt(water_travel.x, air_travel.x, "Water slows a gib sideways")
	assert_lt(water_travel.y, air_travel.y, "and as it sinks")
	assert_lt(lava_travel.length(), water_travel.length(), "Thick lava slows it more")
	assert_lt(absf(in_water.spin_of(0)), absf(in_air.spin_of(0)), "Liquid also stops the spin")
	assert_almost_eq(floating.position_of(0).y, start.y, 0.5, "Full buoyancy cancels gravity")


func test_a_gib_without_terrain_is_lost_instead_of_falling_forever() -> void:
	var simulation := GibSimulation.new()
	simulation.configure(null, Vector2.ZERO)
	simulation.maximum_distance = 500.0
	var gib := simulation.add_gib(Vector2.ZERO, Vector2(50.0, 0.0), 0.0, 0.0, 4.0, 0.5)

	for _step in 600:
		simulation.step(STEP)

	assert_true(simulation.is_asleep(gib))
	assert_lte(simulation.position_of(gib).length(), 500.0)
	var stopped := simulation.position_of(gib)
	for _step in 60:
		simulation.step(STEP)
	assert_eq(simulation.position_of(gib), stopped)


func test_a_gib_enclosed_by_terrain_stays_where_it_is() -> void:
	var query := _query(_room("Stone"))
	var simulation := _simulation(query)
	var start := HexMetrics.center_for_offset(8, 6, HEX)
	var gib := simulation.add_gib(start, Vector2(300.0, -200.0), 0.0, 3.0, 4.0, 0.5)

	for _step in 30:
		simulation.step(STEP)

	assert_true(simulation.is_asleep(gib))
	assert_eq(simulation.position_of(gib), start, "A buried gib neither moves nor jumps through the rock")


func test_a_sleeping_gib_falls_again_when_its_support_is_removed() -> void:
	var world := _room("Air")
	var query := _query(world)
	var simulation := _simulation(query)
	var gib := simulation.add_gib(_above_floor(10.0), Vector2.ZERO, 0.0, 0.0, 4.0, 0.0)
	for _step in 120:
		simulation.step(STEP)
	assert_true(simulation.is_asleep(gib))
	var rested := simulation.position_of(gib)

	var air := FixtureLoader.terrain_id("Air")
	for col in world.dimensions.width:
		for row in [FLOOR_ROW, FLOOR_ROW + 1]:
			world.set_committed_by_offset(col, row, air)
	for _step in 40:
		simulation.step(STEP)

	assert_gt(simulation.position_of(gib).y, rested.y + 4.0, "The gib dropped into the hole")


func test_settling_stops_the_bouncing() -> void:
	var lively := _simulation(_query(_room("Air")))
	var settling := _simulation(_query(_room("Air")))
	settling.restitution_scale = 0.0
	settling.settle_drag = 3.0
	var asleep_at := {}
	for simulation: GibSimulation in [lively, settling]:
		simulation.add_gib(_above_floor(150.0), Vector2(120.0, 0.0), 0.0, 0.0, 5.0, 0.8)
		for step in 600:
			simulation.step(STEP)
			if simulation.is_asleep(0):
				asleep_at[simulation] = step
				break

	assert_true(asleep_at.has(settling))
	assert_lt(int(asleep_at[settling]), int(asleep_at.get(lively, 600)), "A settling gib rests sooner")


func _thrown_handful(query: TerrainCollisionQuery) -> GibSimulation:
	var simulation := _simulation(query)
	for index in 8:
		simulation.add_gib(
			_above_floor(40.0 + index * 6.0),
			Vector2(-300.0 + index * 90.0, -500.0 + index * 40.0),
			0.0,
			index - 4.0,
			3.0 + index * 0.5,
			0.2 + index * 0.08
		)
	return simulation


func _simulation(query: TerrainCollisionQuery) -> GibSimulation:
	var simulation := GibSimulation.new()
	simulation.configure(query, _above_floor(0.0))
	return simulation


## A room of the given terrain with a stone floor and stone walls.
func _room(fill_name: String) -> WorldGrid:
	var fill := FixtureLoader.terrain_id(fill_name)
	var stone := FixtureLoader.terrain_id("Stone")
	var world := WorldGrid.new(WorldDimensions.new(17, 16), fill)
	world.fill_committed(fill, FixtureLoader.terrain_registry().get_definition(fill).maximum_quantity)
	for row in world.dimensions.depth:
		for col in world.dimensions.width:
			if row >= FLOOR_ROW or col < 2 or col >= 15:
				world.set_committed_by_offset(col, row, stone)
	return world


func _query(world: WorldGrid) -> TerrainCollisionQuery:
	var query := TerrainCollisionQuery.new()
	query.configure(world, CompiledTerrainData.compile(FixtureLoader.terrain_registry()), HEX)
	return query


## A point this far above the floor in the middle of the room.
func _above_floor(height: float) -> Vector2:
	var floor_center := HexMetrics.center_for_offset(8, FLOOR_ROW, HEX)
	return Vector2(floor_center.x, floor_center.y - HEX - height)
