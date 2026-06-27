## Parses and validates SimpleBoards leaderboard responses.
class_name SimpleBoardsResponseParser
extends RefCounted


const LeaderboardEntryScript = preload("res://src/leaderboard/leaderboard_entry.gd")


static func parse_entries(body_text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(body_text) != OK:
		return {"ok": false, "message": "Malformed leaderboard response.", "entries": []}
	if parser.data is not Array:
		return {"ok": false, "message": "Leaderboard response was not an array.", "entries": []}
	var entries: Array[LeaderboardEntry] = []
	var rank := 1
	for raw_entry in parser.data:
		if raw_entry is not Dictionary:
			return {"ok": false, "message": "Leaderboard entry payload was invalid.", "entries": []}
		var entry: LeaderboardEntry = _entry_from_dictionary(raw_entry, rank)
		if entry == null:
			return {"ok": false, "message": "Leaderboard entry payload was incomplete.", "entries": []}
		entries.append(entry)
		rank += 1
	return {"ok": true, "message": "", "entries": entries}


static func parse_entry(body_text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(body_text) != OK:
		return {"ok": false, "message": "Malformed score submission response.", "entry": null}
	if parser.data is not Dictionary:
		return {"ok": false, "message": "Score submission response was not an object.", "entry": null}
	var source: Dictionary = parser.data
	var entry: LeaderboardEntry = _entry_from_dictionary(source, 0)
	if entry == null:
		return {"ok": false, "message": "Score submission response was incomplete.", "entry": null}
	return {"ok": true, "message": "", "entry": entry}


static func _entry_from_dictionary(source: Dictionary, entry_rank: int) -> LeaderboardEntry:
	if not source.has("playerDisplayName") or not source.has("score"):
		return null
	var entry: LeaderboardEntry = LeaderboardEntryScript.new()
	entry.rank = entry_rank
	entry.player_name = String(source.get("playerDisplayName", "Unknown"))
	entry.score_depth = int(String(source.get("score", "0")))
	var metadata_text := String(source.get("metadata", "{}"))
	var metadata_parser := JSON.new()
	if metadata_parser.parse(metadata_text) == OK and metadata_parser.data is Dictionary:
		entry.metadata = metadata_parser.data as Dictionary
	return entry
