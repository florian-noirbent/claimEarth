class_name ScoreSubmission
extends RefCounted


var player_name := ""
var score_depth := 0
var run_seed := 0
var game_version := "dev"
var player_id := ""


static func from_dictionary(source: Dictionary) -> ScoreSubmission:
	var submission := ScoreSubmission.new()
	submission.player_name = String(source.get("player_name", "Player"))
	submission.score_depth = int(source.get("score_depth", 0))
	submission.run_seed = int(source.get("seed", 0))
	submission.game_version = String(source.get("game_version", "dev"))
	submission.player_id = String(source.get("player_id", ""))
	return submission


func metadata_dictionary() -> Dictionary:
	return {
		"seed": run_seed,
		"gameVersion": game_version,
	}


func to_pending_dictionary() -> Dictionary:
	return {
		"player_name": player_name,
		"score_depth": score_depth,
		"seed": run_seed,
		"game_version": game_version,
		"player_id": player_id,
	}
