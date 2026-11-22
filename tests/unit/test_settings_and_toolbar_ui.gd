extends GutTest
## Covers the Settings slider rows, the toolbar cooldown cover and refusal reaction, and
## the victory presentation of AppUiController.


const SETTINGS_PATH := "user://gut_settings_and_toolbar_ui.json"

var _motion_was_enabled := false


func before_each() -> void:
	_motion_was_enabled = UiMotion.enabled
	_remove_settings()


func after_each() -> void:
	UiMotion.enabled = _motion_was_enabled
	_remove_settings()


func test_slider_row_reports_shares_and_commits_changes_made_without_a_drag() -> void:
	var row := (load("res://scenes/ui/settings_slider_row.tscn") as PackedScene).instantiate() as SettingsSliderRow
	row.title = "Screen Shake"
	row.max_percent = 200
	row.step_percent = 10
	add_child_autofree(row)
	watch_signals(row)

	assert_eq(row.title_label.text, "Screen Shake")
	assert_eq(row.slider.max_value, 200.0)
	assert_ne(row.slider.focus_mode, Control.FOCUS_NONE, "Keyboard and gamepad focus reach the slider.")
	row.set_value_no_signal(1.5)
	assert_eq(row.value_label.text, "150%")
	assert_signal_not_emitted(row, "value_changed")

	row.slider.value = 44.0
	assert_almost_eq(row.value(), 0.4, 0.0001, "Values snap to the step.")
	assert_signal_emitted_with_parameters(row, "value_changed", [0.4])
	assert_signal_emit_count(row, "value_committed", 1)

	row.slider.drag_started.emit()
	row.slider.value = 0.0
	assert_eq(row.value_label.text, "Off")
	assert_signal_emit_count(row, "value_committed", 1, "A drag commits when it ends.")
	row.slider.drag_ended.emit(true)
	assert_signal_emit_count(row, "value_committed", 2)
	assert_eq(get_signal_parameters(row, "value_committed"), [0.0])


func test_settings_sliders_emit_typed_intents_and_show_applied_values() -> void:
	var ui := await _create_ui()
	watch_signals(ui)

	ui.set_volume(AppSettingsData.VOLUME_MUSIC, 0.35)
	ui.set_screen_shake(1.6)
	assert_eq(ui.music_volume_row.value_label.text, "35%")
	assert_eq(ui.screen_shake_row.value_label.text, "160%")
	assert_signal_not_emitted(ui, "volume_changed")
	assert_signal_not_emitted(ui, "screen_shake_changed")

	ui.sfx_volume_row.slider.value = 60.0
	assert_signal_emitted_with_parameters(ui, "volume_changed", [AppSettingsData.VOLUME_SFX, 0.6])
	assert_signal_emitted_with_parameters(ui, "volume_preview_requested", [AppSettingsData.VOLUME_SFX])
	ui.master_volume_row.slider.value = 80.0
	assert_signal_emitted_with_parameters(ui, "volume_changed", [AppSettingsData.VOLUME_MASTER, 0.8])
	ui.screen_shake_row.slider.value = 0.0
	assert_signal_emitted_with_parameters(ui, "screen_shake_changed", [0.0])


func test_settings_panel_fits_the_screen_and_replaces_the_title_art() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.MAIN_MENU, 42, "", -1, "")

	ui.menu_settings_button.pressed.emit()
	await wait_process_frames(2)

	var screen := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	assert_true(screen.encloses(ui.settings_panel.get_global_rect()), "The panel fits a 1280x720 screen: %s" % ui.settings_panel.get_global_rect())
	assert_false(ui.title_image.visible)
	for row: SettingsSliderRow in [ui.master_volume_row, ui.sfx_volume_row, ui.music_volume_row, ui.screen_shake_row]:
		assert_true(row.is_visible_in_tree())
		assert_true(ui.settings_panel.get_global_rect().encloses(row.get_global_rect()))
		assert_gte(row.slider.size.y, 40.0, "Sliders stay tall enough for touch.")
	ui.settings_back_button.pressed.emit()
	assert_true(ui.title_image.visible)
	assert_true(ui.menu_panel.visible)


