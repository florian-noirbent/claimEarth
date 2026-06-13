class_name LeaderboardService
extends Node


signal top_loaded(entries: Array, failed: bool, message: String)
signal submission_finished(submission, entry, failed: bool, message: String)
signal pending_retry_finished(remaining_pending: Array, successful_count: int, message: String)


func fetch_top(_limit: int) -> void:
	top_loaded.emit([], true, "Leaderboard service is unavailable.")


func submit_score(submission) -> void:
	submission_finished.emit(submission, null, true, "Leaderboard service is unavailable.")


func retry_pending(submissions: Array) -> void:
	pending_retry_finished.emit(submissions.duplicate(true), 0, "Leaderboard service is unavailable.")
