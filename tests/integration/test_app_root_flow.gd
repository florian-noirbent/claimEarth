extends GutTest


const DeathCauseScript = preload("res://src/player/death_cause.gd")


func test_start_transitions_from_menu_to_generating_to_playing() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
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


func test_back_to_menu_restores_menu_visibility() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
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
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.PLAYING)
	app_root._on_player_death_requested(DeathCauseScript.LAVA)
	app_root.resolve_flag_landing(null, HexMetrics.center_for_offset(5, 40, app_root.world_presenter.hex_radius), null, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)
	assert_string_contains(app_root.result_status.text, "Lava")
