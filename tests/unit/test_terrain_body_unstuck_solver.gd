extends GutTest


const HEX_RADIUS := 16.0
const BODY := [Vector2(-10.0, -10.0), Vector2(10.0, -10.0), Vector2(10.0, 10.0), Vector2(-10.0, 10.0)]


func test_result_distinguishes_clear_escaping_and_enclosed_bodies() -> void:
	var registry := FixtureLoader.terrain_registry()
	var air_id := FixtureLoader.terrain_id("Air")
	var stone_id := FixtureLoader.terrain_id("Stone")
	var solver := TerrainBodyUnstuckSolver.new()
	var polygon := PackedVector2Array(BODY)
	var center := HexMetrics.center_for_offset(10, 10, HEX_RADIUS)

	var open_query := _query(WorldGrid.new(WorldDimensions.new(20, 20), air_id), registry)
	var clear_circle := solver.resolve_circle(center, Vector2.ZERO, 0.05, open_query, 10.0, 4, 900.0)
	var clear_polygon := solver.resolve_polygon(center, Vector2.ZERO, 0.05, open_query, polygon, 0.0, 4, 900.0)
	assert_false(clear_circle.overlapping)
	assert_false(clear_circle.moved)
	assert_false(clear_polygon.overlapping)
	assert_false(clear_polygon.moved)

	var enclosed_world := WorldGrid.new(WorldDimensions.new(20, 20), stone_id)
	var enclosed_query := _query(enclosed_world, registry)
	var enclosed_circle := solver.resolve_circle(center, Vector2.ZERO, 0.05, enclosed_query, 10.0, 4, 900.0)
	var enclosed_polygon := solver.resolve_polygon(center, Vector2.ZERO, 0.05, enclosed_query, polygon, 0.0, 4, 900.0)
	assert_true(enclosed_circle.overlapping)
	assert_false(enclosed_circle.moved)
	assert_eq(enclosed_circle.position, center)
	assert_true(enclosed_polygon.overlapping)
	assert_false(enclosed_polygon.moved)
	assert_eq(enclosed_polygon.position, center)

	var pocket := HexCoord.from_offset_odd_q(13, 10)
	for delta_q in range(-1, 2):
		for delta_r in range(maxi(-1, -delta_q - 1), mini(1, -delta_q + 1) + 1):
			var cell := pocket.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q()
			enclosed_world.set_committed_by_offset(cell.x, cell.y, air_id)
	var escaping_circle := solver.resolve_circle(center, Vector2.ZERO, 0.05, enclosed_query, 10.0, 4, 900.0)
	var escaping_polygon := solver.resolve_polygon(center, Vector2.ZERO, 0.05, enclosed_query, polygon, 0.0, 4, 900.0)
	assert_true(escaping_circle.overlapping)
	assert_true(escaping_circle.moved)
	assert_gt(escaping_circle.position.x, center.x)
	assert_true(escaping_polygon.overlapping)
	assert_true(escaping_polygon.moved)
	assert_gt(escaping_polygon.position.x, center.x)


func _query(world: WorldGrid, registry: TerrainRegistry) -> TerrainCollisionQuery:
	var query := TerrainCollisionQuery.new()
	query.configure(world, CompiledTerrainData.compile(registry), HEX_RADIUS)
	return query
