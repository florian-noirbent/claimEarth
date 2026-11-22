extends GutTest
## Covers the settings, refused-use, and flag-outcome facts through the whole app: saved
## values reach the audio buses and every run's camera, refusals reach the toolbar and the
## audio sink, and the personal-best fact comes from ScoreController.


const SUFFIXES := ["startup", "live", "defaults", "refused", "record"]
const BUSES: Array[StringName] = [AudioDirector.BUS_MASTER, AudioDirector.BUS_SFX, AudioDirector.BUS_UI, AudioDirector.BUS_MUSIC]

var _cues: Array[StringName] = []


func before_each() -> void:
	_cues = []
	_remove_files()


func after_each() -> void:
	_remove_files()
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index, 0.0)
		AudioServer.set_bus_mute(index, false)


func test_saved_settings_reach_the_buses_sliders_and_every_run_camera() -> void:
	var file := FileAccess.open(_settings_path("startup"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 3,
		"master_volume": 0.8,
		"sfx_volume": 0.5,
		"music_volume": 0.0,
		"screen_shake": 0.5,
	}))
	file.close()
	var app_root := await _app("startup")
	var audio := app_root.audio_director

	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_MASTER), 0.64, 0.001, "The slider share is squared.")
	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_SFX), 0.25, 0.001)
	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_UI), 0.25, 0.001, "Interface sounds follow the sound effects volume.")
	assert_true(audio.is_bus_muted(AudioDirector.BUS_MUSIC))
	assert_false(audio.is_bus_muted(AudioDirector.BUS_SFX))
	assert_almost_eq(app_root.ui.master_volume_row.value(), 0.8, 0.0001)
	assert_almost_eq(app_root.ui.sfx_volume_row.value(), 0.5, 0.0001)
	assert_eq(app_root.ui.music_volume_row.value_label.text, "Off")
	assert_almost_eq(app_root.ui.screen_shake_row.value(), 0.5, 0.0001)

	await _start_run(app_root, "first")
	var first_camera := app_root.get_player().camera
	assert_almost_eq(first_camera.shake_intensity_multiplier, 0.5, 0.0001)

	app_root.transition_to(RunPhase.GENERATING)
	await wait_process_frames(2)
	await _until_playing(app_root)
	var second_camera := app_root.get_player().camera
	assert_ne(second_camera, first_camera, "A restart creates a new session and camera.")
	assert_almost_eq(second_camera.shake_intensity_multiplier, 0.5, 0.0001)


func test_slider_changes_apply_live_persist_and_preview() -> void:
	var app_root := await _app("live")
	var audio := app_root.audio_director
	audio.cue_played.connect(func(id: StringName, _volume_db: float, _pitch_scale: float) -> void:
		_cues.append(id)
	)
	await _start_run(app_root, "live")
	var camera := app_root.get_player().camera
	assert_almost_eq(camera.shake_intensity_multiplier, 1.0, 0.0001)
	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_SFX), 1.0, 0.001)
	_cues = []

	app_root.ui.sfx_volume_row.slider.value = 30.0
	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_SFX), 0.09, 0.001)
	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_UI), 0.09, 0.001)
	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_MASTER), 1.0, 0.001)
	assert_eq(_cues, [&"item_select"] as Array[StringName], "Settling the effects volume previews it.")
	app_root.ui.music_volume_row.slider.value = 55.0
	assert_almost_eq(audio.bus_volume(AudioDirector.BUS_MUSIC), 0.3025, 0.001)
	assert_eq(_cues.size(), 1, "Music has no preview sound.")
	app_root.ui.master_volume_row.slider.value = 0.0
	assert_true(audio.is_bus_muted(AudioDirector.BUS_MASTER))
	app_root.ui.master_volume_row.slider.value = 100.0
	assert_false(audio.is_bus_muted(AudioDirector.BUS_MASTER))

	app_root.ui.screen_shake_row.slider.value = 0.0
	assert_eq(camera.shake_intensity_multiplier, 0.0, "The running camera follows the slider.")
	camera.apply_shake(40.0, camera.global_position + Vector2(60.0, 0.0))
	assert_gt(camera.shake_trauma(), 0.0)
	assert_eq(camera._shake.offset(), Vector2.ZERO, "Zero disables shake completely.")
	assert_eq(camera._shake.rotation(), 0.0)
	assert_eq(camera._shake.offset_envelope(), 0.0)
	app_root.ui.screen_shake_row.slider.value = 200.0
	assert_almost_eq(camera.shake_intensity_multiplier, 2.0, 0.0001)

	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_settings_path("live")))
	assert_eq(int(saved["version"]), AppSettingsData.CURRENT_VERSION)
	assert_almost_eq(float(saved["sfx_volume"]), 0.3, 0.0001)
	assert_almost_eq(float(saved["music_volume"]), 0.55, 0.0001)
	assert_almost_eq(float(saved["master_volume"]), 1.0, 0.0001)
	assert_almost_eq(float(saved["screen_shake"]), 2.0, 0.0001)

	app_root.transition_to(RunPhase.GENERATING)
	await wait_process_frames(2)
	await _until_playing(app_root)
	assert_almost_eq(app_root.get_player().camera.shake_intensity_multiplier, 2.0, 0.0001)


