extends GutTest


func test_configure_exposes_valid_registries_and_empty_read_models() -> void:
	var controller := RunWorldController.new()
	controller.terrain_catalog = load("res://config/terrain/catalog.tres")
	controller.item_catalog = load("res://config/items/catalog.tres")
	var background := WorldBackground.new()
	background.presentation_config = load("res://config/presentation/default_world_presentation.tres").duplicate(true) as WorldPresentationConfig
	var presenter := WorldPresenter.new()
	presenter.presentation_config = load("res://config/presentation/default_world_presentation.tres").duplicate(true) as WorldPresentationConfig
	var markers := Node2D.new()
	var boundaries := WorldSideBoundaries.new()
	add_child_autofree(controller)
	add_child_autofree(background)
	add_child_autofree(presenter)
	add_child_autofree(markers)
	add_child_autofree(boundaries)

	controller.configure(
		load("res://config/generation/default_profile.tres"),
		load("res://scenes/player/player.tscn"),
		background,
		presenter,
		markers,
		boundaries
	)

	assert_not_null(controller.terrain_registry())
	assert_not_null(controller.item_registry())
	assert_null(controller.current_world())
	assert_null(controller.player())


func test_cancel_generation_is_safe_before_any_generation_starts() -> void:
	var controller := RunWorldController.new()
	add_child_autofree(controller)
	controller.cancel_generation()
	assert_null(controller.current_world())


func test_leaving_active_gameplay_clears_accumulated_simulation_time() -> void:
	var controller := RunWorldController.new()
	add_child_autofree(controller)
	controller._simulation_clock.add_time(0.25)
	assert_gt(controller._simulation_clock.pending_passes(), 0.0)

	controller.set_active(false)

	assert_eq(controller._simulation_clock.pending_passes(), 0.0)
