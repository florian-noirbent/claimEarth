extends GutTest


func test_visible_chunks_cover_only_requested_depth_window() -> void:
	var index := ChunkActivityIndex.new(WorldDimensions.new(100, 200), 20, 32)
	var visible := index.visible_chunks_for_depth_window(0, 64)

	assert_eq(visible.size(), 10)
	assert_true(visible.has(Vector2i(0, 0)))
	assert_true(visible.has(Vector2i(4, 1)))
	assert_false(visible.has(Vector2i(0, 2)))


func test_chunk_rect_clamps_at_world_edges() -> void:
	var index := ChunkActivityIndex.new(WorldDimensions.new(45, 70), 20, 32)

	assert_eq(index.chunk_rect(Vector2i(2, 2)), Rect2i(40, 64, 5, 6))


func test_partial_sand_below_half_fill_is_not_solid() -> void:
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var sand_id := FixtureLoader.terrain_id("Sand")

	assert_false(metadata.is_solid(sand_id, 127))
	assert_true(metadata.is_solid(sand_id, 128))


func test_change_set_tracks_changed_indices_and_dirty_rect_only() -> void:
	var dimensions := WorldDimensions.new(20, 32)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions)

	changes.add_change(dimensions.offset_to_index(5, 5), FixtureLoader.terrain_id("Stone"), FixtureLoader.terrain_id("Air"), metadata)
	changes.add_change(dimensions.offset_to_index(7, 8), FixtureLoader.terrain_id("Sand"), FixtureLoader.terrain_id("Sand"), metadata, 255, 127)

	assert_eq(changes.changed_cell_count(), 2)
	assert_eq(changes.dirty_rect, Rect2i(5, 5, 3, 4))
