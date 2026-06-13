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
