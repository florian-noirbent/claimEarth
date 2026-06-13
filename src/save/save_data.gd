class_name SaveData
extends RefCounted


const CURRENT_VERSION := 1

var version := CURRENT_VERSION
var last_player_name := "Player"
var personal_best_depth := -1
var pending_submissions: Array[Dictionary] = []


static func from_dictionary(source: Dictionary):
	var data = SaveData.new()
	data.version = int(source.get("version", CURRENT_VERSION))
	data.last_player_name = String(source.get("last_player_name", "Player"))
	data.personal_best_depth = int(source.get("personal_best_depth", -1))
	var raw_pending = source.get("pending_submissions", [])
	if raw_pending is Array:
		for entry in raw_pending:
			if entry is Dictionary:
				data.pending_submissions.append(entry.duplicate(true))
	return data


func to_dictionary() -> Dictionary:
	var serialized_pending: Array[Dictionary] = []
	for entry in pending_submissions:
		serialized_pending.append(entry.duplicate(true))
	return {
		"version": version,
		"last_player_name": last_player_name,
		"personal_best_depth": personal_best_depth,
		"pending_submissions": serialized_pending,
	}
