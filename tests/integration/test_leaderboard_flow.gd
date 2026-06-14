extends GutTest


const FakeLeaderboardServiceScript = preload("res://src/leaderboard/fake_leaderboard_service.gd")
const LeaderboardEntryScript = preload("res://src/leaderboard/leaderboard_entry.gd")


func before_each() -> void:
	for suffix in ["ok", "fail"]:
		var path := "user://gut_leaderboard_%s.json" % suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_leaderboard_panel_shows_entries_and_updates_owner_label() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	var service = FakeLeaderboardServiceScript.new()
	var top_entry = LeaderboardEntryScript.new()
	top_entry.rank = 1
	top_entry.player_name = "Dana"
	top_entry.score_depth = 123
	service.top_entries = [top_entry]
	app_root.configure_save_path_for_test("user://gut_leaderboard_ok.json")
	app_root.configure_leaderboard_service_for_test(service)
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.LEADERBOARD)

	assert_string_contains(app_root.owner_label.text, "Dana")
	assert_string_contains(app_root.leaderboard_rows.text, "123")


func test_failed_submission_is_saved_as_pending_and_result_still_opens() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	var service = FakeLeaderboardServiceScript.new()
	service.submit_error = "Offline"
	app_root.configure_save_path_for_test("user://gut_leaderboard_fail.json")
	app_root.configure_leaderboard_service_for_test(service)
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.transition_to(RunPhase.PLAYING)
	app_root.item_controller.resolve_flag_landing(null, HexMetrics.center_for_offset(5, 25, app_root.world_presenter.hex_radius), null, &"impact")
	app_root.player_name_input.text = "Mira"
	app_root.confirm_score_button.pressed.emit()
	await wait_process_frames(1)

	assert_eq(app_root.get_run_state(), RunPhase.RESULT)
	assert_string_contains(app_root.result_status.text, "Online submit failed")
