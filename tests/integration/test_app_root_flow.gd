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
	app_root.menu_start_button.pressed.emit()

	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 1.0)

	assert_signal_emitted(app_root, "generation_started")
	assert_signal_emitted(app_root, "gameplay_started")
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	assert_false(app_root.menu_root.visible)
	assert_false(app_root.menu_background.visible)
	assert_false(app_root.menu_panel.visible)
	assert_false(app_root.title_label.visible)
	assert_false(app_root.status_label.visible)
	GameplayAssertionsScript.assert_app_is_playing(self, app_root)


func test_start_enables_player_movement_input() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_move.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.menu_start_button.pressed.emit()
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
	app_root.back_to_menu_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)
	assert_true(app_root.menu_root.visible)
	assert_true(app_root.menu_background.visible)
	assert_true(app_root.menu_panel.visible)
	assert_false(app_root.playing_panel.visible)


func test_flag_landing_opens_name_entry_and_confirming_shows_result() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_3.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.PLAYING)
	app_root.resolve_flag_landing(null, HexMetrics.center_for_offset(5, 25, app_root.world_presenter.hex_radius), null, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.NAME_ENTRY)
	assert_true(app_root.name_entry_panel.visible)
	assert_eq(app_root.player_name_input.text, "Player")

	app_root.player_name_input.text = "Florian"
	app_root.confirm_score_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.RESULT)
	assert_true(app_root.result_panel.visible)
	assert_string_contains(app_root.result_status.text, "Florian")
	assert_string_contains(app_root.result_status.text, "25")


func test_death_locks_out_later_terminal_outcomes() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_app_root_flow_4.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.PLAYING)
	app_root._on_player_death_requested(DeathCauseScript.LAVA)
	app_root.resolve_flag_landing(null, HexMetrics.center_for_offset(5, 40, app_root.world_presenter.hex_radius), null, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)
	assert_string_contains(app_root.result_status.text, "Lava")


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

	app_root._item_inventory.select_index(2)
	ScenarioDriverScript.set_mouse_world_position(app_root, app_root.get_player().global_position + Vector2(80, 0))
	app_root._throw_selected_item()

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

	app_root._item_inventory.select_index(0)
	ScenarioDriverScript.set_mouse_world_position(app_root, app_root.get_player().global_position + Vector2(80, 0))
	app_root._throw_selected_item()

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
