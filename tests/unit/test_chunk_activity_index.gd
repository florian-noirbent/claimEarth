extends GutTest


func test_visible_chunks_cover_only_requested_depth_window() -> void:
	var index := ChunkActivityIndex.new(WorldDimensions.new(100, 200), 20, 32)
	var visible := index.visible_chunks_for_depth_window(0, 64)

	assert_eq(visible.size(), 10)
	assert_true(visible.has(Vector2i(0, 0)))
	assert_true(visible.has(Vector2i(4, 1)))
	assert_false(visible.has(Vector2i(0, 2)))


func test_mark_dirty_rect_touches_intersecting_chunks() -> void:
	var index := ChunkActivityIndex.new(WorldDimensions.new(100, 200), 20, 32)
	index.mark_dirty_rect(Rect2i(19, 31, 3, 3))
	var dirty := index.consume_dirty_chunks()

	assert_true(dirty.has(Vector2i(0, 0)))
	assert_true(dirty.has(Vector2i(1, 0)))
	assert_true(dirty.has(Vector2i(0, 1)))
	assert_true(dirty.has(Vector2i(1, 1)))


func test_change_set_tracks_fluid_visual_without_collision() -> void:
	var dimensions := WorldDimensions.new(40, 64)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions, 20, 32)
	var source := dimensions.offset_to_index(19, 10)
	changes.add_change(source, FixtureLoader.terrain_id("Water"), FixtureLoader.terrain_id("Air"), metadata)

	assert_eq(changes.mask_for_chunk(Vector2i(0, 0)), TerrainLayerMask.FLUID_VISUAL)
	assert_eq(changes.mask_for_chunk(Vector2i(1, 0)), TerrainLayerMask.NONE)


func test_solid_boundary_change_marks_collision_in_neighbor_chunk() -> void:
	var dimensions := WorldDimensions.new(40, 64)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions, 20, 32)
	var source := dimensions.offset_to_index(19, 10)
	changes.add_change(source, FixtureLoader.terrain_id("Sand"), FixtureLoader.terrain_id("Air"), metadata)

	assert_true((changes.mask_for_chunk(Vector2i(0, 0)) & TerrainLayerMask.COLLISION) != 0)
	assert_true((changes.mask_for_chunk(Vector2i(1, 0)) & TerrainLayerMask.COLLISION) != 0)


func test_static_to_static_change_does_not_dirty_collision() -> void:
	var dimensions := WorldDimensions.new(20, 32)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions, 20, 32)
	changes.add_change(
		dimensions.offset_to_index(5, 5),
		FixtureLoader.terrain_id("Stone"),
		FixtureLoader.terrain_id("Dirt"),
		metadata
	)

	assert_eq(changes.mask_for_chunk(Vector2i.ZERO), TerrainLayerMask.STATIC_VISUAL)
