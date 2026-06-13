extends GutTest


func test_index_round_trip() -> void:
	var dimensions := WorldDimensions.new(5, 7)
	for index in range(0, dimensions.cell_count()):
		var offset := dimensions.index_to_offset(index)
		assert_eq(dimensions.offset_to_index(offset.x, offset.y), index)


func test_axial_bounds_follow_offset_grid() -> void:
	var dimensions := WorldDimensions.new(4, 4)
	assert_true(dimensions.is_in_bounds_axial(HexCoord.from_offset_odd_q(3, 3)))
	assert_false(dimensions.is_in_bounds_axial(HexCoord.from_offset_odd_q(4, 3)))
