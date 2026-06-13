extends GutTest


func test_start_transitions_from_menu_to_generating_to_playing() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.generation_delay_seconds = 0.001
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


func test_back_to_menu_restores_menu_visibility() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.generation_delay_seconds = 0.001
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.PLAYING)
	app_root.back_to_menu_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)
	assert_true(app_root.menu_panel.visible)
	assert_false(app_root.playing_panel.visible)