func test_toolbar_slots_show_the_cooldown_share_and_the_untimed_lock() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")

	ui.show_run_status(3, -1, false, _item_status(0.5, false))
	var slot := ui.item_toolbar_content.get_child(0) as ItemToolbarSlot
	assert_true(slot.cooldown_wipe.visible)
	assert_almost_eq(slot.cooldown_wipe.anchor_top, 0.5, 0.0001, "Half of the cover is left.")
	assert_true(slot.cooldown_edge.visible)
	assert_eq(slot.cooldown_wipe.color, UiMotion.config().item_cooldown_color)

	ui.show_run_status(3, -1, false, _item_status(0.1, false))
	assert_almost_eq(slot.cooldown_wipe.anchor_top, 0.9, 0.0001)
	ui.show_run_status(3, -1, false, _item_status(0.0, false))
	assert_false(slot.cooldown_wipe.visible, "A ready slot is uncovered.")
	assert_eq(slot.cooldown_fraction(), 0.0)

	ui.show_run_status(3, -1, false, _item_status(0.0, true))
	assert_true(slot.is_locked())
	assert_true(slot.cooldown_wipe.visible)
	assert_eq(slot.cooldown_wipe.anchor_top, 0.0, "An untimed lock covers the whole slot.")
	assert_false(slot.cooldown_edge.visible)
	assert_eq(slot.cooldown_wipe.color, UiMotion.config().item_locked_color)
	assert_eq(slot.cooldown_wipe.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_ready_pop_and_refusal_shake_play_and_settle() -> void:
	UiMotion.enabled = true
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_run_status(3, -1, false, _item_status(0.4, false))
	await wait_seconds(0.5)
	var first := ui.item_toolbar_content.get_child(0) as ItemToolbarSlot
	var second := ui.item_toolbar_content.get_child(1) as ItemToolbarSlot

	ui.show_run_status(3, -1, false, _item_status(0.0, false))
	assert_true(UiMotion.is_moving(first.icon_rect), "The icon pops when the lock ends.")

	ui.show_use_refused(1, ItemUseRefusal.EMPTY)
	assert_true(UiMotion.is_moving(second), "The refused slot shakes.")
	assert_false(is_zero_approx(second.rotation))
	assert_false(UiMotion.is_moving(first), "Only the refused slot reacts.")
	var rotation_before := second.rotation
	ui.show_use_refused(1, ItemUseRefusal.EMPTY)
	assert_eq(second.rotation, rotation_before, "A burst of refusals reads as one shake.")
	ui.show_use_refused(99, ItemUseRefusal.EMPTY)
	ui.show_use_refused(-1, ItemUseRefusal.START_LOCK)

	await wait_seconds(0.6)
	for slot: ItemToolbarSlot in [first, second]:
		assert_true(slot.scale.is_equal_approx(Vector2.ONE))
		assert_true(is_zero_approx(slot.rotation))
		assert_eq(slot.modulate, Color.WHITE)
		assert_true(slot.icon_rect.scale.is_equal_approx(Vector2.ONE))


func test_victory_fact_changes_titles_lines_and_dim() -> void:
	var ui := await _create_ui()
	var settings := UiMotion.config()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")

	ui.show_flag_outcome(true, false)
	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 500, "Miner")
	assert_eq(ui.name_entry_title.text, "Victory!")
	assert_true(ui.name_entry_victory_label.visible)
	assert_false(ui.name_entry_record_label.visible)
	assert_eq(ui.name_entry_title.get_theme_color(&"font_color"), settings.victory_color)
	assert_eq(ui.name_entry_title.get_theme_font_size(&"font_size"), settings.victory_title_font_size)
	assert_eq(ui.modal_dim.color, settings.victory_dim_color)

	ui.apply_state(RunPhase.RESULT, 42, "", 500, "Miner")
	assert_eq(ui.result_title.text, "Victory!")
	assert_true(ui.result_victory_label.visible)
	assert_false(ui.name_entry_victory_label.visible)
	assert_eq(ui.result_title.get_theme_color(&"font_color"), settings.victory_color)
	assert_true(ui.result_panel.get_global_rect().size.y <= 720.0)

	# The next run's ordinary flag and a lost run show no trace of the victory.
	ui.apply_state(RunPhase.GENERATING, 42, "", -1, "")
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_flag_outcome(false, false)
	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 30, "Miner")
	assert_eq(ui.name_entry_title.text, "Plant Your Flag")
	assert_false(ui.name_entry_victory_label.visible)
	assert_ne(ui.name_entry_title.get_theme_color(&"font_color"), settings.victory_color)
	assert_eq(ui.modal_dim.color, settings.modal_dim_color)
	ui.apply_state(RunPhase.RESULT, 42, "", 30, "Miner")
	assert_eq(ui.result_title.text, "Flag Planted")
	assert_false(ui.result_victory_label.visible)
	ui.apply_state(RunPhase.DEATH, 42, "", -1, "")
	assert_eq(ui.result_title.text, "Run Lost")
	assert_eq(ui.result_title.get_theme_color(&"font_color"), settings.danger_color)
	assert_false(ui.result_victory_label.visible)


