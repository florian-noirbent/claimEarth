extends GutTest
## Covers the cosmetic layer of AppUiController with motion forced on: logical state stays
## immediate and every control returns to rest after rapid state changes.


const SETTLE_SECONDS := 0.9

var _motion_was_enabled := false


func before_each() -> void:
	_motion_was_enabled = UiMotion.enabled
	UiMotion.enabled = true


func after_each() -> void:
	UiMotion.enabled = _motion_was_enabled


func test_rapid_state_changes_keep_logic_immediate_and_settle_every_control() -> void:
	var ui := await _create_ui()
	var states: Array[StringName] = [
		RunPhase.GENERATING,
		RunPhase.PLAYING,
		RunPhase.PAUSED,
		RunPhase.PLAYING,
		RunPhase.REWARD_PICKER,
		RunPhase.FLAG_IN_FLIGHT,
		RunPhase.NAME_ENTRY,
		RunPhase.SUBMITTING,
		RunPhase.RESULT,
		RunPhase.GENERATING,
		RunPhase.PLAYING,
		RunPhase.DEATH,
		RunPhase.MAIN_MENU,
		RunPhase.LEADERBOARD,
		RunPhase.MAIN_MENU,
	]
	for round_index in 2:
		for state in states:
			ui.apply_state(state, 42, "", 73, "Miner")
			if state == RunPhase.PLAYING:
				ui.show_run_status(12 + round_index, 20, false, _item_status([10, 2, 1], 0))
			if round_index == 1:
				await wait_process_frames(1)

	assert_true(ui.menu_panel.visible)
	assert_true(ui.title_image.visible)
	assert_false(ui.overlay_root.visible)
	assert_false(ui.modal_dim.visible, "The dim never lingers over the menu.")
	assert_false(ui.hud_toast.visible)
	assert_false(ui.generation_progress.visible)

	await wait_seconds(SETTLE_SECONDS)
	assert_false(ui.transition_curtain.visible)
	assert_eq(_controls_off_rest(ui), PackedStringArray())


func test_modal_dim_follows_modal_states_and_page_changes_keep_logic_immediate() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	assert_false(ui.modal_dim.visible)

	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	assert_true(ui.modal_dim.visible)
	assert_true(ui.pause_panel.visible)
	assert_eq(ui.modal_dim.color, UiMotion.config().modal_dim_color)
	assert_eq(ui.modal_dim.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	ui.pause_help_button.pressed.emit()
	assert_true(ui.help_panel.visible)
	assert_true(ui.modal_dim.visible, "The dim stays behind pages opened from pause.")
	ui.help_back_button.pressed.emit()
	assert_true(ui.pause_panel.visible)

	ui.apply_state(RunPhase.DEATH, 42, "", -1, "")
	assert_eq(ui.modal_dim.color, UiMotion.config().death_dim_color)
	assert_eq(ui.result_title.get_theme_color(&"font_color"), UiMotion.config().danger_color)

	ui.apply_state(RunPhase.GENERATING, 42, "", -1, "")
	assert_false(ui.modal_dim.visible)
	assert_true(ui.generation_progress.visible)
	ui.show_generation_progress(0.5, "Settling terrain")
	assert_eq(ui.status_label.text, "Settling terrain 50%")
	await wait_seconds(SETTLE_SECONDS)
	assert_almost_eq(ui.generation_progress.value, 0.5, 0.001)
	assert_almost_eq(ui.menu_panel.modulate.a, UiMotion.config().generating_menu_alpha, 0.001)

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	await wait_process_frames(2)
	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	await wait_seconds(SETTLE_SECONDS)
	assert_true(ui.modal_dim.visible, "Pausing again during the fade-out keeps the dim.")
	assert_eq(ui.modal_dim.modulate, Color.WHITE)
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	await wait_seconds(SETTLE_SECONDS)
	assert_false(ui.modal_dim.visible, "The dim fades out and hides after resuming.")
	assert_eq(ui.menu_panel.modulate, Color.WHITE)


func test_toolbar_keeps_slots_and_tells_gained_from_used_items() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_run_status(3, -1, false, _item_status([10, 2, 1], 0))
	var small_bomb_slot := ui.item_toolbar_content.get_child(0) as ItemToolbarSlot
	var flag_slot := ui.item_toolbar_content.get_child(2) as ItemToolbarSlot
	assert_true(small_bomb_slot.is_selected())
	await wait_seconds(SETTLE_SECONDS)

	# A used item squashes its icon; the slot itself stays put.
	ui.show_run_status(3, -1, false, _item_status([9, 2, 1], 0))
	assert_eq(small_bomb_slot.count_label.text, "x9")
	assert_true(UiMotion.is_moving(small_bomb_slot.icon_rect))
	assert_false(UiMotion.is_moving(small_bomb_slot))
	await wait_seconds(SETTLE_SECONDS)

	# A gained item pulses; a newly collected item gets its own slot without rebuilding others.
	var grown := _item_status([14, 2, 1], 0)
	(grown["items"] as Array).append({"name": "Shovel", "icon": null, "count": 120.0, "count_text": "120", "selected": false, "shortcut": 4, "catalog_index": 4})
	ui.show_run_status(3, -1, false, grown)
	assert_eq(ui.item_toolbar_content.get_child_count(), 4)
	assert_same(ui.item_toolbar_content.get_child(0), small_bomb_slot)
	assert_same(ui.item_toolbar_content.get_child(2), flag_slot)
	assert_gt(small_bomb_slot.modulate.r, 1.0, "Gained items flash.")
	var shovel_slot := ui.item_toolbar_content.get_child(3) as ItemToolbarSlot
	assert_gt(shovel_slot.modulate.r, 1.0, "A newly collected item flashes in.")
	watch_signals(ui)
	shovel_slot.pressed.emit()
	assert_signal_emitted_with_parameters(ui, "item_selected", [4])

	# Selecting an empty item shakes it and dims its icon.
	var emptied := _item_status([14, 0, 1], 1)
	ui.show_run_status(3, -1, false, emptied)
	var large_bomb_slot := ui.item_toolbar_content.get_child(1) as ItemToolbarSlot
	assert_eq(ui.item_toolbar_content.get_child_count(), 3)
	assert_ne(large_bomb_slot.rotation, 0.0)
	assert_eq(UiMotion.rest_modulate(large_bomb_slot.icon_rect), UiMotion.config().item_empty_modulate)

	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_controls_off_rest(ui), PackedStringArray())

	# A new run deals a fresh toolbar instead of pulsing the refilled counts.
	ui.apply_state(RunPhase.GENERATING, 42, "", -1, "")
	assert_eq(ui.item_toolbar_content.get_child_count(), 0)


