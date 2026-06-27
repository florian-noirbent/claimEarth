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


func test_partial_sand_below_half_fill_is_not_solid() -> void:
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var sand_id := FixtureLoader.terrain_id("Sand")

	assert_false(metadata.is_solid(sand_id, 127))
	assert_true(metadata.is_solid(sand_id, 128))


func test_fill_only_sand_change_above_solid_threshold_does_not_dirty_collision() -> void:
	var dimensions := WorldDimensions.new(20, 32)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions, 20, 32)
	changes.add_change(
		dimensions.offset_to_index(5, 5),
		FixtureLoader.terrain_id("Sand"),
		FixtureLoader.terrain_id("Sand"),
		metadata,
		200,
		160
	)

	assert_eq(changes.collision_changed_indices.size(), 0)
	assert_eq(changes.mask_for_chunk(Vector2i.ZERO) & TerrainLayerMask.COLLISION, 0)


func test_fill_only_sand_change_crossing_solid_threshold_dirties_collision() -> void:
	var dimensions := WorldDimensions.new(40, 64)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions, 20, 32)
	changes.add_change(
		dimensions.offset_to_index(19, 10),
		FixtureLoader.terrain_id("Sand"),
		FixtureLoader.terrain_id("Sand"),
		metadata,
		128,
		127
	)

	assert_eq(changes.collision_changed_indices.size(), 1)
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


func test_fill_only_moving_change_marks_all_moving_visual_layers() -> void:
	var dimensions := WorldDimensions.new(20, 32)
	var metadata := CompiledTerrainData.compile(FixtureLoader.terrain_registry())
	var changes := TerrainChangeSet.new(dimensions, 20, 32)
	changes.add_change(
		dimensions.offset_to_index(5, 5),
		FixtureLoader.terrain_id("Sand"),
		FixtureLoader.terrain_id("Sand"),
		metadata,
		128,
		64
	)

	assert_true((changes.mask_for_chunk(Vector2i.ZERO) & TerrainLayerMask.SAND_VISUAL) != 0)
	assert_true((changes.mask_for_chunk(Vector2i.ZERO) & TerrainLayerMask.FLUID_VISUAL) != 0)
