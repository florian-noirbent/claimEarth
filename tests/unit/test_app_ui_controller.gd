extends GutTest


func before_each() -> void:
	Engine.max_fps = 0
	_remove_frame_limit_test_settings()


func after_each() -> void:
	Engine.max_fps = 0
	_remove_frame_limit_test_settings()


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


func test_settings_toggle_and_touch_controls_follow_play_state() -> void:
	var settings_path := "user://gut_ui_frame_limit_settings.json"
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	app_root.configure_settings_path_for_test(settings_path)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	watch_signals(ui)
	ui.menu_settings_button.pressed.emit()
	await wait_process_frames(1)
	assert_true(ui.settings_panel.visible)
	assert_false(ui.menu_panel.visible)
	assert_signal_emitted(ui, "settings_requested")
	ui.phone_controls_toggle.toggled.emit(true)
	assert_signal_emitted_with_parameters(ui, "phone_controls_changed", [true])
	assert_eq(ui.frame_limit_slider.min_value, 0.0)
	assert_eq(ui.frame_limit_slider.max_value, 4.0)
	assert_eq(ui.frame_limit_slider.step, 1.0)
	assert_eq(ui.frame_limit_value_label.text, "Unlimited")
	var phone_controls_label := ui.get_node("Center/Content/SettingsPanel/SettingsMargin/SettingsContent/PhoneControlsRow/PhoneControlsLabel") as Label
	var phone_controls_hint := ui.get_node("Center/Content/SettingsPanel/SettingsMargin/SettingsContent/SettingsHint") as Label
	var frame_limit_title := ui.get_node("Center/Content/SettingsPanel/SettingsMargin/SettingsContent/FrameLimitTitle") as Label
	var frame_limit_hint := ui.get_node("Center/Content/SettingsPanel/SettingsMargin/SettingsContent/FrameLimitHint") as Label
	var aligned_left := phone_controls_label.get_global_rect().position.x
	assert_eq(phone_controls_hint.get_global_rect().position.x, aligned_left)
	assert_eq(frame_limit_title.get_global_rect().position.x, aligned_left)
	assert_eq(ui.frame_limit_slider.get_global_rect().position.x, aligned_left)
	assert_eq(frame_limit_hint.get_global_rect().position.x, aligned_left)
	assert_lt(phone_controls_hint.get_global_rect().position.y, frame_limit_title.get_global_rect().position.y)
	var expected_limits := [30, 60, 90, 120, 0]
	var expected_labels := ["30 FPS", "60 FPS", "90 FPS", "120 FPS", "Unlimited"]
	for index in range(expected_limits.size()):
		ui.set_frame_limit_fps(expected_limits[index])
		assert_eq(ui.frame_limit_slider.value, float(index))
		assert_eq(ui.frame_limit_value_label.text, expected_labels[index])
	ui.frame_limit_slider.value_changed.emit(0.0)
	assert_signal_emitted_with_parameters(ui, "frame_limit_changed", [30])
	assert_eq(ui.frame_limit_value_label.text, "30 FPS")
	assert_eq(Engine.max_fps, 30)
	ui.frame_limit_slider.value_changed.emit(4.0)
	assert_signal_emitted_with_parameters(ui, "frame_limit_changed", [0])
	assert_eq(ui.frame_limit_value_label.text, "Unlimited")
	assert_eq(Engine.max_fps, 0)

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	await wait_process_frames(1)
	assert_true(ui.left_touch_pad.visible)
	assert_true(ui.right_touch_pad.visible)
	var viewport_rect := get_viewport().get_visible_rect()
	var expected_left_rect := Rect2(32.0, 444.0, 244.0, 244.0)
	var expected_right_rect := Rect2(1004.0, 444.0, 244.0, 244.0)
	assert_eq(ui.left_touch_pad.get_global_rect(), expected_left_rect)
	assert_eq(ui.right_touch_pad.get_global_rect(), expected_right_rect)
	assert_true(viewport_rect.encloses(_touch_ring_rect(expected_left_rect)))
	assert_true(viewport_rect.encloses(_touch_ring_rect(expected_right_rect)))
	assert_false(expected_left_rect.intersects(ui.item_toolbar.get_global_rect()))
	assert_false(expected_right_rect.intersects(ui.item_toolbar.get_global_rect()))
	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	assert_false(ui.left_touch_pad.visible)
	assert_false(ui.right_touch_pad.visible)

	ui.settings_back_button.pressed.emit()
	assert_false(ui.settings_panel.visible)


