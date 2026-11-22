extends GutTest

const SAVE_PATH := "user://gut_audio_flow.json"

var _cues: Array[StringName] = []


func before_each() -> void:
	_cues = []
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func test_a_run_plays_synthesized_sounds_through_the_voice_pools() -> void:
	var app_root := await _started_app()
	var director := app_root.audio_director
	var player := app_root.get_player()
	var here := player.global_position

	assert_eq(_cues.count(&"run_start"), 1)
	assert_gt(director.get_node("SFXVoices").get_child_count(), 0)
	assert_gt(director.get_node("UIVoices").get_child_count(), 0)

	_cues = []
	for step in range(12):
		player.landed.emit(here, 150.0, 0.08)
	assert_eq(_cues, [] as Array[StringName], "running over hex steps is silent")

	player.jumped.emit(here, false)
	player.landed.emit(here, 420.0, 0.6)
	app_root.ui.ui_feedback_requested.emit(AppUiController.UI_FEEDBACK_PRESS)
	assert_eq(_cues, [&"jump", &"land_soft", &"ui_press"] as Array[StringName])

	_cues = []
	var landing := HexMetrics.center_for_offset(5, 20, app_root.world_presenter.hex_radius)
	app_root.item_controller.resolve_flag_landing(null, landing, null, &"lava")
	assert_eq(_cues, [&"flag_destroyed", &"game_over"] as Array[StringName])

	for id: StringName in [&"run_start", &"jump", &"land_soft", &"ui_press", &"flag_destroyed", &"game_over"]:
		assert_true(director.sound_bank().is_rendered(id), "%s was rendered for playback" % id)
	assert_lte(director.active_voice_count(AudioDirector.BUS_SFX), director.tuning.sfx_voice_count)


func _started_app() -> AppRoot:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test(SAVE_PATH)
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	app_root.audio_director.cue_played.connect(func(id: StringName, _volume_db: float, _pitch_scale: float) -> void:
		_cues.append(id)
	)
	app_root.start_run_for_test(SeedUtils.seed_from_text("audio-flow"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	return app_root
