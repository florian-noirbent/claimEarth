extends GutTest


func test_offset_round_trip_for_odd_q_layout() -> void:
	for col in range(0, 8):
		for row in range(0, 8):
			var coord := HexCoord.from_offset_odd_q(col, row)
			assert_eq(coord.to_offset_odd_q(), Vector2i(col, row))


func test_neighbor_count_and_distance() -> void:
	var origin := HexCoord.new(0, 0)
	assert_eq(origin.neighbors().size(), 6)
	assert_eq(origin.distance_to(HexCoord.new(2, -1)), 2)


func test_world_position_uses_flat_top_spacing() -> void:
	var right := HexCoord.new(1, 0).to_world_position()
	assert_almost_eq(right.x, 1.5, 0.001)


func test_hex_metrics_world_round_trip_matches_offset_coordinates() -> void:
	var center := HexMetrics.center_for_offset(4, 5, 16.0)
	assert_eq(HexMetrics.offset_for_world(center, 16.0), Vector2i(4, 5))
