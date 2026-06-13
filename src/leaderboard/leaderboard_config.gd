class_name LeaderboardConfig
extends Resource


@export var enabled := false
@export var api_base_url := "https://api.simpleboards.dev/api"
@export var leaderboard_id := ""
@export var api_key := ""
@export var request_timeout_seconds := 8.0
@export var max_entries := 10
@export var game_version := "jam-dev"


func is_valid() -> bool:
	return enabled and not leaderboard_id.is_empty() and not api_key.is_empty()
