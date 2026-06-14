extends GutTest


func test_configure_exposes_valid_registries_and_empty_read_models() -> void:
	var controller := RunWorldController.new()
	var presenter := WorldPresenter.new()
	var markers := Node2D.new()
	var boundaries := WorldSideBoundaries.new()
	add_child_autofree(controller)
	add_child_autofree(presenter)
	add_child_autofree(markers)
	add_child_autofree(boundaries)

	controller.configure(
		load("res://config/generation/default_profile.tres"),
		load("res://scenes/player/player.tscn"),
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
