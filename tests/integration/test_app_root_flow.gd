extends GutTest


const DeathCauseScript = preload("res://src/player/death_cause.gd")
const FakeLeaderboardServiceScript = preload("res://src/leaderboard/fake_leaderboard_service.gd")
const GameplayAssertionsScript = preload("res://tests/helpers/gameplay_assertions.gd")
const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")


func before_each() -> void:
	for suffix in ["1", "2", "3", "4", "5", "move", "flag", "hazards", "inventory_reset", "pause_click", "projectile_disposal", "static_menu", "toolbar_button"]:
		var path := "user://gut_app_root_flow_%s.json" % suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_start_transitions_from_menu_to_generating_to_playing() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_1.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)

	watch_signals(app_root)
	app_root.ui.menu_start_button.pressed.emit()

	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)

	assert_signal_emitted(app_root, "generation_started")
	assert_signal_emitted(app_root, "gameplay_started")
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	assert_false(app_root.simulation_backend().is_available())
	assert_false(app_root.ui.menu_root.visible)
	assert_false(app_root.ui.menu_background.visible)
	assert_false(app_root.ui.menu_panel.visible)
	assert_false(app_root.ui.title_image.visible)
	assert_false(app_root.ui.status_label.visible)
	var left_edge := HexMetrics.center_for_offset(0, 0, app_root.world_presenter.hex_radius).x - app_root.world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(app_root.generation_profile.width - 1, 0, app_root.world_presenter.hex_radius).x + app_root.world_presenter.hex_radius
	var expected_zoom := app_root.get_viewport_rect().size.x / (right_edge - left_edge)
	assert_almost_eq(app_root.get_player().camera.zoom.x, expected_zoom, 0.005)
	var spawn_offset := HexMetrics.offset_for_world(app_root.get_player().global_position, app_root.world_presenter.hex_radius)
	assert_eq(spawn_offset.y, app_root.last_generation_result_for_test().spawn_rect.position.y)
	app_root.get_player().global_position = HexMetrics.center_for_offset(0, spawn_offset.y, app_root.world_presenter.hex_radius)
	app_root.get_player().velocity.x = -500.0
	await wait_physics_frames(1)
	assert_gte(app_root.get_player().global_position.x, left_edge)
	assert_gte(app_root.get_player().velocity.x, 0.0)
	app_root.get_player().global_position = HexMetrics.center_for_offset(app_root.generation_profile.width - 1, spawn_offset.y, app_root.world_presenter.hex_radius)
	app_root.get_player().velocity.x = 500.0
	await wait_physics_frames(1)
	assert_lte(app_root.get_player().global_position.x, right_edge)
	assert_lte(app_root.get_player().velocity.x, 0.0)
	GameplayAssertionsScript.assert_app_is_playing(self, app_root)


func test_start_enables_player_movement_input() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_move.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.ui.menu_start_button.pressed.emit()
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)

	var start_x := app_root.get_player().global_position.x
	Input.action_press(InputActions.MOVE_RIGHT)
	await wait_physics_frames(5)
	Input.action_release(InputActions.MOVE_RIGHT)

	assert_gt(app_root.get_player().global_position.x, start_x + 1.0)


func test_back_to_menu_restores_menu_visibility() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_2.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.PLAYING)
	app_root.ui.pause_button.pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.PAUSED)
	app_root.ui.pause_menu_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)
	assert_true(app_root.ui.menu_root.visible)
	assert_true(app_root.ui.menu_background.visible)
	assert_true(app_root.ui.menu_panel.visible)
	assert_false(app_root.ui.playing_panel.visible)


func test_default_menu_uses_static_background_without_preview_session() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	var service: FakeLeaderboardService = FakeLeaderboardServiceScript.new()
	app_root.configure_save_path_for_test("user://gut_app_root_flow_static_menu.json")
	app_root.configure_leaderboard_service_for_test(service)
	add_child_autofree(app_root)
	await wait_process_frames(2)

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)
	assert_eq(app_root.active_session_count(), 0)
	assert_true(app_root.ui.menu_art_background.visible)
	assert_not_null(app_root.ui.menu_art_background.texture)
	assert_true(app_root.ui.title_image.visible)
	assert_not_null(app_root.ui.title_image.texture)
	assert_true(app_root.ui.menu_background.visible)


func test_flag_landing_opens_name_entry_and_confirming_shows_result() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_3.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("name-entry-flow"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	app_root.item_controller.resolve_flag_landing(null, HexMetrics.center_for_offset(5, 25, app_root.world_presenter.hex_radius), null, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.NAME_ENTRY)
	assert_true(app_root.ui.name_entry_panel.visible)
	assert_eq(app_root.ui.player_name_input.text, "Player")

	app_root.ui.player_name_input.text = "Florian"
	app_root.ui.confirm_score_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.RESULT)
	assert_true(app_root.ui.result_panel.visible)
	assert_string_contains(app_root.ui.result_status.text, "Florian")
	assert_string_contains(app_root.ui.result_status.text, "25")


func test_death_locks_out_later_terminal_outcomes() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_4.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("death-lock-flow"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	app_root._on_player_death_requested(DeathCauseScript.LAVA)
	app_root.item_controller.resolve_flag_landing(null, HexMetrics.center_for_offset(5, 40, app_root.world_presenter.hex_radius), null, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)
	assert_string_contains(app_root.ui.result_status.text, "Lava")


func test_pause_toggles_from_playing_and_back() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_5.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("pause-flow"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)
	app_root.ui.pause_button.pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.PAUSED)
	assert_false(app_root.get_player().is_physics_processing())

	app_root.ui.resume_button.pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	assert_true(app_root.get_player().is_physics_processing())


