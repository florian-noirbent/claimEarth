extends GutTest


const DeathCauseScript = preload("res://src/player/death_cause.gd")
const GameplayAssertionsScript = preload("res://tests/helpers/gameplay_assertions.gd")
const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")


func before_each() -> void:
	for suffix in ["1", "2", "3", "4", "5", "move", "flag", "hazards"]:
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
	assert_false(app_root.ui.menu_root.visible)
	assert_false(app_root.ui.menu_background.visible)
	assert_false(app_root.ui.menu_panel.visible)
	assert_false(app_root.ui.title_label.visible)
	assert_false(app_root.ui.status_label.visible)
	var left_edge := HexMetrics.center_for_offset(0, 0, app_root.world_presenter.hex_radius).x - app_root.world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(app_root.generation_profile.width - 1, 0, app_root.world_presenter.hex_radius).x + app_root.world_presenter.hex_radius
	var expected_zoom := app_root.get_viewport_rect().size.x / (right_edge - left_edge)
	assert_almost_eq(app_root.get_player().camera.zoom.x, expected_zoom, 0.005)
	assert_almost_eq(app_root.world_side_boundaries.left_wall_inner_edge(), left_edge, 0.001)
	assert_almost_eq(app_root.world_side_boundaries.right_wall_inner_edge(), right_edge, 0.001)
	var spawn_offset := HexMetrics.offset_for_world(app_root.get_player().global_position, app_root.world_presenter.hex_radius)
	assert_eq(spawn_offset.y, app_root.last_generation_result_for_test().spawn_rect.position.y + 1)
	app_root.get_player().global_position.x = left_edge - 100.0
	app_root.get_player().velocity.x = -500.0
	await wait_physics_frames(1)
	assert_gte(app_root.get_player().global_position.x, left_edge + app_root.get_player().horizontal_collision_radius)
	assert_gte(app_root.get_player().velocity.x, 0.0)
	app_root.get_player().global_position.x = right_edge + 100.0
	app_root.get_player().velocity.x = 500.0
	await wait_physics_frames(1)
	assert_lte(app_root.get_player().global_position.x, right_edge - app_root.get_player().horizontal_collision_radius)
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
	app_root.ui.back_to_menu_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)
	assert_true(app_root.ui.menu_root.visible)
	assert_true(app_root.ui.menu_background.visible)
	assert_true(app_root.ui.menu_panel.visible)
	assert_false(app_root.ui.playing_panel.visible)


func test_flag_landing_opens_name_entry_and_confirming_shows_result() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_3.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.PLAYING)
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

	app_root.transition_to(RunPhase.PLAYING)
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
	app_root.transition_to(RunPhase.PAUSED)
	assert_eq(app_root.get_run_state(), RunPhase.PAUSED)
	assert_false(app_root.get_player().is_physics_processing())

	app_root.transition_to(RunPhase.PLAYING)
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
	world.set_committed_by_offset(player_offset.x, player_offset.y, lava_id)
	await wait_physics_frames(2)

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)


func test_starting_run_cancels_preview_without_overwriting_active_world() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_preview_cancel.json")
	app_root.set_test_mode(true)
	app_root.set_menu_preview_enabled(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	var run_seed := SeedUtils.seed_from_text("preview-cancel-run")
	app_root.start_run_for_test(run_seed)
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)

	assert_eq(app_root.last_generation_result_for_test().final_seed, SeedUtils.derive_seed(run_seed, "attempt_0"))


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
		assert_eq(app_root.active_projectile_count(), 0)
		app_root.transition_to(RunPhase.MAIN_MENU)
		await wait_process_frames(1)