func test_victory_reveal_settles_at_rest() -> void:
	UiMotion.enabled = true
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_flag_outcome(true, true)

	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 500, "Miner")
	assert_true(UiMotion.is_moving(ui.name_entry_title), "The victory title lands with a punch.")
	ui.apply_state(RunPhase.RESULT, 42, "", 500, "Miner")
	assert_true(UiMotion.is_moving(ui.result_title))

	await wait_seconds(1.0)
	for control: Control in [ui.name_entry_title, ui.result_title, ui.result_victory_label, ui.result_panel]:
		assert_true(control.scale.is_equal_approx(Vector2.ONE))
		assert_eq(control.modulate, Color.WHITE)


func test_outcome_beat_keeps_readouts_and_drops_controls() -> void:
	var ui := await _create_ui()
	ui.set_phone_controls_enabled(true)
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	assert_true(ui.left_touch_pad.visible)

	ui.apply_state(RunPhase.OUTCOME_BEAT, 42, "", -1, "")

	assert_true(ui.overlay_root.visible)
	assert_true(ui.playing_panel.visible)
	assert_true(ui.hazard_meter_stack.visible)
	assert_false(ui.item_toolbar.visible)
	assert_false(ui.pause_button.visible)
	assert_false(ui.left_touch_pad.visible)
	assert_false(ui.right_touch_pad.visible)
	assert_false(ui.result_panel.visible)
	assert_false(ui.modal_dim.visible)
	assert_false(ui.menu_root.visible)


func _create_ui() -> AppUiController:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_settings_path_for_test(SETTINGS_PATH)
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	# These tests drive the UI alone: detach it so slider intents never reach settings or audio.
	for signal_name: StringName in [&"volume_changed", &"volume_preview_requested", &"screen_shake_changed"]:
		for connection: Dictionary in app_root.ui.get_signal_connection_list(signal_name):
			app_root.ui.disconnect(signal_name, connection["callable"])
	return app_root.ui


func _item_status(cooldown_fraction: float, locked: bool) -> Dictionary:
	var names := ["Small Bomb", "Large Bomb", "Flag"]
	var items: Array[Dictionary] = []
	for index in names.size():
		items.append({
			"name": names[index],
			"icon": null,
			"count": 2.0,
			"count_text": "2",
			"selected": index == 0,
			"shortcut": index + 1,
			"catalog_index": index,
			"cooldown_fraction": cooldown_fraction,
			"locked": locked,
		})
	return {"flag_in_flight": locked, "items": items}


func _remove_settings() -> void:
	for path in [SETTINGS_PATH, "%s.tmp" % SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
