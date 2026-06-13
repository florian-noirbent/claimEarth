extends GutTest


func test_world_presenter_uses_chunk_nodes_instead_of_cell_nodes() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)

	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(40, 64), 0)
	var stone_id := registry.get_definition(1).stable_id
	for row in range(0, 8):
		for col in range(0, 40):
			world.set_committed_by_offset(col, row, stone_id)

	var activity := ChunkActivityIndex.new(world.dimensions, 20, 32)
	presenter.configure(world, registry, activity)

	assert_eq(presenter.visible_chunk_count(), 4)
	assert_eq(presenter.total_renderer_nodes(), 4)
	assert_eq(presenter.get_child_count(), 8)


func test_world_presenter_builds_collision_for_solid_exposed_edges() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)

	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(20, 20), 0)
	var stone_id := registry.get_definition(1).stable_id
	world.set_committed_by_offset(5, 5, stone_id)

	var activity := ChunkActivityIndex.new(world.dimensions, 20, 20)
	presenter.configure(world, registry, activity)

	assert_true(presenter.chunk_collision_segment_count(Vector2i.ZERO) >= 6)


func test_world_presenter_rebuilds_only_dirty_or_newly_visible_chunks() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(40, 64), FixtureLoader.terrain_id("Air"))
	var stone_id := FixtureLoader.terrain_id("Stone")
	for row in range(0, 8):
		for col in range(0, 40):
			world.set_committed_by_offset(col, row, stone_id)

	var activity := ChunkActivityIndex.new(world.dimensions, 20, 32)
	presenter.configure(world, registry, activity)
	presenter.reset_stats()

	presenter.refresh_visible_chunks(0)
	assert_eq(presenter.rebuild_count(), 0)

	activity.mark_dirty_rect(Rect2i(0, 0, 1, 1))
	presenter.refresh_visible_chunks(0)
	assert_eq(presenter.rebuild_count(), 1)
	assert_eq(presenter.dirty_rebuild_count(), 1)


func test_world_presenter_discards_offscreen_chunks_to_keep_node_count_bounded() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(100, 200), FixtureLoader.terrain_id("Stone"))
	var activity := ChunkActivityIndex.new(world.dimensions, 20, 32)
	presenter.configure(world, registry, activity)

	presenter.refresh_visible_chunks(0)
	var initial_visible := presenter.visible_chunk_count()
	presenter.refresh_visible_chunks(96)

	assert_eq(presenter.total_renderer_nodes(), presenter.visible_chunk_count())
	assert_eq(presenter.total_collider_nodes(), presenter.visible_chunk_count())
	assert_lte(presenter.visible_chunk_count(), initial_visible + 5)
