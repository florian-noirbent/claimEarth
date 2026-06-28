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
	presenter.build_budget_usec = 1000000
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
	for _frame in range(30):
		presenter.refresh_visible_chunks(0)
		if presenter.pending_job_count() == 0 and presenter.rebuild_count() > 0:
			break
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


func test_world_presenter_builds_separate_static_sand_and_fluid_meshes() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Sand"))
	world.set_committed_by_offset(4, 2, FixtureLoader.terrain_id("Water"))
	presenter.configure(world, registry, ChunkActivityIndex.new(world.dimensions, 20, 32))

	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.STATIC_VISUAL), 0)
	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.SAND_VISUAL), 0)
	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.FLUID_VISUAL), 0)


func test_world_presenter_renders_partial_fill_levels() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 4, FixtureLoader.terrain_id("Water"), 128)
	presenter.configure(world, registry, ChunkActivityIndex.new(world.dimensions, 20, 32))

	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.FLUID_VISUAL), 0)
	var full_top_y := HexMetrics.center_for_offset(4, 4, presenter.hex_radius).y - presenter.hex_radius * sqrt(3.0) * 0.5
	assert_gt(presenter.chunk_layer_min_vertex_y(Vector2i.ZERO, TerrainLayerMask.FLUID_VISUAL), full_top_y + 1.0)


func test_world_presenter_renders_partial_moving_cell_full_under_solid() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 3, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(4, 4, FixtureLoader.terrain_id("Water"), 128)
	presenter.configure(world, registry, ChunkActivityIndex.new(world.dimensions, 20, 32))

	assert_eq(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.FLUID_VISUAL), 7)


func test_world_presenter_draws_liquid_above_partial_moving_cell() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 3, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(4, 4, FixtureLoader.terrain_id("Sand"), 128)
	presenter.configure(world, registry, ChunkActivityIndex.new(world.dimensions, 20, 32))

	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.FLUID_VISUAL), 7)
	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.SAND_VISUAL), 0)


func test_chunk_build_job_smooths_adjacent_water_surface() -> void:
	var water_id := FixtureLoader.terrain_id("Water")
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 4, water_id, 150)
	world.set_committed_by_offset(5, 3, water_id, 100)
	var result := _build_chunk_result(world, TerrainLayerMask.FLUID_VISUAL)

	var expected := _expected_side_surface_point(4, 4, 150, 5, 3, 100, 1)
	_assert_contains_vertex(result.fluid_vertices, expected)


func test_chunk_build_job_smooths_adjacent_sand_surface() -> void:
	var sand_id := FixtureLoader.terrain_id("Sand")
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 4, sand_id, 150)
	world.set_committed_by_offset(5, 3, sand_id, 100)
	var result := _build_chunk_result(world, TerrainLayerMask.SAND_VISUAL)

	var expected := _expected_side_surface_point(4, 4, 150, 5, 3, 100, 1)
	_assert_contains_vertex(result.sand_vertices, expected)


func test_chunk_build_job_keeps_moving_surface_flat_beside_air() -> void:
	var water_id := FixtureLoader.terrain_id("Water")
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 4, water_id, 150)
	var result := _build_chunk_result(world, TerrainLayerMask.FLUID_VISUAL)

	var center := HexMetrics.center_for_offset(4, 4, 16.0)
	var surface_y := _fill_line_y(150, 16.0)
	var expected := center + Vector2(_right_boundary_x(surface_y, 16.0), surface_y)
	_assert_contains_vertex(result.fluid_vertices, expected)


func test_chunk_build_job_does_not_smooth_between_different_moving_terrain() -> void:
	var sand_id := FixtureLoader.terrain_id("Sand")
	var water_id := FixtureLoader.terrain_id("Water")
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(4, 4, sand_id, 150)
	world.set_committed_by_offset(5, 3, water_id, 100)
	var result := _build_chunk_result(world, TerrainLayerMask.SAND_VISUAL | TerrainLayerMask.FLUID_VISUAL)

	var flat_y := _fill_line_y(150, 16.0)
	var flat_expected := HexMetrics.center_for_offset(4, 4, 16.0) + Vector2(_right_boundary_x(flat_y, 16.0), flat_y)
	var smoothed_expected := _expected_side_surface_point(4, 4, 150, 5, 3, 100, 1)
	_assert_contains_vertex(result.sand_vertices, flat_expected)
	_assert_missing_vertex(result.sand_vertices, smoothed_expected)


