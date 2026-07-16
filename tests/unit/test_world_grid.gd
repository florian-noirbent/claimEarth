extends GutTest


func test_grid_initializes_packed_cell_buffer_and_texture() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(3, 2), 9)
	assert_eq(grid.cell_bytes.size(), 6 * WorldGrid.BYTES_PER_CELL)
	assert_eq(grid.get_committed_by_offset(2, 1), 9)
	assert_eq(grid.get_committed_quantity_by_offset(2, 1), 127)
	assert_eq(grid.get_committed_light_by_offset(0, 0), 0)
	assert_eq(grid.get_committed_light_by_offset(2, 1), 0)
	assert_eq(grid.texture().get_width(), 3)
	assert_eq(grid.texture().get_height(), 2)


func test_committed_writes_update_packed_snapshot() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(2, 2), 1)
	grid.set_committed_by_offset(1, 1, 4, 128)
	assert_eq(grid.get_committed_by_offset(1, 1), 4)
	assert_eq(grid.get_committed_quantity_by_offset(1, 1), 128)
	var offset := (1 * 2 + 1) * WorldGrid.BYTES_PER_CELL
	assert_eq(grid.cell_bytes[offset + WorldGrid.CELL_HEX_IDS], 4)
	assert_eq(grid.cell_bytes[offset + WorldGrid.CELL_QUANTITY], 128)


func test_secondary_hex_id_uses_high_nibble_without_changing_primary_id() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(1, 1), 0)
	grid.set_committed_components_by_offset(0, 0, 4, 127, 5, 73)

	assert_eq(grid.get_committed_by_offset(0, 0), 4)
	assert_eq(grid.get_committed_secondary_by_offset(0, 0), 5)
	assert_eq(grid.get_committed_secondary_quantity_by_offset(0, 0), 73)
	assert_eq(grid.cell_bytes[WorldGrid.CELL_HEX_IDS], 0x54)
	assert_eq(grid.cell_bytes[WorldGrid.CELL_SECONDARY_QUANTITY], 73)


func test_primary_write_clears_secondary_component_and_preserves_light() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(1, 1), 0)
	grid.set_committed_components_by_offset(0, 0, 4, 255, 5, 200)
	grid.set_committed_light_by_offset(0, 0, 180)

	var change := grid.set_committed_by_offset(0, 0, 3, 127)

	assert_eq(grid.get_committed_by_offset(0, 0), 3)
	assert_eq(grid.get_committed_quantity_by_offset(0, 0), 127)
	assert_eq(grid.get_committed_secondary_by_offset(0, 0), 0)
	assert_eq(grid.get_committed_secondary_quantity_by_offset(0, 0), 0)
	assert_eq(grid.get_committed_light_by_offset(0, 0), 180)
	assert_eq(change.previous_secondary_id, 5)
	assert_eq(change.previous_secondary_quantity, 200)
	assert_eq(change.next_secondary_quantity, 0)


func test_copy_committed_region_returns_row_major_bytes() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(3, 3), 0)
	grid.set_committed_by_offset(1, 0, 1, 64)
	grid.set_committed_by_offset(0, 1, 2, 128)
	grid.set_committed_by_offset(1, 1, 3, 192)
	assert_eq(grid.copy_committed_region(Rect2i(0, 0, 2, 2)), PackedByteArray([0, 1, 2, 3]))
	assert_eq(grid.copy_committed_quantity_region(Rect2i(0, 0, 2, 2)), PackedByteArray([64, 64, 128, 192]))
	assert_eq(grid.copy_rgba_region(Rect2i(1, 0, 1, 1)), PackedByteArray([1, 64, 0, 0]))


func test_terrain_write_preserves_location_lighting() -> void:
	var grid := WorldGrid.new(WorldDimensions.new(1, 1), 0)
	grid.set_committed_light_by_offset(0, 0, 180)
	grid.set_committed_by_offset(0, 0, FixtureLoader.terrain_id("Stone"))

	assert_eq(grid.get_committed_light_by_offset(0, 0), 180)


func test_committed_hash_includes_fill_amounts() -> void:
	var left := WorldGrid.new(WorldDimensions.new(2, 2), 0)
	var right := WorldGrid.new(WorldDimensions.new(2, 2), 0)
	left.set_committed_by_offset(1, 1, FixtureLoader.terrain_id("Water"), 64)
	right.set_committed_by_offset(1, 1, FixtureLoader.terrain_id("Water"), 128)

	assert_ne(left.committed_hash(), right.committed_hash())


func test_partial_sand_below_half_fill_is_not_solid() -> void:
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var sand_id := FixtureLoader.terrain_id("Sand")

	assert_false(metadata.is_solid(sand_id, 63))
	assert_true(metadata.is_solid(sand_id, 64))


func test_change_set_tracks_changed_indices_and_dirty_rect_only() -> void:
	var dimensions := WorldDimensions.new(20, 32)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions)

	changes.add_change(dimensions.offset_to_index(5, 5), FixtureLoader.terrain_id("Stone"), FixtureLoader.terrain_id("Air"), metadata)
	changes.add_change(dimensions.offset_to_index(7, 8), FixtureLoader.terrain_id("Sand"), FixtureLoader.terrain_id("Sand"), metadata, 127, 63)

	assert_eq(changes.changed_cell_count(), 2)
	assert_eq(changes.dirty_rect, Rect2i(5, 5, 3, 4))


func test_change_set_tracks_secondary_only_changes() -> void:
	var dimensions := WorldDimensions.new(2, 2)
	var grid := WorldGrid.new(dimensions, FixtureLoader.terrain_id("Air"))
	grid.set_committed_components_by_offset(
		1,
		1,
		FixtureLoader.terrain_id("Sand"),
		127,
		FixtureLoader.terrain_id("Water"),
		64
	)
	var change := grid.set_committed_by_offset(1, 1, FixtureLoader.terrain_id("Sand"), 127)
	var changes := TerrainChangeSet.new(dimensions)

	changes.add_cell_change(change)

	assert_eq(changes.changed_cell_count(), 1)
	assert_eq(changes.dirty_rect, Rect2i(1, 1, 1, 1))
