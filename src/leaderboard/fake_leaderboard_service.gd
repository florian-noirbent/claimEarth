## Test double for leaderboard flows that never contacts the network.
class_name FakeLeaderboardService
extends "res://src/leaderboard/leaderboard_service.gd"


const LeaderboardEntryScript = preload("res://src/leaderboard/leaderboard_entry.gd")

var top_entries: Array[LeaderboardEntry] = []
var fetch_error := ""
var submit_error := ""
var retry_error := ""


func fetch_top(_limit: int) -> void:
	var entries := top_entries.duplicate()
	_sort_entries_by_best_depth(entries)
	top_loaded.emit(entries, not fetch_error.is_empty(), fetch_error)


func submit_score(submission: ScoreSubmission) -> void:
	if not submit_error.is_empty():
		submission_finished.emit(submission, null, true, submit_error)
		return
	var entry: LeaderboardEntry = LeaderboardEntryScript.new()
	entry.rank = 1
	entry.player_name = submission.player_name
	entry.score_depth = submission.score_depth
	entry.metadata = submission.metadata_dictionary()
	submission_finished.emit(submission, entry, false, "Score submitted.")


func retry_pending(submissions: Array) -> void:
	if not retry_error.is_empty():
		pending_retry_finished.emit(submissions.duplicate(true), 0, retry_error)
		return
	pending_retry_finished.emit([], submissions.size(), "Pending scores submitted.")


func _sort_entries_by_best_depth(entries: Array[LeaderboardEntry]) -> void:
	entries.sort_custom(func(left: LeaderboardEntry, right: LeaderboardEntry) -> bool:
		if left.score_depth == right.score_depth:
			return left.rank < right.rank
		return left.score_depth > right.score_depth
	)
	for index in entries.size():
		entries[index].rank = index + 1
