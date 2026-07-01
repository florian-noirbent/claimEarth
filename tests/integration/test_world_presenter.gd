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
	assert_eq(presenter.total_collider_nodes(), 0)
	assert_eq(presenter.get_child_count(), 4)


func test_world_presenter_does_not_build_terrain_collider_nodes() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)

	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(20, 20), 0)
	var stone_id := registry.get_definition(1).stable_id
	world.set_committed_by_offset(5, 5, stone_id)

	var activity := ChunkActivityIndex.new(world.dimensions, 20, 20)
	presenter.configure(world, registry, activity)

	assert_eq(presenter.total_collider_nodes(), 0)
	assert_eq(presenter.chunk_collision_segment_count(Vector2i.ZERO), 0)


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
	assert_eq(presenter.total_collider_nodes(), 0)
	assert_lte(presenter.visible_chunk_count(), initial_visible + 5)


func test_world_presenter_builds_separate_static_sand_and_fluid_meshes() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Dirt"))
	world.set_committed_by_offset(4, 2, FixtureLoader.terrain_id("Sand"))
	world.set_committed_by_offset(5, 2, FixtureLoader.terrain_id("Water"))
	presenter.configure(world, registry, ChunkActivityIndex.new(world.dimensions, 20, 32))

	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.STATIC_VISUAL), 0)
	assert_eq(presenter.chunk_static_material_mesh_count(Vector2i.ZERO), 2)
	assert_gt(presenter.chunk_static_edge_vertex_count(Vector2i.ZERO), 0)
	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.SAND_VISUAL), 0)
	assert_gt(presenter.chunk_layer_vertex_count(Vector2i.ZERO, TerrainLayerMask.FLUID_VISUAL), 0)


func test_chunk_build_job_groups_static_meshes_by_material_and_uses_material_scale() -> void:
	var registry := _terrain_registry_with_material_scale("Stone", 32.0)
	var metadata := CompiledTerrainData.compile(registry)
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Dirt"))
	var result := _build_chunk_result(world, TerrainLayerMask.STATIC_VISUAL, registry)
	var stone_material_index := int(metadata.material_index_by_id[FixtureLoader.terrain_id("Stone")])
	var dirt_material_index := int(metadata.material_index_by_id[FixtureLoader.terrain_id("Dirt")])
	var stone_mesh := result.static_material_meshes[stone_material_index] as ChunkMeshArrays
	var dirt_mesh := result.static_material_meshes[dirt_material_index] as ChunkMeshArrays

	assert_eq(result.static_material_meshes.size(), 2)
	assert_true(stone_material_index != dirt_material_index)
	assert_eq(stone_mesh.uvs[0], Vector2(stone_mesh.vertices[0].x, stone_mesh.vertices[0].y) / 32.0)
	assert_eq(
		dirt_mesh.uvs[0],
		Vector2(dirt_mesh.vertices[0].x, dirt_mesh.vertices[0].y) / metadata.fill_texture_world_scale_by_id[FixtureLoader.terrain_id("Dirt")]
	)


func test_chunk_build_job_falls_back_when_static_material_has_no_texture() -> void:
	var registry := _terrain_registry_without_material_texture("Dirt")
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(3, 2, FixtureLoader.terrain_id("Dirt"))
	var result := _build_chunk_result(world, TerrainLayerMask.STATIC_VISUAL, registry)

	assert_gt(result.static_vertices.size(), 0)
	assert_eq(result.static_material_meshes.size(), 0)


func test_chunk_build_job_outlines_isolated_static_cell() -> void:
	var registry := FixtureLoader.terrain_registry()
	var metadata := CompiledTerrainData.compile(registry)
	var stone_id := FixtureLoader.terrain_id("Stone")
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(5, 5, stone_id)
	var result := _build_chunk_result(world, TerrainLayerMask.STATIC_VISUAL, registry)
	var stone_material_index := int(metadata.material_index_by_id[stone_id])
	var stone_edges := result.static_edge_meshes[stone_material_index] as ChunkMeshArrays

	assert_eq(stone_edges.vertices.size(), 24)


func test_chunk_build_job_skips_shared_edge_between_same_material_cells() -> void:
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(6, 5, FixtureLoader.terrain_id("Stone"))
	var result := _build_chunk_result(world, TerrainLayerMask.STATIC_VISUAL)

	assert_eq(_static_edge_vertex_count(result), 40)


func test_chunk_build_job_outlines_boundary_between_different_static_materials_once() -> void:
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(6, 5, FixtureLoader.terrain_id("Dirt"))
	var result := _build_chunk_result(world, TerrainLayerMask.STATIC_VISUAL)

	assert_eq(_static_edge_vertex_count(result), 44)


func test_chunk_build_job_uses_visual_outline_when_material_has_no_edge_definition() -> void:
	var registry := _terrain_registry_without_edge_definition("Stone", Color(1, 0, 0, 0.5), 3.5)
	var metadata := CompiledTerrainData.compile(registry)
	var stone_id := FixtureLoader.terrain_id("Stone")
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(5, 5, stone_id)
	var result := _build_chunk_result(world, TerrainLayerMask.STATIC_VISUAL, registry)
	var stone_material_index := int(metadata.material_index_by_id[stone_id])
	var stone_edges := result.static_edge_meshes[stone_material_index] as ChunkMeshArrays

	assert_eq(stone_edges.colors[0], Color(1, 0, 0, 0.5))
	assert_true(_has_edge_width(stone_edges.vertices, 3.5))


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


