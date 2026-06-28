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

	ui.menu_help_button.pressed.emit()
	assert_true(ui.help_panel.visible)
	assert_false(ui.menu_panel.visible)
	assert_false(ui.controls_label.visible)
	ui.help_back_button.pressed.emit()
	assert_false(ui.help_panel.visible)
	assert_true(ui.menu_panel.visible)
	assert_eq(ui.help_back_button.custom_minimum_size, ui.leaderboard_back_button.custom_minimum_size)
	assert_eq(ui.help_back_button.icon, ui.leaderboard_back_button.icon)
	assert_eq(ui.help_back_button.focus_mode, Control.FOCUS_NONE)

	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 73, "Miner")
	assert_true(ui.overlay_root.visible)
	assert_true(ui.name_entry_panel.visible)
	assert_eq(ui.name_entry_panel.get_theme_stylebox("panel"), ui.help_panel.get_theme_stylebox("panel"))
	assert_eq(ui.confirm_score_button.get_theme_stylebox("normal"), ui.menu_start_button.get_theme_stylebox("normal"))
	assert_eq(ui.name_entry_status.text, "Depth: 73")
	assert_eq(ui.player_name_input.text, "Miner")
	assert_not_null(ui.player_name_input.get_theme_stylebox("normal"))

	ui.apply_state(RunPhase.MAIN_MENU, 42, "storage warning", -1, "")
	assert_true(ui.menu_root.visible)
	assert_true(ui.warning_label.visible)
	assert_false(ui.controls_label.visible)
	assert_string_contains(ui.status_label.text, "42")


func test_playing_ui_uses_toolbar_and_pause_controls() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_run_status(12, 20, false, {
		"flag_in_flight": false,
		"items": [
			{"name": "Small Bomb", "icon": load("res://assets/objects/small_bomb.svg"), "count": 10, "selected": true, "shortcut": 1},
			{"name": "Large Bomb", "icon": load("res://assets/objects/large_bomb.svg"), "count": 2, "selected": false, "shortcut": 2},
			{"name": "Flag", "icon": load("res://assets/objects/flag.svg"), "count": 1, "selected": false, "shortcut": 3},
		],
	})

	assert_true(ui.item_toolbar.visible)
	assert_true(ui.pause_button.visible)
	assert_not_null(ui.pause_button.icon)
	assert_eq(ui.pause_button.get_theme_stylebox("normal"), ui.menu_start_button.get_theme_stylebox("normal"))
	assert_eq(ui.item_toolbar_content.get_child_count(), 3)
	var selected_slot := ui.item_toolbar_content.get_child(0) as ItemToolbarSlot
	assert_eq(selected_slot.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(selected_slot.get_theme_stylebox("normal"), selected_slot.selected_style)
	assert_not_null(selected_slot.icon_rect.texture)
	assert_eq(selected_slot.key_label.text, "1")
	assert_eq(selected_slot.key_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(selected_slot.count_label.text, "x10")
	assert_eq(selected_slot.count_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_true(selected_slot.get_global_rect().encloses(selected_slot.icon_rect.get_global_rect()))
	assert_true(selected_slot.get_global_rect().encloses(selected_slot.count_label.get_global_rect()))
	assert_false(ui.selection_name_label.visible)
	watch_signals(ui)
	(ui.item_toolbar_content.get_child(1) as ItemToolbarSlot).pressed.emit()
	assert_signal_emitted_with_parameters(ui, "item_selected", [1])

	ui.show_run_status(12, 20, false, {
		"flag_in_flight": false,
		"items": [
			{"name": "Small Bomb", "icon": load("res://assets/objects/small_bomb.svg"), "count": 10, "selected": false, "shortcut": 1},
			{"name": "Large Bomb", "icon": load("res://assets/objects/large_bomb.svg"), "count": 2, "selected": true, "shortcut": 2},
			{"name": "Flag", "icon": load("res://assets/objects/flag.svg"), "count": 1, "selected": false, "shortcut": 3},
		],
	})
	assert_true(ui.selection_name_label.visible)
	assert_eq(ui.selection_name_label.text, "Large Bomb")

	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	assert_false(ui.item_toolbar.visible)
	assert_false(ui.pause_button.visible)
	assert_true(ui.pause_panel.visible)
	assert_eq(ui.resume_button.get_theme_stylebox("normal"), ui.menu_start_button.get_theme_stylebox("normal"))
	assert_not_null(ui.resume_button.icon)
	assert_eq(ui.pause_restart_button.get_theme_stylebox("normal"), ui.menu_start_button.get_theme_stylebox("normal"))
	assert_eq(ui.pause_restart_button.text, "Restart")
	assert_eq(ui.pause_menu_button.get_theme_stylebox("normal"), ui.menu_start_button.get_theme_stylebox("normal"))
	assert_eq(ui.pause_menu_button.text, "Exit to Menu")
	watch_signals(ui)
	ui.pause_restart_button.pressed.emit()
	assert_signal_emitted(ui, "restart_requested")

	ui.apply_state(RunPhase.DEATH, 42, "", -1, "")
	assert_true(ui.result_panel.visible)
	assert_eq(ui.result_panel.get_theme_stylebox("panel"), ui.help_panel.get_theme_stylebox("panel"))
	assert_eq(ui.restart_button.get_theme_stylebox("normal"), ui.menu_start_button.get_theme_stylebox("normal"))
	assert_eq(ui.result_menu_button.get_theme_stylebox("normal"), ui.menu_start_button.get_theme_stylebox("normal"))


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


func test_playing_ui_only_buttons_capture_mouse() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_run_status(12, 20, false, {
		"flag_in_flight": false,
		"items": [
			{"name": "Small Bomb", "icon": null, "count": 10, "selected": true, "shortcut": 1},
			{"name": "Large Bomb", "icon": null, "count": 2, "selected": false, "shortcut": 2},
			{"name": "Flag", "icon": null, "count": 1, "selected": false, "shortcut": 3},
		],
	})
	await wait_process_frames(1)

	var capturing_paths := PackedStringArray()
	var controls: Array[Node] = [app_root]
	controls.append_array(app_root.find_children("*", "Control", true, false))
	for node in controls:
		var control := node as Control
		if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			capturing_paths.append(str(control.get_path()))

	assert_eq(capturing_paths.size(), 4)
	assert_has(capturing_paths, str(ui.pause_button.get_path()))
	for child in ui.item_toolbar_content.get_children():
		assert_has(capturing_paths, str(child.get_path()))
