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
