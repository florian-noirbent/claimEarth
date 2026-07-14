extends GutTest


func before_each() -> void:
	for suffix in ["playing", "flag"]:
		var path := "user://gut_item_chest_flow_%s.json" % suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_touching_chest_pauses_run_and_selected_reward_is_added_once() -> void:
	var app_root := await _start_app("playing")
	assert_eq(app_root.item_chest_count_for_test(), 19)
	assert_eq(app_root.simulation_backend().standard_light_source_count(), 19)
	var chest := _first_chest(app_root.item_controller)
	assert_not_null(chest)
	var chest_light_cell := chest.light_source.registered_offset()
	assert_eq(
		app_root.simulation_backend().standard_light_level_at(chest_light_cell),
		(load("res://config/lighting/chest_light.tres") as WorldLightSourceDefinition).light_level
	)
	assert_true(app_root.get_player().world_light_source.is_registered())
	var before := app_root.inventory_status_for_test()
	chest.touch_area.body_entered.emit(app_root.get_player())
	assert_eq(app_root.get_run_state(), RunPhase.REWARD_PICKER)
	assert_true(app_root.ui.reward_picker_layer.visible)
	assert_false(app_root.get_player().is_physics_processing())
	assert_eq(app_root.ui.reward_picker_cards.get_child_count(), 2)
	var first_card := app_root.ui.reward_picker_cards.get_child(0) as RewardPickerCard
	var reward_name := first_card.title_label.text
	var reward_amount := int(first_card.quantity_label.text.trim_prefix("+"))
	var before_count := _status_count(before, reward_name)

	first_card.pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	assert_eq(_status_count(app_root.inventory_status_for_test(), reward_name), before_count + reward_amount)
	await wait_process_frames(1)
	assert_eq(app_root.item_chest_count_for_test(), 18)
	assert_eq(app_root.simulation_backend().standard_light_source_count(), 18)
	assert_eq(app_root.simulation_backend().standard_light_level_at(chest_light_cell), 0)
	first_card.pressed.emit()
	assert_eq(_status_count(app_root.inventory_status_for_test(), reward_name), before_count + reward_amount)


func test_world_advance_synchronizes_the_player_light_to_the_current_cell() -> void:
	var app_root := await _start_app("playing")
	var player := app_root.get_player()
	var source := player.world_light_source
	var previous_cell := source.registered_offset()
	var current_cell := previous_cell + Vector2i(0, 1)
	player.global_position = HexMetrics.center_for_offset(
		current_cell.x,
		current_cell.y,
		app_root.world_presenter.hex_radius
	)

	app_root.world_controller.advance(0.0)

	assert_eq(source.registered_offset(), current_cell)


func test_reward_picker_restores_flag_in_flight_phase() -> void:
	var app_root := await _start_app("flag")
	app_root.select_item_for_test(2)
	assert_true(app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2(100.0, 0.0), true))
	assert_eq(app_root.get_run_state(), RunPhase.FLAG_IN_FLIGHT)
	var chest := _first_chest(app_root.item_controller)
	chest.touch_area.body_entered.emit(app_root.get_player())
	assert_eq(app_root.get_run_state(), RunPhase.REWARD_PICKER)
	var projectiles := app_root.item_controller.get_children().filter(func(child: Node) -> bool: return child is ItemProjectile)
	assert_false((projectiles[0] as ItemProjectile).is_physics_processing())

	(app_root.ui.reward_picker_cards.get_child(0) as RewardPickerCard).pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.FLAG_IN_FLIGHT)


func test_explosion_arming_pending_chest_closes_picker_without_reward() -> void:
	var app_root := await _start_app("playing")
	var chest := _first_chest(app_root.item_controller)
	var before := app_root.inventory_status_for_test()
	chest.touch_area.body_entered.emit(app_root.get_player())
	assert_eq(app_root.get_run_state(), RunPhase.REWARD_PICKER)

	app_root.item_controller.resolve_explosion(chest.spawn_data.definition.explosion_definition, chest.global_position)

	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	assert_false(app_root.ui.reward_picker_layer.visible)
	assert_eq(app_root.inventory_status_for_test(), before)
	assert_true(chest.explosive.is_chain_armed())


func _start_app(suffix: String) -> AppRoot:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_item_chest_flow_%s.json" % suffix)
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	app_root.start_run_for_test(SeedUtils.seed_from_text("item-chest-flow-%s" % suffix))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	return app_root


func _first_chest(controller: RunItemController) -> ItemChest:
	for child in controller.get_children():
		if child is ItemChest:
			return child as ItemChest
	return null


func _status_count(status: Dictionary, item_name: String) -> int:
	for item in status.items:
		if item.name == item_name:
			return int(item.count)
	return 0
