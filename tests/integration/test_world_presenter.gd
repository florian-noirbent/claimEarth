extends GutTest

const WorldGridTextureScript = preload("res://src/presentation/world_grid_texture.gd")
const WorldPresenterShader = preload("res://src/presentation/world_presenter.gdshader")


func test_world_grid_texture_packs_committed_cell_id_fill_and_lighting() -> void:
	var world := WorldGrid.new(WorldDimensions.new(3, 2), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(1, 0, FixtureLoader.terrain_id("Water"), 128)
	var grid_texture = WorldGridTextureScript.new()

	grid_texture.upload_full(world)

	assert_eq(grid_texture.texel_bytes(1, 0), PackedByteArray([FixtureLoader.terrain_id("Water"), 128, 255, 255]))
	assert_eq(grid_texture.upload_count, 1)


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
	assert_eq(presenter.grid_texture().texel_bytes(2, 2)[0], FixtureLoader.terrain_id("Stone"))
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


func test_world_presenter_upload_world_reflects_committed_grid_changes() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	presenter.configure(world, registry)
	var before_uploads: int = presenter.grid_texture().upload_count

	world.set_committed_by_offset(5, 5, FixtureLoader.terrain_id("Sand"), 127)
	presenter.upload_world()

	assert_eq(presenter.grid_texture().upload_count, before_uploads + 1)
	assert_eq(presenter.grid_texture().texel_bytes(5, 5), PackedByteArray([FixtureLoader.terrain_id("Sand"), 127, 255, 255]))


func test_world_presenter_keeps_single_renderer_after_repeated_uploads() -> void:
	var presenter := _presenter()
	add_child_autofree(presenter)
	var world := WorldGrid.new(WorldDimensions.new(100, 200), FixtureLoader.terrain_id("Stone"))
	presenter.configure(world, FixtureLoader.terrain_registry())

	for _frame in range(10):
		presenter.upload_world()

	assert_eq(presenter.total_renderer_nodes(), 1)
	assert_eq(presenter.grid_texture().upload_count, 11)


func _presenter() -> WorldPresenter:
	var presenter := WorldPresenter.new()
	presenter.terrain_shader = WorldPresenterShader
	return presenter


func _texture_byte(texture: ImageTexture, x: int, channel: int) -> int:
	var pixel := texture.get_image().get_pixel(x, 0)
	var channels := [pixel.r, pixel.g, pixel.b, pixel.a]
	return roundi(channels[channel] * 255.0)


func _color_byte(value: float) -> int:
	return roundi(clampf(value, 0.0, 1.0) * 255.0)
