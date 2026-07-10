extends GutTest

const WorldPresenterShader = preload("res://src/presentation/world_presenter.gdshader")
const RenderTextureSimulationBackendScript = preload("res://src/simulation/render_texture_simulation_backend.gd")


func test_world_presenter_uses_single_shader_renderer_and_uploads_full_grid() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))

	presenter.configure(world, registry)

	assert_eq(presenter.total_renderer_nodes(), 1)
	assert_eq(presenter.get_child_count(), 1)
	var material := (presenter.get_child(0) as Polygon2D).material as ShaderMaterial
	assert_eq(material.shader, WorldPresenterShader)
	assert_eq(_world_pixel_bytes(world, 2, 2)[0], FixtureLoader.terrain_id("Stone"))
	assert_not_null(presenter.material_atlas_texture())


func test_world_presenter_material_atlas_uses_full_size_material_slots() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var metadata := CompiledTerrainData.compile(registry)
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Stone"))

	presenter.configure(world, registry)

	var atlas_image := presenter.material_atlas_texture().get_image()
	var material_count := metadata.materials.size() - 1
	var columns := presenter.material_atlas_columns()
	var rows := maxi(1, ceili(float(material_count) / float(columns)))
	var stride := presenter.material_atlas_tile_size + 2
	assert_eq(presenter.material_atlas_tile_size, 1024)
	assert_eq(atlas_image.get_width(), stride * columns)
	assert_eq(atlas_image.get_height(), stride * rows)


func test_world_presenter_properties_store_material_index_and_scale() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var metadata := CompiledTerrainData.compile(registry)
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Stone"))

	presenter.configure(world, registry)

	var stone_id := FixtureLoader.terrain_id("Stone")
	var dirt_id := FixtureLoader.terrain_id("Dirt")
	assert_eq(_texture_byte(presenter.property_texture(), stone_id, 2), int(metadata.material_index_by_id[stone_id]))
	assert_eq(_texture_byte(presenter.property_texture(), dirt_id, 2), int(metadata.material_index_by_id[dirt_id]))
	assert_gt(_texture_byte(presenter.property_texture(), stone_id, 2), 0)
	assert_gt(_texture_byte(presenter.property_texture(), dirt_id, 2), 0)
	assert_eq(_texture_byte(presenter.property_texture(), stone_id, 3), 255)


func test_world_presenter_edge_style_texture_packs_edge_color_and_width() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var metadata := CompiledTerrainData.compile(registry)
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Stone"))

	presenter.configure(world, registry)

	var stone_id := FixtureLoader.terrain_id("Stone")
	var edge_style := presenter.edge_style_texture().get_image().get_pixel(stone_id, 0)
	var expected_color := metadata.edge_color_by_id[stone_id]
	var expected_width := metadata.edge_width_by_id[stone_id]
	assert_eq(_color_byte(edge_style.r), _color_byte(expected_color.r))
	assert_eq(_color_byte(edge_style.g), _color_byte(expected_color.g))
	assert_eq(_color_byte(edge_style.b), _color_byte(expected_color.b))
	assert_eq(_color_byte(edge_style.a), roundi(clampf(expected_width / 16.0, 0.0, 1.0) * 255.0))


func test_world_presenter_binds_fluid_material_uniforms() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Water"))

	presenter.configure(world, FixtureLoader.terrain_registry())

	var material := (presenter.get_child(0) as Polygon2D).material as ShaderMaterial
	assert_eq(material.get_shader_parameter("fluid_alpha"), presenter.fluid_alpha)
	assert_eq(material.get_shader_parameter("fluid_caustic_strength"), presenter.fluid_caustic_strength)
	assert_eq(material.get_shader_parameter("fluid_caustic_scale"), presenter.fluid_caustic_scale)
	assert_eq(material.get_shader_parameter("fluid_caustic_speed"), presenter.fluid_caustic_speed)
	assert_eq(material.get_shader_parameter("fluid_shimmer_strength"), presenter.fluid_shimmer_strength)
	assert_eq(material.get_shader_parameter("fluid_surface_glow_width"), presenter.fluid_surface_glow_width)
	assert_eq(material.get_shader_parameter("fluid_surface_glow_strength"), presenter.fluid_surface_glow_strength)
	assert_eq(material.get_shader_parameter("fluid_hot_glow_strength"), presenter.fluid_hot_glow_strength)


func test_world_presenter_upload_world_reflects_committed_grid_changes() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	presenter.configure(world, registry)
	var before_revision: int = world.texture_revision

	world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Sand"), 127)
	presenter.upload_world()

	assert_eq(world.texture_revision, before_revision + 1)
	assert_eq(_world_pixel_bytes(world, 5, 5), PackedByteArray([FixtureLoader.terrain_id("Sand"), 127, 255, 255]))


func test_world_presenter_keeps_single_renderer_after_repeated_uploads() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var world := WorldGrid.new(WorldDimensions.new(100, 200), FixtureLoader.terrain_id("Stone"))
	presenter.configure(world, FixtureLoader.terrain_registry())

	for _frame in range(10):
		presenter.upload_world()

	assert_eq(presenter.total_renderer_nodes(), 1)
	assert_eq(world.texture_revision, 12)


func test_world_presenter_can_bind_backend_phase_textures() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 0, FixtureLoader.terrain_id("Sand"))
	presenter.configure(world, FixtureLoader.terrain_registry())
	var backend = RenderTextureSimulationBackendScript.new()
	backend.initialize(world, FixtureLoader.terrain_registry(), 123)
	add_child_autofree(backend.render_root())

	for _pass in range(RenderTextureSimulationBackendScript.PASS_COUNT):
		backend.advance(0)
	presenter.use_simulation_textures(backend.presentation_texture(), backend.presentation_even_texture())

	var material := (presenter.get_child(0) as Polygon2D).material as ShaderMaterial
	assert_eq(material.get_shader_parameter("world_data"), backend.presentation_texture())
	assert_eq(material.get_shader_parameter("even_world"), backend.presentation_even_texture())


func _presenter() -> WorldPresenter:
	var presenter := WorldPresenter.new()
	presenter.terrain_shader = WorldPresenterShader
	return presenter


func _texture_byte(texture: ImageTexture, x: int, channel: int) -> int:
	var pixel := texture.get_image().get_pixel(x, 0)
	var channels := [pixel.r, pixel.g, pixel.b, pixel.a]
	return roundi(channels[channel] * 255.0)


func _world_pixel_bytes(world: WorldGrid, x: int, y: int) -> PackedByteArray:
	var pixel := world.cell_image.get_pixel(x, y)
	return PackedByteArray([
		_color_byte(pixel.r),
		_color_byte(pixel.g),
		_color_byte(pixel.b),
		_color_byte(pixel.a),
	])


func _color_byte(value: float) -> int:
	return roundi(clampf(value, 0.0, 1.0) * 255.0)
