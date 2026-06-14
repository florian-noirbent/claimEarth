extends GutTest


func test_invisible_walls_align_with_map_outer_edges() -> void:
	var boundaries := WorldSideBoundaries.new()
	add_child_autofree(boundaries)
	await wait_process_frames(1)

	boundaries.configure(-16.0, 2400.0, -32.0, 4000.0)

	assert_almost_eq(boundaries.left_wall_inner_edge(), -16.0, 0.001)
	assert_almost_eq(boundaries.right_wall_inner_edge(), 2400.0, 0.001)
