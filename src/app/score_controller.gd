## Owns local score persistence and leaderboard submission workflow.
class_name ScoreController
extends Node


signal profile_changed
signal leaderboard_changed(entries: Array[LeaderboardEntry], failed: bool, message: String)
signal submission_finished(submission: ScoreSubmission, entry: LeaderboardEntry, failed: bool, message: String)
signal pending_retry_finished(successful_count: int, message: String)

const SaveRepositoryScript = preload("res://src/save/save_repository.gd")
const SaveDataScript = preload("res://src/save/save_data.gd")
const ScoreSubmissionScript = preload("res://src/leaderboard/score_submission.gd")
const SimpleBoardsLeaderboardServiceScript = preload("res://src/leaderboard/simpleboards_leaderboard_service.gd")

var last_player_name := "Player"
var personal_best_depth := -1
var global_best_depth := -1
var global_best_player := ""
var storage_warning := ""

var _save_repository: SaveRepository = SaveRepositoryScript.new()
var _leaderboard_service: LeaderboardService
var _leaderboard_config: LeaderboardConfig
var _pending_submissions: Array[Dictionary] = []
var _retrying_pending := false


func configure(leaderboard_config: LeaderboardConfig, test_mode: bool, injected_service: LeaderboardService = null) -> void:
	_leaderboard_config = leaderboard_config
	_load_local_state()
	if injected_service != null:
		_install_service(injected_service)
	elif not test_mode:
		var service: LeaderboardService = SimpleBoardsLeaderboardServiceScript.new()
		service.configure(leaderboard_config)
		_install_service(service)
	profile_changed.emit()


func configure_save_path(save_path: String) -> void:
	_save_repository.configure(save_path)


func configure_service(service: LeaderboardService) -> void:
	_install_service(service)


func has_service() -> bool:
	return _leaderboard_service != null


func confirm_score(player_name: String, depth: int, run_seed: int) -> Dictionary:
	var trimmed_name := player_name.strip_edges()
	if trimmed_name.is_empty():
		return {"accepted": false, "error": "Enter a name between 1 and 20 characters."}
	last_player_name = trimmed_name.substr(0, 20)
	personal_best_depth = maxi(personal_best_depth, depth)
	_persist_local_state()
	profile_changed.emit()

	var submission: ScoreSubmission = ScoreSubmissionScript.new()
	submission.player_name = last_player_name
	submission.score_depth = depth
	submission.run_seed = run_seed
	submission.game_version = _leaderboard_config.game_version if _leaderboard_config != null else "dev"
	if _leaderboard_service == null:
		return {"accepted": true, "submitted": false, "submission": submission}
	_leaderboard_service.call_deferred("submit_score", submission)
	return {"accepted": true, "submitted": true, "submission": submission}


func fetch_top(limit: int = 10) -> bool:
	if _leaderboard_service == null:
		return false
	_leaderboard_service.fetch_top(limit)
	return true


func retry_pending() -> void:
	if _leaderboard_service == null or _pending_submissions.is_empty() or _retrying_pending:
		return
	_retrying_pending = true
	_leaderboard_service.retry_pending(_pending_submissions)


func pending_submission_count() -> int:
	return _pending_submissions.size()


func _install_service(service: LeaderboardService) -> void:
	_leaderboard_service = service
	if _leaderboard_service.get_parent() == null:
		add_child(_leaderboard_service)
	if not _leaderboard_service.top_loaded.is_connected(_on_top_loaded):
		_leaderboard_service.top_loaded.connect(_on_top_loaded)
	if not _leaderboard_service.submission_finished.is_connected(_on_submission_finished):
		_leaderboard_service.submission_finished.connect(_on_submission_finished)
	if not _leaderboard_service.pending_retry_finished.is_connected(_on_pending_retry_finished):
		_leaderboard_service.pending_retry_finished.connect(_on_pending_retry_finished)


func _load_local_state() -> void:
	storage_warning = _save_repository.storage_warning()
	var save_data: SaveData = _save_repository.load_data()
	last_player_name = save_data.last_player_name
	personal_best_depth = save_data.personal_best_depth
	_pending_submissions.assign(save_data.pending_submissions)


func _persist_local_state() -> void:
	var save_data: SaveData = SaveDataScript.new()
	save_data.last_player_name = last_player_name
	save_data.personal_best_depth = personal_best_depth
	for pending_submission in _pending_submissions:
		save_data.pending_submissions.append(pending_submission.duplicate(true))
	_save_repository.save_data(save_data)


func _on_top_loaded(entries: Array[LeaderboardEntry], failed: bool, message: String) -> void:
	if not failed:
		if entries.is_empty():
			global_best_depth = -1
			global_best_player = ""
		else:
			global_best_depth = entries[0].score_depth
			global_best_player = entries[0].player_name
		profile_changed.emit()
	leaderboard_changed.emit(entries, failed, message)


func _on_submission_finished(submission: ScoreSubmission, entry: LeaderboardEntry, failed: bool, message: String) -> void:
	if failed:
		_pending_submissions.append(submission.to_pending_dictionary())
		_persist_local_state()
	elif entry != null and (global_best_depth < 0 or entry.score_depth >= global_best_depth):
		global_best_depth = entry.score_depth
		global_best_player = entry.player_name
		profile_changed.emit()
	submission_finished.emit(submission, entry, failed, message)


func _on_pending_retry_finished(remaining_pending: Array, successful_count: int, message: String) -> void:
	_retrying_pending = false
	_pending_submissions.clear()
	for pending_submission in remaining_pending:
		_pending_submissions.append(pending_submission.duplicate(true))
	_persist_local_state()
	pending_retry_finished.emit(successful_count, message)
