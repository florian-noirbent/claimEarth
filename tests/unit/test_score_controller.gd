extends GutTest


const FakeLeaderboardServiceScript = preload("res://src/leaderboard/fake_leaderboard_service.gd")


func before_each() -> void:
	var path := "user://gut_score_controller.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_confirm_score_updates_profile_and_emits_submission_result() -> void:
	var controller := ScoreController.new()
	var service = FakeLeaderboardServiceScript.new()
	controller.configure_save_path("user://gut_score_controller.json")
	add_child_autofree(controller)
	controller.configure(load("res://config/leaderboard/simpleboards.tres"), true, service)
	watch_signals(controller)

	var result := controller.confirm_score("  Ada  ", 81, 1234)
	assert_true(result.accepted)
	assert_true(result.submitted)
	assert_eq(controller.last_player_name, "Ada")
	assert_eq(controller.personal_best_depth, 81)
	await wait_process_frames(1)
	assert_signal_emitted(controller, "submission_finished")


func test_failed_submission_is_persisted_for_retry() -> void:
	var controller := ScoreController.new()
	var service = FakeLeaderboardServiceScript.new()
	service.submit_error = "Offline"
	controller.configure_save_path("user://gut_score_controller.json")
	add_child_autofree(controller)
	controller.configure(load("res://config/leaderboard/simpleboards.tres"), true, service)

	controller.confirm_score("Mira", 25, 99)
	await wait_process_frames(1)
	assert_eq(controller.pending_submission_count(), 1)


func test_empty_name_is_rejected_without_changing_profile() -> void:
	var controller := ScoreController.new()
	controller.configure_save_path("user://gut_score_controller.json")
	add_child_autofree(controller)
	controller.configure(load("res://config/leaderboard/simpleboards.tres"), true)

	var result := controller.confirm_score("   ", 10, 1)
	assert_false(result.accepted)
	assert_eq(controller.personal_best_depth, -1)
