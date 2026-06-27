## Represents one parsed leaderboard row.
class_name LeaderboardEntry
extends RefCounted


var rank := 0
var player_name := ""
var score_depth := 0
var metadata: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"rank": rank,
		"player_name": player_name,
		"score_depth": score_depth,
		"metadata": metadata.duplicate(true),
	}