func test_depth_milestones_and_passing_the_personal_best_are_celebrated_once() -> void:
	var ui := await _create_ui()
	var interval := UiMotion.config().depth_milestone_interval
	var record_color := UiMotion.config().record_color
	var normal_color := ui.play_status_label.get_theme_color(&"font_color")
	ui.apply_state(RunPhase.GENERATING, 42, "", -1, "")
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	var best := interval + 10

	ui.show_run_status(0, best, false, _item_status([10, 2, 1], 0))
	ui.show_run_status(interval - 1, best, false, _item_status([10, 2, 1], 0))
	assert_false(ui.hud_toast.visible)
	assert_eq(ui.play_status_label.text, "Depth %d  |  PB:%d" % [interval - 1, best])

	ui.show_run_status(interval, best, false, _item_status([10, 2, 1], 0))
	assert_true(ui.hud_toast.visible)
	assert_eq(ui.hud_toast.text, "Depth %d" % interval)
	assert_eq(ui.play_status_label.get_theme_color(&"font_color"), normal_color)

	ui.show_run_status(best + 1, best, false, _item_status([10, 2, 1], 0))
	assert_eq(ui.hud_toast.text, "Deeper than your best!")
	assert_eq(ui.play_status_label.get_theme_color(&"font_color"), record_color)

	# Climbing back above the best and passing it again does not repeat the celebration.
	ui.show_run_status(best - 1, best, false, _item_status([10, 2, 1], 0))
	assert_eq(ui.play_status_label.get_theme_color(&"font_color"), normal_color)
	ui.hud_toast.text = ""
	ui.show_run_status(best + 2, best, false, _item_status([10, 2, 1], 0))
	assert_eq(ui.hud_toast.text, "")
	assert_eq(ui.play_status_label.get_theme_color(&"font_color"), record_color)

	ui.apply_state(RunPhase.PAUSED, 42, "", -1, "")
	assert_false(ui.hud_toast.visible, "Toasts never linger outside active play.")

	# Without a saved best there is nothing to beat, only milestones.
	ui.apply_state(RunPhase.GENERATING, 42, "", -1, "")
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_run_status(0, -1, false, _item_status([10, 2, 1], 0))
	ui.show_run_status(5, -1, false, _item_status([10, 2, 1], 0))
	assert_false(ui.hud_toast.visible)
	assert_eq(ui.play_status_label.get_theme_color(&"font_color"), normal_color)
	await wait_seconds(UiMotion.config().toast_hold_duration + SETTLE_SECONDS)
	assert_false(ui.hud_toast.visible)