func _touch_ring_rect(pad_rect: Rect2) -> Rect2:
	const OUTER_RING_RADIUS := 112.0
	var center := pad_rect.get_center()
	return Rect2(center - Vector2.ONE * OUTER_RING_RADIUS, Vector2.ONE * OUTER_RING_RADIUS * 2.0)


func _remove_frame_limit_test_settings() -> void:
	var settings_path := "user://gut_ui_frame_limit_settings.json"
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	if FileAccess.file_exists("%s.tmp" % settings_path):
		DirAccess.remove_absolute("%s.tmp" % settings_path)


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
	await wait_process_frames(1)
	assert_false(ui.item_toolbar.visible)
	assert_false(ui.pause_button.visible)
	assert_true(ui.pause_panel.visible)
	assert_true(ui.pause_panel.get_global_rect().encloses(ui.pause_help_button.get_global_rect()))
	assert_true(ui.pause_panel.get_global_rect().encloses(ui.pause_settings_button.get_global_rect()))
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


func test_help_and_settings_open_from_pause_and_return_to_pause() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	ui.pause_help_button.pressed.emit()
	await wait_process_frames(1)
	assert_true(ui.help_panel.is_visible_in_tree())
	assert_false(ui.pause_panel.visible)
	assert_false(ui.overlay_root.visible)
	assert_true(ui.menu_root.visible)
	var help_title := ui.get_node("Center/Content/HelpPanel/HelpMargin/HelpContent/HelpTitle") as Label
	var help_body := ui.get_node("Center/Content/HelpPanel/HelpMargin/HelpContent/HelpBody") as Label
	assert_gte(help_body.get_global_rect().position.y, help_title.get_global_rect().end.y)
	assert_lt(help_body.get_global_rect().position.y, get_viewport().get_visible_rect().get_center().y)
	assert_lte(help_body.get_global_rect().end.y, ui.help_back_button.get_global_rect().position.y)

	ui.help_back_button.pressed.emit()
	assert_false(ui.help_panel.visible)
	assert_false(ui.menu_root.visible)
	assert_true(ui.overlay_root.visible)
	assert_true(ui.pause_panel.visible)

	ui.pause_settings_button.pressed.emit()
	await wait_process_frames(1)
	assert_true(ui.settings_panel.is_visible_in_tree())
	assert_false(ui.pause_panel.visible)
	assert_false(ui.overlay_root.visible)
	assert_true(ui.menu_root.visible)

	ui.settings_back_button.pressed.emit()
	assert_false(ui.settings_panel.visible)
	assert_false(ui.menu_root.visible)
	assert_true(ui.overlay_root.visible)
	assert_true(ui.pause_panel.visible)


func test_fps_display_formats_and_samples_only_during_active_play() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	assert_eq(ui.fps_timer.wait_time, 0.5)
	assert_true(ui.fps_timer.is_stopped())
	assert_false(ui.fps_label.is_visible_in_tree())

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_fps(73)
	await wait_process_frames(1)
	assert_eq(ui.fps_label.text, "FPS: 73")
	assert_true(ui.fps_label.is_visible_in_tree())
	assert_false(ui.fps_timer.is_stopped())
	assert_gt(ui.fps_label.get_global_rect().position.y, ui.run_state_label.get_global_rect().position.y)

	ui.apply_state(RunPhase.FLAG_IN_FLIGHT, 42, "", -1, "")
	assert_true(ui.fps_label.is_visible_in_tree())
	assert_false(ui.fps_timer.is_stopped())

	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	assert_false(ui.fps_label.is_visible_in_tree())
	assert_true(ui.fps_timer.is_stopped())


