extends GutTest


const PlayerStatisticsScript = preload("res://src/statistics/player_statistics.gd")
const StatisticsRulesScript = preload("res://src/statistics/statistics_rules.gd")
const RULES_RESOURCE_PATH := "res://config/statistics/statistics_rules.tres"


func test_defaults_are_empty() -> void:
	var data = PlayerStatisticsScript.new()

	assert_eq(data.version, PlayerStatisticsScript.CURRENT_VERSION)
	assert_eq(data.runs_started, 0)
	assert_eq(data.games_played, 0)
	assert_eq(data.flags_planted, 0)
	assert_eq(data.victories, 0)
	assert_eq(data.max_depth_reached, 0)
	assert_eq(data.best_flag_depth, 0)
	assert_eq(data.total_depth_traveled, 0)
	assert_eq(data.total_play_seconds, 0.0)
	assert_eq(data.longest_run_seconds, 0.0)
	assert_eq(data.fastest_victory_seconds, 0.0)
	assert_eq(data.current_flag_streak, 0)
	assert_eq(data.best_flag_streak, 0)
	assert_eq(data.item_uses.size(), 0)
	assert_eq(data.containers_opened.size(), 0)
	assert_eq(data.total_deaths(), 0)
	assert_eq(data.total_flags_lost(), 0)
	assert_eq(data.total_items_used(), 0)


func test_dictionary_round_trip_through_json_preserves_every_field() -> void:
	var data := _populated_statistics()

	var parsed: Variant = JSON.parse_string(JSON.stringify(data.to_dictionary()))
	var reloaded := PlayerStatisticsScript.from_dictionary(parsed) as PlayerStatistics

	assert_eq(reloaded.to_dictionary(), data.to_dictionary())
	assert_eq(typeof(reloaded.runs_started), TYPE_INT)
	assert_eq(typeof(reloaded.item_uses["3"]), TYPE_INT)
	assert_eq(PlayerStatisticsScript.count_in(reloaded.item_uses, 3), 7)
	assert_eq(PlayerStatisticsScript.count_in(reloaded.perk_picks, &"2"), 1)
	assert_eq(PlayerStatisticsScript.count_in(reloaded.deaths_by_cause, &"missing"), 0)


func test_totals_sum_counter_dictionaries() -> void:
	var data := _populated_statistics()

	assert_eq(data.total_deaths(), 5)
	assert_eq(data.total_flags_lost(), 2)
	assert_eq(data.total_items_used(), 9)


func test_duplicate_is_a_deep_copy() -> void:
	var data := _populated_statistics()

	var copy := data.duplicate_statistics()
	copy.runs_started += 1
	copy.item_uses["3"] = 99
	copy.deaths_by_cause["new"] = 1

	assert_eq(data.runs_started, 12)
	assert_eq(data.item_uses["3"], 7)
	assert_false(data.deaths_by_cause.has("new"))
	assert_eq(data.duplicate_statistics().to_dictionary(), data.to_dictionary())


func test_from_dictionary_sanitizes_invalid_values() -> void:
	var data := PlayerStatisticsScript.from_dictionary({
		"version": 99,
		"runs_started": -4,
		"games_played": "seven",
		"flags_planted": true,
		"victories": null,
		"max_depth_reached": 41.0,
		"best_flag_depth": [3],
		"total_depth_traveled": INF,
		"total_play_seconds": -2.5,
		"longest_run_seconds": NAN,
		"fastest_victory_seconds": "12",
		"current_flag_streak": 2.0,
		"item_uses": ["not", "a", "dictionary"],
		"item_offers": {"1": 2.0, "2": -1, "3": "four", "4": true, "": 5, 6: 3},
		"perk_picks": "nope",
		"deaths_by_cause": {"cooked": 1.0, "acid": {"nested": 1}},
	}) as PlayerStatistics

	assert_eq(data.version, PlayerStatisticsScript.CURRENT_VERSION)
	assert_eq(data.runs_started, 0)
	assert_eq(data.games_played, 0)
	assert_eq(data.flags_planted, 0)
	assert_eq(data.victories, 0)
	assert_eq(data.max_depth_reached, 41)
	assert_eq(typeof(data.max_depth_reached), TYPE_INT)
	assert_eq(data.best_flag_depth, 0)
	assert_eq(data.total_depth_traveled, 0)
	assert_eq(data.total_play_seconds, 0.0)
	assert_eq(data.longest_run_seconds, 0.0)
	assert_eq(data.fastest_victory_seconds, 0.0)
	assert_eq(data.current_flag_streak, 2)
	assert_eq(data.best_flag_streak, 0)
	assert_eq(data.item_uses, {})
	assert_eq(data.item_offers, {"1": 2, "6": 3})
	assert_eq(data.perk_picks, {})
	assert_eq(data.deaths_by_cause, {"cooked": 1})


func test_from_empty_dictionary_returns_defaults() -> void:
	var data := PlayerStatisticsScript.from_dictionary({}) as PlayerStatistics

	assert_eq(data.to_dictionary(), PlayerStatisticsScript.new().to_dictionary())


func test_default_rules_resource_is_valid() -> void:
	var rules := load(RULES_RESOURCE_PATH) as StatisticsRules

	assert_not_null(rules)
	assert_true(rules.validate().is_empty())
	assert_eq(rules.minimum_game_depth, 30)
	assert_almost_eq(rules.victory_depth_ratio, 0.95, 0.0001)


func test_rules_victory_depth_rounds_up_into_the_lava_core() -> void:
	var rules = StatisticsRulesScript.new()

	assert_eq(rules.victory_depth(200), 190)
	assert_eq(rules.victory_depth(101), 96)
	assert_eq(rules.victory_depth(0), 0)
	assert_eq(rules.victory_depth(-5), 0)


func test_rules_validation_reports_invalid_tuning() -> void:
	var rules = StatisticsRulesScript.new()
	rules.victory_depth_ratio = 0.0

	assert_true("\n".join(rules.validate()).contains("victory_depth_ratio"))


func _populated_statistics() -> PlayerStatistics:
	var data = PlayerStatisticsScript.new()
	data.runs_started = 12
	data.games_played = 9
	data.flags_planted = 4
	data.victories = 1
	data.max_depth_reached = 188
	data.best_flag_depth = 176
	data.total_depth_traveled = 950
	data.total_play_seconds = 1234.5
	data.longest_run_seconds = 301.25
	data.fastest_victory_seconds = 280.5
	data.current_flag_streak = 2
	data.best_flag_streak = 3
	data.item_uses = {"3": 7, "5": 2}
	data.item_offers = {"3": 4}
	data.item_picks = {"3": 1}
	data.perk_offers = {"2": 3}
	data.perk_picks = {"2": 1}
	data.containers_opened = {"item_chest": 6, "perk_geode": 2}
	data.containers_destroyed = {"item_chest": 3}
	data.deaths_by_cause = {"cooked": 3, "acid": 2}
	data.flags_lost_by_cause = {"lava": 2}
	return data
