## Serializable lifetime player statistics kept separate from scores and settings.
class_name PlayerStatistics
extends RefCounted


const CURRENT_VERSION := 1

var version := CURRENT_VERSION
var runs_started := 0
var games_played := 0
var flags_planted := 0
var victories := 0
var max_depth_reached := 0
var best_flag_depth := 0
var total_depth_traveled := 0
var total_play_seconds := 0.0
var longest_run_seconds := 0.0
## Zero until the first victory.
var fastest_victory_seconds := 0.0
var current_flag_streak := 0
var best_flag_streak := 0
## Item stable ID string -> times used.
var item_uses: Dictionary = {}
## Item stable ID string -> times offered in a chest.
var item_offers: Dictionary = {}
## Item stable ID string -> times picked from a chest.
var item_picks: Dictionary = {}
## Perk stable ID string -> times offered in a geode.
var perk_offers: Dictionary = {}
## Perk stable ID string -> times picked from a geode.
var perk_picks: Dictionary = {}
## Container key -> times opened.
var containers_opened: Dictionary = {}
## Death cause -> deaths.
var deaths_by_cause: Dictionary = {}
## Flag loss cause -> flags lost.
var flags_lost_by_cause: Dictionary = {}


static func from_dictionary(source: Dictionary) -> PlayerStatistics:
	var data := PlayerStatistics.new()
	data.version = CURRENT_VERSION
	data.runs_started = _read_count(source, "runs_started")
	data.games_played = _read_count(source, "games_played")
	data.flags_planted = _read_count(source, "flags_planted")
	data.victories = _read_count(source, "victories")
	data.max_depth_reached = _read_count(source, "max_depth_reached")
	data.best_flag_depth = _read_count(source, "best_flag_depth")
	data.total_depth_traveled = _read_count(source, "total_depth_traveled")
	data.total_play_seconds = _read_seconds(source, "total_play_seconds")
	data.longest_run_seconds = _read_seconds(source, "longest_run_seconds")
	data.fastest_victory_seconds = _read_seconds(source, "fastest_victory_seconds")
	data.current_flag_streak = _read_count(source, "current_flag_streak")
	data.best_flag_streak = _read_count(source, "best_flag_streak")
	data.item_uses = _read_counter(source, "item_uses")
	data.item_offers = _read_counter(source, "item_offers")
	data.item_picks = _read_counter(source, "item_picks")
	data.perk_offers = _read_counter(source, "perk_offers")
	data.perk_picks = _read_counter(source, "perk_picks")
	data.containers_opened = _read_counter(source, "containers_opened")
	data.deaths_by_cause = _read_counter(source, "deaths_by_cause")
	data.flags_lost_by_cause = _read_counter(source, "flags_lost_by_cause")
	return data


func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"runs_started": runs_started,
		"games_played": games_played,
		"flags_planted": flags_planted,
		"victories": victories,
		"max_depth_reached": max_depth_reached,
		"best_flag_depth": best_flag_depth,
		"total_depth_traveled": total_depth_traveled,
		"total_play_seconds": total_play_seconds,
		"longest_run_seconds": longest_run_seconds,
		"fastest_victory_seconds": fastest_victory_seconds,
		"current_flag_streak": current_flag_streak,
		"best_flag_streak": best_flag_streak,
		"item_uses": item_uses.duplicate(),
		"item_offers": item_offers.duplicate(),
		"item_picks": item_picks.duplicate(),
		"perk_offers": perk_offers.duplicate(),
		"perk_picks": perk_picks.duplicate(),
		"containers_opened": containers_opened.duplicate(),
		"deaths_by_cause": deaths_by_cause.duplicate(),
		"flags_lost_by_cause": flags_lost_by_cause.duplicate(),
	}


func duplicate_statistics() -> PlayerStatistics:
	return PlayerStatistics.from_dictionary(to_dictionary())


static func count_in(counter: Dictionary, key: Variant) -> int:
	return int(counter.get(str(key), 0))


func total_deaths() -> int:
	return _sum(deaths_by_cause)


func total_flags_lost() -> int:
	return _sum(flags_lost_by_cause)


func total_items_used() -> int:
	return _sum(item_uses)


static func _sum(counter: Dictionary) -> int:
	var total := 0
	for value in counter.values():
		total += int(value)
	return total


static func _read_count(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key, 0)
	return int(value) if _is_non_negative_number(value) else 0


static func _read_seconds(source: Dictionary, key: String) -> float:
	var value: Variant = source.get(key, 0.0)
	return float(value) if _is_non_negative_number(value) else 0.0


## JSON parses every number as a float, so counters accept integral floats too.
static func _read_counter(source: Dictionary, key: String) -> Dictionary:
	var counter := {}
	var raw: Variant = source.get(key, {})
	if raw is not Dictionary:
		return counter
	var raw_counter := raw as Dictionary
	for raw_key in raw_counter.keys():
		var counter_key := str(raw_key)
		var raw_count: Variant = raw_counter[raw_key]
		if counter_key.is_empty() or not _is_non_negative_number(raw_count):
			continue
		counter[counter_key] = int(raw_count)
	return counter


static func _is_non_negative_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number >= 0.0
