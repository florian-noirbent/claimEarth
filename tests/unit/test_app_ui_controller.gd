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
			{"name": "Small Bomb", "icon": load("res://assets/vector/small_bomb.svg"), "count": 10, "selected": true, "shortcut": 1},
			{"name": "Large Bomb", "icon": load("res://assets/vector/large_bomb.svg"), "count": 2, "selected": false, "shortcut": 2},
			{"name": "Flag", "icon": load("res://assets/vector/flag.svg"), "count": 1, "selected": false, "shortcut": 3},
		],
	})

	assert_true(ui.item_toolbar.visible)
	assert_true(ui.pause_button.visible)
	assert_eq(ui.item_toolbar_content.get_child_count(), 3)
	var selected_slot := ui.item_toolbar_content.get_child(0) as ItemToolbarSlot
	assert_eq(selected_slot.get_theme_stylebox("panel"), selected_slot.selected_style)
	assert_not_null(selected_slot.icon_rect.texture)
	assert_eq(selected_slot.key_label.text, "1")
	assert_eq(selected_slot.key_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(selected_slot.count_label.text, "x10")
	assert_eq(selected_slot.count_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_false(ui.selection_name_label.visible)

	ui.show_run_status(12, 20, false, {
		"flag_in_flight": false,
		"items": [
			{"name": "Small Bomb", "icon": load("res://assets/vector/small_bomb.svg"), "count": 10, "selected": false, "shortcut": 1},
			{"name": "Large Bomb", "icon": load("res://assets/vector/large_bomb.svg"), "count": 2, "selected": true, "shortcut": 2},
			{"name": "Flag", "icon": load("res://assets/vector/flag.svg"), "count": 1, "selected": false, "shortcut": 3},
		],
	})
	assert_true(ui.selection_name_label.visible)
	assert_eq(ui.selection_name_label.text, "Large Bomb")

	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	assert_false(ui.item_toolbar.visible)
	assert_false(ui.pause_button.visible)
	assert_true(ui.pause_panel.visible)


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
