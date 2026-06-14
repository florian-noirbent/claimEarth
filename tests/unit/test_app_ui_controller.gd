extends GutTest


func test_ui_controller_emits_intents_and_applies_phase_visibility() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	watch_signals(ui)
	ui.menu_start_button.pressed.emit()
	assert_signal_emitted(ui, "start_requested")

	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 73, "Miner")
	assert_true(ui.overlay_root.visible)
	assert_true(ui.name_entry_panel.visible)
	assert_eq(ui.name_entry_status.text, "Depth: 73")
	assert_eq(ui.player_name_input.text, "Miner")

	ui.apply_state(RunPhase.MAIN_MENU, 42, "storage warning", -1, "")
	assert_true(ui.menu_root.visible)
	assert_true(ui.warning_label.visible)
	assert_string_contains(ui.status_label.text, "42")


func test_confirm_button_emits_current_editable_name() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	watch_signals(ui)
	ui.player_name_input.text = "Deep Digger"
	ui.confirm_score_button.pressed.emit()
	assert_signal_emitted_with_parameters(ui, "score_confirmed", ["Deep Digger"])
