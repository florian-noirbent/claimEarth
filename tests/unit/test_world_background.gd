extends GutTest


func _background() -> WorldBackground:
	var background := WorldBackground.new()
	background.presentation_config = load("res://config/presentation/default_world_presentation.tres").duplicate(true) as WorldPresentationConfig
	return background


func test_world_background_splits_sky_and_cave_at_level_zero() -> void:
	var background := _background()
	add_child_autofree(background)

	background.presentation_config.sky_height = 120.0
	background.configure_bounds(-50.0, 150.0, 0.0, 300.0)

	assert_eq(background.sky_rect(), Rect2(-50.0, -120.0, 200.0, 120.0))
	assert_eq(background.cave_rect(), Rect2(-50.0, 0.0, 200.0, 300.0))


func test_world_background_clamps_cave_height_above_bottom_edge() -> void:
	var background := _background()
	add_child_autofree(background)

	background.configure_bounds(-16.0, 16.0, 0.0, -8.0)

	assert_eq(background.cave_rect(), Rect2(-16.0, 0.0, 32.0, 0.0))


func test_world_background_exposes_cave_grading_parameters() -> void:
	var background := _background()
	add_child_autofree(background)

	background.presentation_config.cave_saturation = 0.35
	background.presentation_config.cave_brightness = 0.7
	background.presentation_config.cave_contrast = 0.8
	background.presentation_config.depth_darkening = 0.4
	background.configure_bounds(-32.0, 96.0, 0.0, 200.0)

	var parameters := background.shader_parameters()
	assert_eq(parameters["left_edge"], -32.0)
	assert_eq(parameters["right_edge"], 96.0)
	assert_eq(parameters["level_zero_y"], 0.0)
	assert_eq(parameters["cave_saturation"], 0.35)
	assert_eq(parameters["cave_brightness"], 0.7)
	assert_eq(parameters["cave_contrast"], 0.8)
	assert_eq(parameters["depth_darkening"], 0.4)


func test_world_background_positions_grass_band_on_level_zero_edge() -> void:
	var background := _background()
	var image := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	add_child_autofree(background)

	background.presentation_config.grass_band_texture = texture
	background.presentation_config.grass_band_scale = 2.0
	background.presentation_config.grass_band_y_offset = 3.0
	background.presentation_config.grass_band_top_crop_px = 1.0
	background.presentation_config.grass_band_bottom_crop_px = 1.0
	background.configure_bounds(-20.0, 80.0, 0.0, 200.0)

	assert_eq(background.grass_band_rect(), Rect2(-20.0, -9.0, 100.0, 12.0))
	var parameters := background.shader_parameters()
	assert_eq(parameters["grass_band_top"], -9.0)
	assert_eq(parameters["grass_band_bottom"], 3.0)