func test_incremental_collision_update_removes_changed_boundary_edges() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Stone"))
	var activity := ChunkActivityIndex.new(world.dimensions, 20, 32)
	presenter.configure(world, registry, activity)
	var initial_segments := presenter.chunk_collision_segment_count(Vector2i.ZERO)
	var metadata := CompiledTerrainData.compile(registry)
	var change := world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Air"))
	var changes := TerrainChangeSet.new(world.dimensions, 20, 32)
	changes.add_change(change.index, change.previous_id, change.next_id, metadata)
	activity.mark_change_set(changes)
	for _frame in range(10):
		presenter.refresh_visible_chunks(0)
		if presenter.pending_job_count() == 0:
			break

	assert_gt(initial_segments, 0)
	assert_eq(presenter.chunk_collision_segment_count(Vector2i.ZERO), 0)


func _build_chunk_result(world: WorldGrid, mask: int) -> ChunkBuildResult:
	var rect := Rect2i(Vector2i.ZERO, Vector2i(world.dimensions.width, world.dimensions.depth))
	var job := ChunkBuildJob.new()
	job.configure(
		Vector2i.ZERO,
		1,
		mask,
		rect,
		rect,
		world.copy_committed_region(rect),
		world.copy_committed_fill_region(rect),
		CompiledTerrainData.compile(FixtureLoader.terrain_registry()),
		16.0,
		world.dimensions.width
	)
	assert_true(job.advance(1000000))
	return job.result


func _expected_side_surface_point(col: int, row: int, fill: int, neighbor_col: int, neighbor_row: int, neighbor_fill: int, side: int) -> Vector2:
	var center := HexMetrics.center_for_offset(col, row, 16.0)
	var neighbor_center := HexMetrics.center_for_offset(neighbor_col, neighbor_row, 16.0)
	var local_y := (center.y + _fill_line_y(fill, 16.0) + neighbor_center.y + _fill_line_y(neighbor_fill, 16.0)) * 0.5 - center.y
	var half_height := _half_height(16.0)
	local_y = clampf(local_y, -half_height, half_height)
	var local_x := _right_boundary_x(local_y, 16.0) if side > 0 else _left_boundary_x(local_y, 16.0)
	return center + Vector2(local_x, local_y)


func _fill_line_y(fill: int, radius: float) -> float:
	var half_height := _half_height(radius)
	return lerpf(half_height, -half_height, float(fill) / 255.0)


func _half_height(radius: float) -> float:
	return radius * sqrt(3.0) * 0.5


func _left_boundary_x(local_y: float, radius: float) -> float:
	return -radius + absf(local_y) / sqrt(3.0)


func _right_boundary_x(local_y: float, radius: float) -> float:
	return radius - absf(local_y) / sqrt(3.0)


func _assert_contains_vertex(vertices: PackedVector3Array, expected: Vector2) -> void:
	assert_true(_has_vertex(vertices, expected), "Expected mesh vertex near %s" % expected)


func _assert_missing_vertex(vertices: PackedVector3Array, expected: Vector2) -> void:
	assert_false(_has_vertex(vertices, expected), "Unexpected mesh vertex near %s" % expected)


func _has_vertex(vertices: PackedVector3Array, expected: Vector2) -> bool:
	for vertex in vertices:
		if Vector2(vertex.x, vertex.y).distance_to(expected) <= 0.05:
			return true
	return false


func test_incremental_collision_update_removes_sand_edges_below_half_fill() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	world.set_committed_by_offset(5, 5, sand_id)
	var activity := ChunkActivityIndex.new(world.dimensions, 20, 32)
	presenter.configure(world, registry, activity)
	var initial_segments := presenter.chunk_collision_segment_count(Vector2i.ZERO)
	var metadata := CompiledTerrainData.compile(registry)
	var change := world.set_committed_by_offset(5, 5, sand_id, 127)
	var changes := TerrainChangeSet.new(world.dimensions, 20, 32)
	changes.add_change(change.index, change.previous_id, change.next_id, metadata, change.previous_fill, change.next_fill)
	activity.mark_change_set(changes)
	for _frame in range(10):
		presenter.refresh_visible_chunks(0)
		if presenter.pending_job_count() == 0:
			break

	assert_gt(initial_segments, 0)
	assert_eq(presenter.chunk_collision_segment_count(Vector2i.ZERO), 0)