func test_record_labels_mark_a_new_personal_best_only_after_confirmation() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_run_status(60, 50, false, _item_status([10, 2, 1], 0))

	ui.show_flag_outcome(false, false)
	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 40, "Miner")
	assert_false(ui.name_entry_record_label.visible, "A shallower flag is not a record.")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(ui.name_entry_status.text, "Depth: 40")

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 73, "Miner")
	assert_false(ui.name_entry_record_label.visible, "Depth alone never marks a record; the fact from AppRoot does.")
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_flag_outcome(false, true)
	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 73, "Miner")
	assert_true(ui.name_entry_record_label.visible)
	ui.show_name_error("Enter a name.")
	assert_eq(ui.name_entry_status.text, "Enter a name.", "An error replaces a running count-up.")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(ui.name_entry_status.text, "Enter a name.")

	# Leaving name entry without confirming shows no record on the result panel.
	ui.apply_state(RunPhase.RESULT, 42, "", 73, "Miner")
	assert_false(ui.result_record_label.visible)
	assert_false(ui.name_entry_record_label.visible)

	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_flag_outcome(false, true)
	ui.apply_state(RunPhase.NAME_ENTRY, 42, "", 73, "Miner")
	ui.score_confirmed.connect(func(_player_name: String) -> void:
		ui.apply_state(RunPhase.SUBMITTING, 42, "", 73, "Miner")
	)
	ui.confirm_score_button.pressed.emit()
	assert_true(ui.result_record_label.visible)
	ui.apply_state(RunPhase.RESULT, 42, "", 73, "Miner")
	assert_true(ui.result_record_label.visible)
	ui.apply_state(RunPhase.MAIN_MENU, 42, "", -1, "")
	assert_false(ui.result_record_label.visible)


func test_chosen_reward_card_confirms_outside_the_picker_and_frees_itself() -> void:
	var ui := await _create_ui()
	var choices: Array[RewardChoiceViewData] = [
		RewardChoiceViewData.new("One", "First", null, "+5"),
		RewardChoiceViewData.new("Two", "Second", null, "+2"),
	]
	ui.apply_state(RunPhase.REWARD_PICKER, 42, "", -1, "")
	ui.show_reward_choices("Choose", choices)
	await wait_process_frames(2)
	var chosen := ui.reward_picker_cards.get_child(1) as RewardPickerCard

	# A rejected choice leaves the picker untouched.
	chosen.pressed.emit()
	assert_eq(ui.reward_picker_cards.get_child_count(), 2)
	assert_eq(ui.effects_layer.get_child_count(), 0)

	ui.reward_selected.connect(func(_index: int) -> void:
		ui.set_reward_picker_enabled(false)
		ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	)
	chosen.pressed.emit()
	assert_false(ui.reward_picker_layer.visible)
	assert_eq(ui.reward_picker_cards.get_child_count(), 0)
	assert_eq(ui.effects_layer.get_child_count(), 2)
	assert_eq(chosen.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(chosen.disabled)
	assert_eq(chosen.modulate, Color.WHITE, "The chosen card is not left greyed out.")

	await wait_seconds(SETTLE_SECONDS)
	assert_eq(ui.effects_layer.get_child_count(), 0)
	assert_false(is_instance_valid(chosen))

	# The next picker starts from fresh, enabled cards.
	ui.apply_state(RunPhase.REWARD_PICKER, 42, "", -1, "")
	ui.show_reward_choices("Choose", choices)
	assert_eq(ui.reward_picker_cards.get_child_count(), 2)
	assert_false((ui.reward_picker_cards.get_child(0) as RewardPickerCard).disabled)


func test_hazard_meters_fade_out_and_a_returning_hazard_reuses_its_meter() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	ui.show_hazard_statuses([_hazard(0.9, true)])
	var row := ui.hazard_meter_stack.rows.get_child(0) as HazardMeterRow
	assert_eq(row.meter.value, 90.0, "The level is exact from the first frame.")
	assert_gt(row.danger(), 0.5)
	await wait_seconds(SETTLE_SECONDS)
	assert_ne(row.rotation, 0.0, "A nearly full building meter shakes.")

	ui.show_hazard_statuses([_hazard(0.2, false)])
	assert_eq(row.danger(), 0.0)
	assert_eq(row.rotation, 0.0)
	assert_eq(row.scale, Vector2.ONE)

	ui.show_hazard_statuses([])
	assert_eq(ui.hazard_meter_stack.meter_count(), 0)
	assert_true(is_instance_valid(row))
	await wait_process_frames(2)
	ui.show_hazard_statuses([_hazard(0.3, true)])
	assert_eq(ui.hazard_meter_stack.meter_count(), 1)
	assert_same(ui.hazard_meter_stack.rows.get_child(0), row)
	assert_eq(ui.hazard_meter_stack.rows.get_child_count(), 1)
	assert_eq(row.modulate, Color.WHITE)

	ui.show_hazard_statuses([])
	await wait_seconds(SETTLE_SECONDS)
	assert_false(is_instance_valid(row))
	assert_eq(ui.hazard_meter_stack.rows.get_child_count(), 0)


func test_perk_stack_pops_only_newly_gained_perks() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.PLAYING, 42, "", -1, "")
	var first := PerkViewData.new(&"jelly", "Jelly", "Bouncy", null)
	var second := PerkViewData.new(&"acrobat", "Acrobat", "Longer rope", null)
	ui.show_perks([first])
	await wait_seconds(SETTLE_SECONDS)

	ui.show_perks([first, second])
	assert_eq(ui.perk_stack.perk_count(), 2)
	var kept := ui.perk_stack.badges.get_child(0) as Control
	var gained := ui.perk_stack.badges.get_child(1) as Control
	assert_false(UiMotion.is_moving(kept))
	assert_true(UiMotion.is_moving(gained))
	assert_eq(kept.modulate, Color.WHITE)

	ui.clear_perks()
	assert_eq(ui.perk_stack.perk_count(), 0)
	await wait_process_frames(2)