func test_web_fullscreen_control_is_persistent_and_keeps_pause_in_the_top_right_row() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	ui.set_web_fullscreen_available(true)
	for state in [
		RunPhase.MAIN_MENU,
		RunPhase.GENERATING,
		RunPhase.PLAYING,
		RunPhase.FLAG_IN_FLIGHT,
		RunPhase.NAME_ENTRY,
		RunPhase.PAUSED,
		RunPhase.SUBMITTING,
		RunPhase.DEATH,
		RunPhase.RESULT,
		RunPhase.LEADERBOARD,
	]:
		ui.apply_state(state, 42, "", -1, "")
		await wait_process_frames(1)
		assert_true(ui.fullscreen_button.visible, "Fullscreen should remain visible in %s" % state)
		assert_eq(ui.fullscreen_button.get_global_rect(), Rect2(1202.0, 24.0, 54.0, 54.0))

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.set_phone_controls_enabled(true)
	await wait_process_frames(1)
	var fullscreen_rect := ui.fullscreen_button.get_global_rect()
	assert_eq(ui.pause_button.get_global_rect(), Rect2(1140.0, 24.0, 54.0, 54.0))
	assert_false(ui.pause_button.get_global_rect().intersects(fullscreen_rect))
	assert_false(ui.playing_panel.get_global_rect().intersects(fullscreen_rect))
	assert_false(ui.hazard_meter_stack.get_global_rect().intersects(fullscreen_rect))
	assert_false(ui.item_toolbar.get_global_rect().intersects(fullscreen_rect))
	assert_false(ui.left_touch_pad.get_global_rect().intersects(fullscreen_rect))
	assert_false(ui.right_touch_pad.get_global_rect().intersects(fullscreen_rect))
	assert_eq(ui.fullscreen_button.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_not_null(ui.fullscreen_button.icon)
	assert_eq(ui.fullscreen_button.get_theme_stylebox("normal"), ui.pause_button.get_theme_stylebox("normal"))

	watch_signals(ui)
	ui.fullscreen_button.pressed.emit()
	assert_signal_emitted(ui, "fullscreen_requested")
	ui.set_fullscreen_active(true)
	assert_eq(ui.fullscreen_button.tooltip_text, "Exit fullscreen")
	ui.set_fullscreen_active(false)
	assert_eq(ui.fullscreen_button.tooltip_text, "Enter fullscreen")

	ui.apply_state(RunPhase.MAIN_MENU, 42, "", -1, "")
	await wait_process_frames(1)
	assert_false(ui.owner_label.get_global_rect().intersects(ui.fullscreen_button.get_global_rect()))


func test_native_layout_hides_fullscreen_and_right_aligns_pause() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	ui.set_web_fullscreen_available(false)
	ui.apply_state(RunPhase.MAIN_MENU, 42, "", -1, "")
	await wait_process_frames(1)
	assert_eq(ui.owner_label.get_global_rect().position.y, 31.0)
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	await wait_process_frames(1)
	assert_false(ui.fullscreen_button.visible)
	assert_eq(ui.pause_button.get_global_rect(), Rect2(1202.0, 24.0, 54.0, 54.0))


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


func test_hazard_stack_renders_generic_icon_meters_and_distinguishes_recovery() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_hazard_statuses([
		{
			"cause": &"lava",
			"icon": load("res://assets/ui/hazard_lava.svg"),
			"bar_color": Color(0.94, 0.42, 0.2),
			"level": 0.6,
			"is_active": true,
			"display_order": 20,
		},
		{
			"cause": &"suffocation",
			"icon": load("res://assets/ui/hazard_suffocation.svg"),
			"bar_color": Color(0.35, 0.72, 0.91),
			"level": 0.25,
			"is_active": false,
			"display_order": 10,
		},
	])

	assert_true(ui.hazard_meter_stack.visible)
	assert_eq(ui.hazard_meter_stack.meter_count(), 2)
	var suffocation_row = ui.hazard_meter_stack.rows.get_child(0)
	var lava_row = ui.hazard_meter_stack.rows.get_child(1)
	assert_eq(suffocation_row.meter.value, 25.0)
	assert_eq(suffocation_row.state_indicator.text, "v")
	assert_false(suffocation_row.forward_sweep.visible)
	assert_eq(lava_row.meter.value, 60.0)
	assert_true(lava_row.is_building())
	assert_eq(lava_row.state_indicator.text, ">")
	assert_true(lava_row.forward_sweep.visible)
	assert_eq(lava_row.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_not_null(lava_row.icon_rect.texture)

	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	assert_false(ui.hazard_meter_stack.visible)
	assert_eq(ui.hazard_meter_stack.meter_count(), 2)
	ui.apply_state(RunPhase.GENERATING, 42, "", -1, "")
	assert_eq(ui.hazard_meter_stack.meter_count(), 0)


func test_reward_picker_renders_two_or_three_generic_cards_and_emits_selection() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui
	var choices: Array[RewardChoiceViewData] = [
		RewardChoiceViewData.new("One", "First description", load("res://assets/objects/small_bomb.svg"), "+5"),
		RewardChoiceViewData.new("Two", "Second description", load("res://assets/objects/large_bomb.svg"), "+2"),
		RewardChoiceViewData.new("Three", "Third description", load("res://assets/objects/flag.svg"), "+1"),
	]
	ui.apply_state(RunPhase.REWARD_PICKER, 42, "", -1, "")
	ui.show_reward_choices("Choose a reward", choices)
	await wait_process_frames(1)

	assert_true(ui.overlay_root.visible)
	assert_true(ui.reward_picker_layer.visible)
	assert_false(ui.item_toolbar.visible)
	assert_false(ui.pause_button.visible)
	assert_false(ui.left_touch_pad.visible)
	assert_eq(ui.reward_picker_title.text, "Choose a reward")
	assert_eq(ui.reward_picker_cards.get_child_count(), 3)
	var first := ui.reward_picker_cards.get_child(0) as RewardPickerCard
	assert_eq(first.title_label.text, "One")
	assert_eq(first.description_label.text, "First description")
	assert_eq(first.quantity_label.text, "+5")
	assert_not_null(first.icon_rect.texture)
	assert_true(ui.reward_picker_cards.get_global_rect().encloses(first.get_global_rect()))
	assert_true(first.has_focus())

	watch_signals(ui)
	(ui.reward_picker_cards.get_child(1) as RewardPickerCard).pressed.emit()
	assert_signal_emitted_with_parameters(ui, "reward_selected", [1])
	var key_three := InputEventAction.new()
	key_three.action = &"select_flag"
	key_three.pressed = true
	ui._unhandled_input(key_three)
	assert_signal_emitted_with_parameters(ui, "reward_selected", [2])

	ui.show_reward_choices("Choose an item", choices.slice(0, 2))
	assert_eq(ui.reward_picker_cards.get_child_count(), 2)
	ui.set_reward_picker_enabled(false)
	assert_true((ui.reward_picker_cards.get_child(0) as RewardPickerCard).disabled)


func test_reward_picker_ignores_pause_and_back_without_dismissing() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui
	ui.apply_state(RunPhase.REWARD_PICKER, 42, "", -1, "")
	ui.show_reward_choices("Choose", [RewardChoiceViewData.new("One", "Description", null, "+1")])
	watch_signals(ui)
	var pause_event := InputEventAction.new()
	pause_event.action = InputActions.PAUSE
	pause_event.pressed = true
	ui._unhandled_input(pause_event)
	var back_event := InputEventAction.new()
	back_event.action = InputActions.MENU_BACK
	back_event.pressed = true
	ui._unhandled_input(back_event)

	assert_true(ui.reward_picker_layer.visible)
	assert_signal_not_emitted(ui, "pause_requested")
