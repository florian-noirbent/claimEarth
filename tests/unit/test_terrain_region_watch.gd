extends GutTest


const HEX_RADIUS := 16.0

var _air_id := 0
var _stone_id := 0
var _water_id := 0


func before_all() -> void:
	_air_id = FixtureLoader.terrain_id("Air")
	_stone_id = FixtureLoader.terrain_id("Stone")
	_water_id = FixtureLoader.terrain_id("Water")


func test_watch_reports_a_solidity_change_inside_the_captured_cells_until_recaptured() -> void:
	var world := _world_with_floor()
	var query := _query(world)
	var watch := TerrainRegionWatch.new()
	var bounds := _bounds_around_cell(Vector2i(5, 5))
	watch.capture(query, bounds)

	assert_true(watch.cells().has_point(Vector2i(5, 6)))
	assert_false(watch.has_changed())
	world.set_committed_by_offset(5, 6, _air_id)
	assert_true(watch.has_changed())
	assert_true(watch.has_changed(), "An unhandled change must keep being reported")
	watch.capture(query, bounds)
	assert_false(watch.has_changed())
	world.set_committed_by_offset(5, 6, _stone_id)
	assert_true(watch.has_changed())


func test_watch_ignores_cells_outside_the_captured_range() -> void:
	var world := _world_with_floor()
	var watch := TerrainRegionWatch.new()
	watch.capture(_query(world), _bounds_around_cell(Vector2i(5, 5)))
	var outside := watch.cells().end + Vector2i.ONE

	assert_true(world.dimensions.is_in_bounds_offset(outside.x, outside.y))
	world.set_committed_by_offset(outside.x, outside.y, _stone_id)
	world.set_committed_by_offset(0, 6, _air_id)
	assert_false(watch.has_changed())


func test_watch_ignores_light_and_non_solid_changes_but_still_sees_a_later_solidity_change() -> void:
	var world := _world_with_floor()
	var query := _query(world)
	var watch := TerrainRegionWatch.new()
	watch.capture(query, _bounds_around_cell(Vector2i(5, 5)))

	world.set_committed_light_by_offset(5, 6, 200)
	world.set_committed_light_by_offset(5, 5, 90)
	assert_false(watch.has_changed())
	world.set_committed_by_offset(5, 5, _water_id, 40)
	assert_false(query.is_solid_cell(5, 5))
	assert_false(watch.has_changed(), "Fluid in an open cell does not change what a body collides with")
	world.set_committed_by_offset(5, 5, _water_id, 90)
	assert_false(watch.has_changed())

	world.set_committed_by_offset(4, 6, _air_id)
	assert_true(watch.has_changed())


func test_watch_capturing_air_reports_air_cells_that_fill_or_open() -> void:
	var world := _world_with_floor()
	var query := _query(world)
	var bounds := _bounds_around_cell(Vector2i(5, 5))
	var watch := TerrainRegionWatch.new()
	watch.capture(query, bounds, true)

	world.set_committed_light_by_offset(5, 5, 90)
	assert_false(watch.has_changed())
	world.set_committed_by_offset(5, 5, _water_id)
	assert_true(watch.has_changed(), "An Air center that fills is no longer an escape candidate")
	watch.capture(query, bounds, true)
	assert_false(watch.has_changed())
	world.set_committed_by_offset(5, 5, _air_id)
	assert_true(watch.has_changed())


func test_watch_handles_ranges_that_leave_the_world() -> void:
	var world := _world_with_floor()
	var query := _query(world)
	var watch := TerrainRegionWatch.new()
	watch.capture(query, Rect2(Vector2(-200.0, -200.0), Vector2(230.0, 230.0)))

	assert_lt(watch.cells().position.x, 0)
	assert_lt(watch.cells().position.y, 0)
	assert_false(watch.has_changed())
	world.set_committed_by_offset(0, 0, _stone_id)
	assert_true(watch.has_changed())

	watch.capture(query, Rect2(Vector2(-900.0, -900.0), Vector2(40.0, 40.0)))
	world.set_committed_by_offset(0, 0, _air_id)
	assert_false(watch.has_changed())
	assert_false(TerrainRegionWatch.new().has_changed())


func _world_with_floor() -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(12, 12), _air_id)
	for col in range(12):
		world.set_committed_by_offset(col, 6, _stone_id)
	return world


func _query(world: WorldGrid) -> TerrainCollisionQuery:
	var query := TerrainCollisionQuery.new()
	query.configure(world, CompiledTerrainData.compile(FixtureLoader.terrain_registry()), HEX_RADIUS)
	return query


func _bounds_around_cell(cell: Vector2i) -> Rect2:
	var center := HexMetrics.center_for_offset(cell.x, cell.y, HEX_RADIUS)
	return Rect2(center - Vector2(20.0, 20.0), Vector2(40.0, 40.0))