func test_statistics_page_counts_up_to_exact_values() -> void:
	var ui := await _create_ui()
	ui.apply_state(RunPhase.MAIN_MENU, 42, "", -1, "")
	var tiles: Array[StatisticsEntryViewData] = [
		StatisticsEntryViewData.new(null, "Flags planted", "37"),
		StatisticsEntryViewData.new(null, "Time played", "1h 20m"),
	]
	var bars: Array[StatisticsEntryViewData] = [
		StatisticsEntryViewData.new(null, "Cooked", "12", "60%", "", 0.6),
	]
	var sections: Array[StatisticsSectionViewData] = [
		StatisticsSectionViewData.new("Overview", StatisticsSectionViewData.Layout.TILES, tiles),
		StatisticsSectionViewData.new("Deaths", StatisticsSectionViewData.Layout.BARS, bars),
	]
	ui.show_statistics(StatisticsViewData.new(sections))
	var tile := ui.statistics_page.section_at(0).entry_control(0) as StatisticsStatTile
	var text_tile := ui.statistics_page.section_at(0).entry_control(1) as StatisticsStatTile
	var bar_row := ui.statistics_page.section_at(1).entry_control(0) as StatisticsBarRow
	assert_eq(tile.value_label.text, "0")
	assert_eq(text_tile.value_label.text, "1h 20m", "Only whole numbers count up.")
	assert_eq(bar_row.bar.value, 0.0)

	await wait_seconds(UiMotion.config().count_up_duration + UiMotion.config().bar_grow_duration + 0.4)
	assert_eq(tile.value_label.text, "37")
	assert_eq(bar_row.value_label.text, "12")
	assert_almost_eq(bar_row.bar.value, 0.6, 0.001)
	assert_eq(_controls_off_rest(ui), PackedStringArray())

	# Closing mid-animation and reopening shows exact values again.
	ui.show_statistics(StatisticsViewData.new(sections))
	ui.statistics_page.back_button.pressed.emit()
	assert_false(ui.statistics_page.visible)
	assert_true(ui.menu_panel.visible)


func _create_ui() -> AppUiController:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	return app_root.ui


func _item_status(counts: Array, selected_index: int) -> Dictionary:
	var names := ["Small Bomb", "Large Bomb", "Flag"]
	var items: Array[Dictionary] = []
	for index in counts.size():
		items.append({
			"name": names[index],
			"icon": null,
			"count": float(counts[index]),
			"count_text": str(counts[index]),
			"selected": index == selected_index,
			"shortcut": index + 1,
			"catalog_index": index,
		})
	return {"flag_in_flight": false, "items": items}


func _hazard(level: float, active: bool) -> Dictionary:
	return {
		"cause": &"cooked",
		"icon": null,
		"bar_color": Color(0.94, 0.42, 0.2),
		"level": level,
		"is_active": active,
		"display_order": 20,
	}


## Lists every control below the UI layer that is not at its resting transform or opacity.
func _controls_off_rest(ui: AppUiController) -> PackedStringArray:
	var off_rest := PackedStringArray()
	for node in ui.find_children("*", "Control", true, false):
		var control := node as Control
		var hovered_button := control is BaseButton and (control.has_focus() or (control as BaseButton).is_hovered())
		if not hovered_button and not control.scale.is_equal_approx(Vector2.ONE):
			off_rest.append("%s scale %s" % [ui.get_path_to(control), control.scale])
		if not is_zero_approx(control.rotation):
			off_rest.append("%s rotation %s" % [ui.get_path_to(control), control.rotation])
		if control.modulate != UiMotion.rest_modulate(control) or UiMotion.is_moving(control):
			off_rest.append("%s still animating" % ui.get_path_to(control))
		if control.modulate.a <= 0.0:
			off_rest.append("%s is transparent" % ui.get_path_to(control))
	return off_rest
