extends GutTest


const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")


func test_round_trip_world_to_offset_conversion_stays_on_same_hex_center() -> void:
	for col in range(0, 6):
		for row in range(0, 6):
			var center := HexMetrics.center_for_offset(col, row, 16.0)
			assert_eq(HexMetrics.offset_for_world(center, 16.0), Vector2i(col, row))


func test_query_returns_first_hookable_cell_on_probe_line() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(6, 6), 0)
	world.set_committed_by_offset(3, 2, 1)
	var query = WorldGrappleAnchorQueryScript.new()
	query.configure(world, registry, 16.0, 12.0, 8.0)

	var anchor := query.find_anchor(Vector2.ZERO, HexMetrics.center_for_offset(3, 2, 16.0))

	assert_not_null(anchor)
	assert_eq(anchor.cell, Vector2i(3, 2))
	assert_true(query.is_anchor_valid(anchor))