func test_start_run_for_test_throws_flag_and_locks_item_flow() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_flag.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("flag-flow"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)
	await wait_seconds(1.1)

	app_root.select_item_for_test(2)
	ScenarioDriverScript.set_mouse_world_position(app_root, app_root.get_player().global_position + Vector2(80, 0))
	app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2.DOWN * 20.0)

	assert_eq(app_root.get_run_state(), RunPhase.FLAG_IN_FLIGHT)
	assert_eq(app_root.active_projectile_count(), 1)


func test_start_run_for_test_blocks_throwing_for_first_second() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_throw_lock.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("throw-lock"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)

	app_root.select_item_for_test(0)
	ScenarioDriverScript.set_mouse_world_position(app_root, app_root.get_player().global_position + Vector2(80, 0))
	app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2.DOWN * 20.0)

	assert_eq(app_root.active_projectile_count(), 0)
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)


func test_hazards_apply_in_live_run() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_hazards.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("hazard-flow"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)

	var world := app_root.current_world()
	var lava_id := FixtureLoader.terrain_id("Lava")
	var player_offset := HexMetrics.offset_for_world(app_root.get_player().global_position, app_root.world_presenter.hex_radius)
	for row in range(player_offset.y - 2, player_offset.y + 12):
		for col in range(player_offset.x - 2, player_offset.x + 3):
			if world.dimensions.is_in_bounds_offset(col, row):
				world.set_committed_by_offset(col, row, lava_id)
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.DEATH
	, 0.5)

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)


func test_repeated_menu_and_restart_cycles_keep_single_player_and_clear_projectiles() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_cycles.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	for run_index in range(3):
		app_root.start_run_for_test(SeedUtils.seed_from_text("cycle-%d" % run_index))
		await wait_until(func() -> bool:
			return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
		, 2.0)
		var player_count := 0
		for child in app_root.world_controller.get_children():
			if child is PlayerController:
				player_count += 1
		assert_eq(player_count, 1)
		assert_eq(app_root.active_session_count(), 1)
		assert_eq(app_root.active_projectile_count(), 0)
		app_root.transition_to(RunPhase.MAIN_MENU)
		await wait_process_frames(1)
		assert_eq(app_root.active_session_count(), 0)


func test_restart_resets_inventory_and_selection() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_inventory_reset.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("inventory-reset-1"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	app_root.select_item_for_test(1)
	assert_true(app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2.UP * 100.0, true))
	var depleted := app_root.inventory_status_for_test()
	assert_eq(depleted.items[1].count, 1)
	assert_eq(depleted.selected_name, "Large Bomb")

	app_root.start_run_for_test(SeedUtils.seed_from_text("inventory-reset-2"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	var reset_status := app_root.inventory_status_for_test()
	assert_eq(reset_status.items[0].count, 10)
	assert_eq(reset_status.items[1].count, 2)
	assert_eq(reset_status.items[2].count, 1)
	assert_eq(reset_status.selected_name, "Small Bomb")


func test_pause_button_does_not_throw_selected_item() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_pause_click.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("pause-click"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	var before := app_root.inventory_status_for_test()
	Input.action_press(InputActions.THROW_SELECTED)
	app_root.ui.pause_button.pressed.emit()
	await wait_process_frames(1)
	Input.action_release(InputActions.THROW_SELECTED)

	assert_eq(app_root.get_run_state(), RunPhase.PAUSED)
	assert_eq(app_root.active_projectile_count(), 0)
	assert_eq(app_root.inventory_status_for_test().items[0].count, before.items[0].count)


func test_world_click_throws_selected_item_through_passive_hud() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_world_click.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("world-click"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	await wait_seconds(1.1)
	var before: int = int(app_root.inventory_status_for_test().items[0].count)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(576.0, 324.0)
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	await wait_process_frames(1)

	assert_eq(app_root.active_projectile_count(), 1)
	assert_eq(app_root.inventory_status_for_test().items[0].count, before - 1)


func test_toolbar_button_selects_item_without_throwing() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_toolbar_button.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("toolbar-button"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	await wait_process_frames(1)
	var before := app_root.inventory_status_for_test()
	var large_bomb_button := app_root.ui.item_toolbar_content.get_child(1) as ItemToolbarSlot
	large_bomb_button.pressed.emit()
	await wait_process_frames(1)

	var after := app_root.inventory_status_for_test()
	assert_eq(after.selected_name, "Large Bomb")
	assert_eq(after.items[0].count, before.items[0].count)
	assert_eq(after.items[1].count, before.items[1].count)
	assert_eq(app_root.active_projectile_count(), 0)


func test_restart_disposes_old_projectiles_before_they_can_resolve() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_projectile_disposal.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("projectile-disposal-1"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	var old_session := app_root._session
	var old_world := app_root.current_world()
	assert_true(app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2.UP * 120.0, true))
	assert_true(app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2.UP * 160.0, true))
	assert_eq(app_root.active_projectile_count(), 2)

	app_root.start_run_for_test(SeedUtils.seed_from_text("projectile-disposal-2"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)
	assert_false(is_instance_valid(old_session))
	assert_ne(app_root.current_world(), old_world)
	assert_eq(app_root.active_projectile_count(), 0)
	var old_hash_after_disposal := old_world.committed_hash()
	await wait_seconds(2.6)
	assert_eq(old_world.committed_hash(), old_hash_after_disposal)
