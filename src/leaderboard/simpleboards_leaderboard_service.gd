## SimpleBoards implementation of the leaderboard service boundary.
class_name SimpleBoardsLeaderboardService
extends "res://src/leaderboard/leaderboard_service.gd"


const ParserScript = preload("res://src/leaderboard/simpleboards_response_parser.gd")
const ScoreSubmissionScript = preload("res://src/leaderboard/score_submission.gd")

var config: LeaderboardConfig


func configure(config_value: LeaderboardConfig) -> void:
	config = config_value


func fetch_top(limit: int) -> void:
	if config == null or not config.is_valid():
		top_loaded.emit([], true, "Leaderboard is not configured yet.")
		return
	var url := "%s/leaderboards/%s/entries" % [_normalized_base_url(), config.leaderboard_id]
	var response: Dictionary = await _perform_request(url, _headers(), HTTPClient.METHOD_GET)
	if not bool(response["ok"]):
		var empty_entries: Array[LeaderboardEntry] = []
		top_loaded.emit(empty_entries, true, String(response["message"]))
		return
	var parsed: Dictionary = ParserScript.parse_entries(String(response["body"]))
	if not bool(parsed["ok"]):
		var empty_entries: Array[LeaderboardEntry] = []
		top_loaded.emit(empty_entries, true, String(parsed["message"]))
		return
	var entries: Array[LeaderboardEntry] = parsed["entries"]
	if limit > 0 and entries.size() > limit:
		entries = entries.slice(0, limit)
	top_loaded.emit(entries, false, "")


func submit_score(submission: ScoreSubmission) -> void:
	if config == null or not config.is_valid():
		submission_finished.emit(submission, null, true, "Leaderboard is not configured yet.")
		return
	var payload := {
		"leaderboardId": config.leaderboard_id,
		"playerDisplayName": submission.player_name,
		"score": str(submission.score_depth),
		"metadata": JSON.stringify(submission.metadata_dictionary()),
	}
	if not submission.player_id.is_empty():
		payload["playerId"] = submission.player_id
	var response: Dictionary = await _perform_request(
		"%s/entries" % _normalized_base_url(),
		_headers(true),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if not bool(response["ok"]):
		submission_finished.emit(submission, null, true, String(response["message"]))
		return
	var parsed: Dictionary = ParserScript.parse_entry(String(response["body"]))
	if not bool(parsed["ok"]):
		submission_finished.emit(submission, null, true, String(parsed["message"]))
		return
	var entry: LeaderboardEntry = parsed["entry"]
	submission_finished.emit(submission, entry, false, "Score submitted.")


func retry_pending(submissions: Array) -> void:
	if submissions.is_empty():
		pending_retry_finished.emit([], 0, "")
		return
	var remaining: Array = []
	var success_count := 0
	var last_message := ""
	for pending_submission in submissions:
		var submission: ScoreSubmission = ScoreSubmissionScript.from_dictionary(pending_submission)
		var payload := {
			"leaderboardId": config.leaderboard_id,
			"playerDisplayName": submission.player_name,
			"score": str(submission.score_depth),
			"metadata": JSON.stringify(submission.metadata_dictionary()),
		}
		if not submission.player_id.is_empty():
			payload["playerId"] = submission.player_id
		var response: Dictionary = await _perform_request(
			"%s/entries" % _normalized_base_url(),
			_headers(true),
			HTTPClient.METHOD_POST,
			JSON.stringify(payload)
		)
		if not bool(response["ok"]):
			remaining.append(pending_submission)
			last_message = String(response["message"])
			continue
		var parsed: Dictionary = ParserScript.parse_entry(String(response["body"]))
		if not bool(parsed["ok"]):
			remaining.append(pending_submission)
			last_message = String(parsed["message"])
			continue
		success_count += 1
	pending_retry_finished.emit(remaining, success_count, last_message)


func _normalized_base_url() -> String:
	return config.api_base_url.rstrip("/")


func _headers(include_json: bool = false) -> PackedStringArray:
	var headers := PackedStringArray(["x-api-key: %s" % config.api_key])
	if include_json:
		headers.append("Content-Type: application/json")
	return headers


func _perform_request(url: String, headers: PackedStringArray, method: HTTPClient.Method, body: String = "") -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = config.request_timeout_seconds
	add_child(request)
	var request_error := request.request(url, headers, method, body)
	if request_error != OK:
		request.queue_free()
		return {"ok": false, "message": "Request failed to start (%d)." % request_error, "body": ""}
	var completed: Array = await request.request_completed
	request.queue_free()
	var result := int(completed[0])
	var response_code := int(completed[1])
	var response_body := PackedByteArray(completed[3]).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "message": "Network request failed (%d)." % result, "body": response_body}
	if response_code < 200 or response_code >= 300:
		return {"ok": false, "message": "Leaderboard request failed (%d)." % response_code, "body": response_body}
	return {"ok": true, "message": "", "body": response_body}