func test_terrain_change_keeps_presenter_collision_free() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Stone"))
	var activity := ChunkActivityIndex.new(world.dimensions, 20, 32)
	presenter.configure(world, registry, activity)
	var metadata := CompiledTerrainData.compile(registry)
	var change := world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Air"))
	var changes := TerrainChangeSet.new(world.dimensions, 20, 32)
	changes.add_change(change.index, change.previous_id, change.next_id, metadata)
	activity.mark_change_set(changes)
	for _frame in range(10):
		presenter.refresh_visible_chunks(0)
		if presenter.pending_job_count() == 0:
			break

	assert_eq(presenter.chunk_collision_segment_count(Vector2i.ZERO), 0)


func _build_chunk_result(world: WorldGrid, mask: int, registry: TerrainRegistry = null) -> ChunkBuildResult:
	var rect := Rect2i(Vector2i.ZERO, Vector2i(world.dimensions.width, world.dimensions.depth))
	var terrain_registry := registry if registry != null else FixtureLoader.terrain_registry()
	var job := ChunkBuildJob.new()
	job.configure(
		Vector2i.ZERO,
		1,
		mask,
		rect,
		rect,
		world.copy_committed_region(rect),
		world.copy_committed_fill_region(rect),
		CompiledTerrainData.compile(terrain_registry),
		16.0,
		world.dimensions.width
	)
	assert_true(job.advance(1000000))
	return job.result


func _terrain_registry_with_material_scale(terrain_name: String, scale: float) -> TerrainRegistry:
	var catalog := _duplicated_terrain_catalog()
	var style := _style_for_terrain(catalog, terrain_name)
	style.material = style.material.duplicate(true) as TerrainMaterial
	style.material.fill_texture_world_scale = scale
	return _registry_from_catalog(catalog)


func _terrain_registry_without_material_texture(terrain_name: String) -> TerrainRegistry:
	var catalog := _duplicated_terrain_catalog()
	var style := _style_for_terrain(catalog, terrain_name)
	style.material = style.material.duplicate(true) as TerrainMaterial
	style.material.fill_texture = null
	return _registry_from_catalog(catalog)


func _terrain_registry_without_edge_definition(terrain_name: String, outline_color: Color, outline_width: float) -> TerrainRegistry:
	var catalog := _duplicated_terrain_catalog()
	var style := _style_for_terrain(catalog, terrain_name)
	style.outline_color = outline_color
	style.outline_width = outline_width
	style.material = style.material.duplicate(true) as TerrainMaterial
	style.material.edge_definition = null
	return _registry_from_catalog(catalog)


func _duplicated_terrain_catalog() -> TerrainCatalog:
	var source := FixtureLoader.terrain_catalog()
	var catalog := TerrainCatalog.new()
	var definitions := []
	for definition_variant in source.definitions:
		var definition := (definition_variant as TerrainDefinition).duplicate(true) as TerrainDefinition
		if definition.visual_style != null:
			definition.visual_style = definition.visual_style.duplicate(true)
		definitions.append(definition)
	catalog.definitions = definitions
	return catalog


func _style_for_terrain(catalog: TerrainCatalog, terrain_name: String) -> TerrainVisualStyle:
	for definition_variant in catalog.definitions:
		var definition := definition_variant as TerrainDefinition
		if definition.display_name == terrain_name:
			return definition.visual_style as TerrainVisualStyle
	return null


func _registry_from_catalog(catalog: TerrainCatalog) -> TerrainRegistry:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(catalog))
	return registry


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


func _static_edge_vertex_count(result: ChunkBuildResult) -> int:
	var count := 0
	for mesh_variant in result.static_edge_meshes.values():
		count += (mesh_variant as ChunkMeshArrays).vertices.size()
	return count


func _has_edge_width(vertices: Array[Vector3], expected_width: float) -> bool:
	for index in range(0, vertices.size(), 4):
		var start := Vector2(vertices[index].x, vertices[index].y)
		var outer_start := Vector2(vertices[index + 3].x, vertices[index + 3].y)
		if is_equal_approx(start.distance_to(outer_start), expected_width):
			return true
	return false


func test_sand_fill_change_keeps_presenter_collision_free() -> void:
	var presenter := WorldPresenter.new()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	var sand_id := FixtureLoader.terrain_id("Sand")
	world.set_committed_by_offset(5, 5, sand_id)
	var activity := ChunkActivityIndex.new(world.dimensions, 20, 32)
	presenter.configure(world, registry, activity)
	var metadata := CompiledTerrainData.compile(registry)
	var change := world.set_committed_by_offset(5, 5, sand_id, 127)
	var changes := TerrainChangeSet.new(world.dimensions, 20, 32)
	changes.add_change(change.index, change.previous_id, change.next_id, metadata, change.previous_fill, change.next_fill)
	activity.mark_change_set(changes)
	for _frame in range(10):
		presenter.refresh_visible_chunks(0)
		if presenter.pending_job_count() == 0:
			break

	assert_eq(presenter.chunk_collision_segment_count(Vector2i.ZERO), 0)
