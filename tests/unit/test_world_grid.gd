extends GutTest


func test_grid_initializes_committed_and_working_buffers() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(3, 2), 9)
	assert_eq(grid.committed_cells.size(), 6)
	assert_eq(grid.working_cells.size(), 6)
	assert_eq(grid.committed_fill.size(), 6)
	assert_eq(grid.working_fill.size(), 6)
	assert_eq(grid.get_committed_by_offset(2, 1), 9)
	assert_eq(grid.get_working_by_offset(0, 0), 9)
	assert_eq(grid.get_committed_fill_by_offset(2, 1), 255)


func test_working_commit_and_reset_behave_deterministically() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(2, 2), 1)
	grid.set_working_by_offset(1, 1, 4, 128)
	assert_eq(grid.get_committed_by_offset(1, 1), 1)
	grid.commit_working_to_committed()
	assert_eq(grid.get_committed_by_offset(1, 1), 4)
	assert_eq(grid.get_committed_fill_by_offset(1, 1), 128)
	grid.set_working_by_offset(0, 1, 7)
	grid.reset_working_from_committed()
	assert_eq(grid.get_working_by_offset(0, 1), 1)


func test_copy_committed_region_returns_row_major_bytes() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(3, 3), 0)
	grid.set_committed_by_offset(1, 0, 1, 64)
	grid.set_committed_by_offset(0, 1, 2, 128)
	grid.set_committed_by_offset(1, 1, 3, 192)
	assert_eq(grid.copy_committed_region(Rect2i(0, 0, 2, 2)), PackedByteArray([0, 1, 2, 3]))
	assert_eq(grid.copy_committed_fill_region(Rect2i(0, 0, 2, 2)), PackedByteArray([0, 64, 128, 192]))


func test_committed_hash_includes_fill_amounts() -> void:
	var left := WorldGrid.new(WorldDimensions.new(2, 2), 0)
	var right := WorldGrid.new(WorldDimensions.new(2, 2), 0)
	left.set_committed_by_offset(1, 1, FixtureLoader.terrain_id("Water"), 64)
	right.set_committed_by_offset(1, 1, FixtureLoader.terrain_id("Water"), 128)

	assert_ne(left.committed_hash(), right.committed_hash())