func test_test_mode_without_a_settings_file_keeps_the_defaults() -> void:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test(_save_path("defaults"))
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	for bus in BUSES:
		assert_almost_eq(app_root.audio_director.bus_volume(bus), 1.0, 0.001)
		assert_false(app_root.audio_director.is_bus_muted(bus))
	assert_almost_eq(app_root.ui.screen_shake_row.value(), 1.0, 0.0001)
	assert_almost_eq(app_root.ui.master_volume_row.value(), 1.0, 0.0001)


func test_refused_use_reaches_the_toolbar_and_a_rate_limited_sound() -> void:
	var motion_was_enabled := UiMotion.enabled
	UiMotion.enabled = true
	var app_root := await _app("refused")
	app_root.audio_director.cue_played.connect(func(id: StringName, _volume_db: float, _pitch_scale: float) -> void:
		_cues.append(id)
	)
	await _start_run(app_root, "refused")
	await wait_process_frames(2)
	var aim := app_root.get_player().global_position + Vector2(80.0, -40.0)
	var slot := app_root.ui.item_toolbar_content.get_child(0) as ItemToolbarSlot
	assert_gt(slot.cooldown_fraction(), 0.0, "The run-start lock shows on the toolbar.")
	watch_signals(app_root.item_controller)
	_cues = []

	app_root._on_throw_requested(aim)
	app_root._on_throw_requested(aim)

	assert_signal_emit_count(app_root.item_controller, "use_refused", 2)
	assert_eq(get_signal_parameters(app_root.item_controller, "use_refused"), [ItemUseRefusal.START_LOCK, 0])
	assert_eq(_cues, [&"use_denied"] as Array[StringName], "Rapid refusals play one quiet sound.")
	assert_true(UiMotion.is_moving(slot), "The selected slot shakes.")
	assert_eq(app_root.active_projectile_count(), 0)

	await wait_seconds(RunItemController.RUN_START_LOCK_SECONDS + 0.2)
	assert_eq(slot.cooldown_fraction(), 0.0)
	assert_false(slot.cooldown_wipe.visible)
	_cues = []
	app_root._on_throw_requested(aim)
	assert_eq(app_root.active_projectile_count(), 1)
	assert_false(_cues.has(&"use_denied"))
	UiMotion.enabled = motion_was_enabled


func test_personal_best_fact_comes_from_the_score_controller() -> void:
	var app_root := await _app("record")
	assert_true(app_root.score_controller.is_new_personal_best(0), "Any first flag is a record.")

	await _start_run(app_root, "record-1")
	_land_flag(app_root, 60)
	assert_true(app_root.ui.name_entry_record_label.visible)
	assert_eq(app_root.ui.name_entry_title.text, "Plant Your Flag")
	app_root.ui.player_name_input.text = "Florian"
	app_root.ui.confirm_score_button.pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.RESULT)
	assert_true(app_root.ui.result_record_label.visible)
	assert_eq(app_root.score_controller.personal_best_depth, 60)
	assert_false(app_root.score_controller.is_new_personal_best(60), "Equalling the best is not a new best.")
	assert_true(app_root.score_controller.is_new_personal_best(61))

	# The HUD never showed a depth this run, so only ScoreController can know 40 is no record.
	app_root.ui.restart_button.pressed.emit()
	await _until_playing(app_root)
	_land_flag(app_root, 40)
	assert_false(app_root.ui.name_entry_record_label.visible)
	app_root.ui.confirm_score_button.pressed.emit()
	assert_false(app_root.ui.result_record_label.visible)
	assert_eq(app_root.score_controller.personal_best_depth, 60)

	app_root.ui.restart_button.pressed.emit()
	await _until_playing(app_root)
	_land_flag(app_root, 61)
	assert_true(app_root.ui.name_entry_record_label.visible)


func _app(suffix: String) -> AppRoot:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test(_save_path(suffix))
	app_root.configure_settings_path_for_test(_settings_path(suffix))
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	return app_root


func _start_run(app_root: AppRoot, seed_text: String) -> void:
	app_root.start_run_for_test(SeedUtils.seed_from_text("settings-facts-%s" % seed_text))
	await _until_playing(app_root)


func _until_playing(app_root: AppRoot) -> void:
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 3.0)


func _land_flag(app_root: AppRoot, row: int) -> void:
	var landing := HexMetrics.center_for_offset(5, row, app_root.world_presenter.hex_radius)
	app_root.item_controller.resolve_flag_landing(null, landing, null, &"impact")


func _save_path(suffix: String) -> String:
	return "user://gut_settings_facts_%s.json" % suffix


func _settings_path(suffix: String) -> String:
	return "user://gut_settings_facts_%s_settings.json" % suffix


func _remove_files() -> void:
	for suffix in SUFFIXES:
		for path in [_save_path(suffix), _settings_path(suffix)]:
			for candidate in [path, "%s.tmp" % path]:
				if FileAccess.file_exists(candidate):
					DirAccess.remove_absolute(candidate)
