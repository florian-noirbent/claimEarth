## Owns lifetime player statistics, the in-progress run record, and their local persistence.
##
## Callers pass primitive keys (stable IDs, cause and container names); this controller
## knows nothing about items, perks, UI, or scenes. Event counters update the lifetime
## totals immediately, run aggregates fold in at end_run(), and disk is written only by
## end_run() and reset_statistics(). Until configure() runs, nothing is read or written.
class_name StatisticsController
extends Node


signal statistics_changed


const PlayerStatisticsScript = preload("res://src/statistics/player_statistics.gd")
const StatisticsRepositoryScript = preload("res://src/statistics/statistics_repository.gd")
const StatisticsRulesScript = preload("res://src/statistics/statistics_rules.gd")

@export var rules: StatisticsRules

var _repository: StatisticsRepository = StatisticsRepositoryScript.new()
var _data: PlayerStatistics = PlayerStatisticsScript.new()
var _default_rules: StatisticsRules
var _persistence_enabled := false
var _run_active := false
var _run_world_depth := 0
var _run_max_depth := 0
var _run_seconds := 0.0
var _run_death_recorded := false
var _run_flag_resolved := false
var _run_flag_planted := false
var _run_victory := false


func configure(statistics_path: String = "", persistence_enabled: bool = true) -> void:
	if not statistics_path.is_empty():
		_repository.configure(statistics_path)
	_persistence_enabled = persistence_enabled
	_data = _repository.load_data() if _persistence_enabled else PlayerStatisticsScript.new()
	statistics_changed.emit()


func statistics() -> PlayerStatistics:
	return _data.duplicate_statistics()


func is_run_active() -> bool:
	return _run_active


func begin_run(world_depth: int) -> void:
	if _run_active:
		end_run()
	_run_active = true
	_run_world_depth = maxi(world_depth, 0)
	_run_max_depth = 0
	_run_seconds = 0.0
	_run_death_recorded = false
	_run_flag_resolved = false
	_run_flag_planted = false
	_run_victory = false


## Called every active-play frame: no allocation, no save, no signal.
func record_progress(depth: int, delta_seconds: float) -> void:
	if not _run_active:
		return
	if depth > _run_max_depth:
		_run_max_depth = depth
	if delta_seconds > 0.0:
		_run_seconds += delta_seconds


func record_item_used(item_id: int) -> void:
	_increment_run_counter(_data.item_uses, item_id)


func record_item_offered(item_id: int) -> void:
	_increment_run_counter(_data.item_offers, item_id)


func record_item_picked(item_id: int) -> void:
	_increment_run_counter(_data.item_picks, item_id)


func record_perk_offered(perk_id: int) -> void:
	_increment_run_counter(_data.perk_offers, perk_id)


func record_perk_picked(perk_id: int) -> void:
	_increment_run_counter(_data.perk_picks, perk_id)


func record_container_opened(container_key: StringName) -> void:
	_increment_run_counter(_data.containers_opened, container_key)


func record_object_destroyed(container_key: StringName) -> void:
	_increment_run_counter(_data.objects_destroyed, container_key)


## At most one death counts per run. A death and a flag resolution may both be recorded in
## one run, in either order: the Relentless perk drops the held flag when the player dies
## and that flag can still plant or be destroyed afterwards.
func record_death(cause: StringName) -> void:
	if not _run_active or _run_death_recorded:
		return
	_run_death_recorded = true
	_increment_counter(_data.deaths_by_cause, cause)


## At most one flag resolution (planted or lost) counts per run. Returns true for a victory.
func record_flag_planted(depth: int) -> bool:
	if not _claim_flag_resolution():
		return false
	var landing_depth := maxi(depth, 0)
	_run_flag_planted = true
	_run_victory = _run_world_depth > 0 and landing_depth >= _rules().victory_depth(_run_world_depth)
	_data.flags_planted += 1
	_data.best_flag_depth = maxi(_data.best_flag_depth, landing_depth)
	if _run_victory:
		_data.victories += 1
	return _run_victory


func record_flag_lost(cause: StringName) -> void:
	if not _claim_flag_resolution():
		return
	_increment_counter(_data.flags_lost_by_cause, cause)


func end_run() -> void:
	if not _run_active:
		return
	_run_active = false
	_data.runs_started += 1
	var played_game := _run_max_depth >= _rules().minimum_game_depth
	if played_game:
		_data.games_played += 1
	_data.max_depth_reached = maxi(_data.max_depth_reached, _run_max_depth)
	_data.total_depth_traveled += _run_max_depth
	_data.total_play_seconds += _run_seconds
	_data.longest_run_seconds = maxf(_data.longest_run_seconds, _run_seconds)
	if _run_flag_planted:
		_data.current_flag_streak += 1
		_data.best_flag_streak = maxi(_data.best_flag_streak, _data.current_flag_streak)
	elif played_game:
		_data.current_flag_streak = 0
	if _run_victory and (_data.fastest_victory_seconds <= 0.0 or _run_seconds < _data.fastest_victory_seconds):
		_data.fastest_victory_seconds = _run_seconds
	_save()
	statistics_changed.emit()


func reset_statistics() -> void:
	_data = PlayerStatisticsScript.new()
	_save()
	statistics_changed.emit()


func _claim_flag_resolution() -> bool:
	if not _run_active or _run_flag_resolved:
		return false
	_run_flag_resolved = true
	return true


func _increment_run_counter(counter: Dictionary, key: Variant) -> void:
	if not _run_active:
		return
	_increment_counter(counter, key)


func _increment_counter(counter: Dictionary, key: Variant) -> void:
	var counter_key := str(key)
	if counter_key.is_empty():
		return
	counter[counter_key] = int(counter.get(counter_key, 0)) + 1


func _rules() -> StatisticsRules:
	if rules != null:
		return rules
	if _default_rules == null:
		_default_rules = StatisticsRulesScript.new()
	return _default_rules


func _save() -> void:
	if _persistence_enabled:
		_repository.save_data(_data)
