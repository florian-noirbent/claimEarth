extends GutTest


const StatisticsControllerScript = preload("res://src/statistics/statistics_controller.gd")
const StatisticsRulesScript = preload("res://src/statistics/statistics_rules.gd")
const PlayerStatisticsScript = preload("res://src/statistics/player_statistics.gd")

const WORLD_DEPTH := 200

var _statistics_path := "user://gut_statistics_controller.json"
var _default_path_existed := false


func before_each() -> void:
	_remove_statistics()
	_default_path_existed = FileAccess.file_exists("user://claim_earth_statistics.json")


func after_each() -> void:
	_remove_statistics()


func test_missing_rules_fall_back_to_default_resource_values() -> void:
	var controller := _controller(false, false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(29, 1.0)
	controller.end_run()
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(30, 1.0)

	assert_true(controller.record_flag_planted(190))
	controller.end_run()
	assert_eq(controller.statistics().games_played, 1)
	controller.free()


func test_runs_count_as_games_only_from_the_minimum_depth() -> void:
	var controller := _controller(false)

	_play_run(controller, 29)
	_play_run(controller, 30)
	_play_run(controller, 75)

	var data := controller.statistics()
	assert_eq(data.runs_started, 3)
	assert_eq(data.games_played, 2)
	assert_eq(data.max_depth_reached, 75)
	assert_eq(data.total_depth_traveled, 29 + 30 + 75)
	controller.free()


func test_progress_tracks_the_run_maximum_and_play_time() -> void:
	var controller := _controller(false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(10, 0.5)
	controller.record_progress(42, 0.5)
	controller.record_progress(12, 1.0)
	controller.record_progress(-3, -1.0)
	controller.end_run()
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(5, 3.0)
	controller.end_run()

	var data := controller.statistics()
	assert_eq(data.max_depth_reached, 42)
	assert_eq(data.total_depth_traveled, 47)
	assert_almost_eq(data.total_play_seconds, 5.0, 0.0001)
	assert_almost_eq(data.longest_run_seconds, 3.0, 0.0001)
	controller.free()


func test_run_aggregates_fold_in_only_at_end_run() -> void:
	var controller := _controller(false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(80, 2.0)
	controller.record_item_used(4)

	var during := controller.statistics()
	assert_eq(during.runs_started, 0)
	assert_eq(during.max_depth_reached, 0)
	assert_eq(during.total_play_seconds, 0.0)
	assert_eq(PlayerStatisticsScript.count_in(during.item_uses, 4), 1)

	controller.end_run()
	assert_eq(controller.statistics().runs_started, 1)
	assert_eq(controller.statistics().max_depth_reached, 80)
	controller.free()


func test_statistics_returns_a_copy() -> void:
	var controller := _controller(false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_item_used(1)

	var snapshot := controller.statistics()
	snapshot.item_uses["1"] = 50
	snapshot.runs_started = 9

	assert_eq(PlayerStatisticsScript.count_in(controller.statistics().item_uses, 1), 1)
	assert_eq(controller.statistics().runs_started, 0)
	controller.free()


func test_event_counters_use_stringified_keys() -> void:
	var controller := _controller(false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_item_used(3)
	controller.record_item_used(3)
	controller.record_item_offered(3)
	controller.record_item_offered(5)
	controller.record_item_picked(5)
	controller.record_perk_offered(1)
	controller.record_perk_offered(2)
	controller.record_perk_picked(2)
	controller.record_container_opened(&"item_chest")
	controller.record_container_opened(&"item_chest")
	controller.record_container_opened(&"perk_geode")
	controller.record_object_destroyed(&"perk_geode")

	var data := controller.statistics()
	assert_eq(data.item_uses, {"3": 2})
	assert_eq(data.item_offers, {"3": 1, "5": 1})
	assert_eq(data.item_picks, {"5": 1})
	assert_eq(data.perk_offers, {"1": 1, "2": 1})
	assert_eq(data.perk_picks, {"2": 1})
	assert_eq(data.containers_opened, {"item_chest": 2, "perk_geode": 1})
	assert_eq(data.objects_destroyed, {"perk_geode": 1})
	assert_eq(data.total_items_used(), 2)
	controller.free()


func test_records_are_ignored_without_an_active_run() -> void:
	var controller := _controller(false)
	watch_signals(controller)

	controller.record_progress(90, 5.0)
	controller.record_item_used(1)
	controller.record_item_offered(1)
	controller.record_item_picked(1)
	controller.record_perk_offered(1)
	controller.record_perk_picked(1)
	controller.record_container_opened(&"item_chest")
	controller.record_death(&"cooked")
	assert_false(controller.record_flag_planted(195))
	controller.record_flag_lost(&"lava")
	controller.end_run()

	assert_false(controller.is_run_active())
	assert_eq(controller.statistics().to_dictionary(), PlayerStatisticsScript.new().to_dictionary())
	assert_signal_not_emitted(controller, "statistics_changed")
	controller.free()


func test_victory_requires_the_configured_lava_core_depth() -> void:
	var controller := _controller(false)

	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(189, 1.0)
	assert_false(controller.record_flag_planted(189))
	controller.end_run()
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(190, 1.0)
	assert_true(controller.record_flag_planted(190))
	controller.end_run()

	var data := controller.statistics()
	assert_eq(data.flags_planted, 2)
	assert_eq(data.victories, 1)
	assert_eq(data.best_flag_depth, 190)
	controller.free()


func test_victory_threshold_follows_rules_resource() -> void:
	var rules = StatisticsRulesScript.new()
	rules.victory_depth_ratio = 0.5
	var controller = StatisticsControllerScript.new()
	controller.rules = rules
	controller.configure(_statistics_path, false)

	controller.begin_run(WORLD_DEPTH)
	assert_true(controller.record_flag_planted(100))
	controller.end_run()

	assert_eq(controller.statistics().victories, 1)
	controller.free()


func test_a_run_records_at_most_one_death_and_one_flag_resolution() -> void:
	var controller := _controller(false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_death(&"cooked")
	controller.record_death(&"acid")
	controller.end_run()

	controller.begin_run(WORLD_DEPTH)
	controller.record_flag_lost(&"lava")
	controller.record_flag_lost(&"acid")
	assert_false(controller.record_flag_planted(195), "A lost flag already resolved this run.")
	controller.end_run()

	controller.begin_run(WORLD_DEPTH)
	assert_false(controller.record_flag_planted(40))
	assert_false(controller.record_flag_planted(195))
	controller.record_flag_lost(&"acid")
	controller.end_run()

	var data := controller.statistics()
	assert_eq(data.deaths_by_cause, {"cooked": 1})
	assert_eq(data.flags_lost_by_cause, {"lava": 1})
	assert_eq(data.flags_planted, 1)
	assert_eq(data.victories, 0)
	assert_eq(data.best_flag_depth, 40)
	assert_eq(data.total_deaths(), 1)
	assert_eq(data.total_flags_lost(), 1)
	controller.free()


func test_relentless_death_then_flag_resolution_records_both() -> void:
	var controller := _controller(false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(120, 1.0)
	controller.record_death(&"cooked")
	assert_true(controller.record_flag_planted(195), "The dropped flag can still plant after the death.")
	controller.record_death(&"acid")
	controller.end_run()

	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(80, 1.0)
	controller.record_death(&"suffocation")
	controller.record_flag_lost(&"lava")
	controller.end_run()

	var data := controller.statistics()
	assert_eq(data.deaths_by_cause, {"cooked": 1, "suffocation": 1})
	assert_eq(data.flags_planted, 1)
	assert_eq(data.victories, 1)
	assert_eq(data.flags_lost_by_cause, {"lava": 1})
	controller.free()


func test_flag_resolution_then_death_records_both() -> void:
	var controller := _controller(false)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(60, 1.0)
	assert_false(controller.record_flag_planted(60))
	controller.record_death(&"bomb")
	controller.end_run()

	var data := controller.statistics()
	assert_eq(data.flags_planted, 1)
	assert_eq(data.deaths_by_cause, {"bomb": 1})
	controller.free()


func test_planted_flag_keeps_the_streak_even_when_the_player_died() -> void:
	var controller := _controller(false)
	_play_run(controller, 50, true)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(70, 1.0)
	controller.record_death(&"cooked")
	controller.record_flag_planted(72)
	controller.end_run()
	_assert_streak(controller, 2, 2)
	controller.free()


func test_flag_streak_counts_consecutive_played_games_with_a_flag() -> void:
	var controller := _controller(false)

	_play_run(controller, 50, true)
	_play_run(controller, 60, true)
	_assert_streak(controller, 2, 2)
	_play_run(controller, 10)
	_assert_streak(controller, 2, 2)
	_play_run(controller, 12, true)
	_assert_streak(controller, 3, 3)
	_play_run(controller, 45, false, &"cooked")
	_assert_streak(controller, 0, 3)
	_play_run(controller, 45, true)
	_assert_streak(controller, 1, 3)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(40, 1.0)
	controller.record_flag_lost(&"lava")
	controller.end_run()
	_assert_streak(controller, 0, 3)
	controller.free()


func test_fastest_victory_keeps_the_shortest_winning_run() -> void:
	var controller := _controller(false)

	_play_victory(controller, 300.0)
	assert_almost_eq(controller.statistics().fastest_victory_seconds, 300.0, 0.0001)
	_play_victory(controller, 200.0)
	_play_victory(controller, 250.0)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(50, 10.0)
	controller.record_flag_planted(60)
	controller.end_run()

	var data := controller.statistics()
	assert_almost_eq(data.fastest_victory_seconds, 200.0, 0.0001)
	assert_almost_eq(data.longest_run_seconds, 300.0, 0.0001)
	assert_eq(data.victories, 3)
	controller.free()


func test_begin_run_abandons_an_active_run_first() -> void:
	var controller := _controller(false)
	watch_signals(controller)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(70, 4.0)
	controller.begin_run(WORLD_DEPTH)

	assert_true(controller.is_run_active())
	assert_signal_emit_count(controller, "statistics_changed", 1)
	var data := controller.statistics()
	assert_eq(data.runs_started, 1)
	assert_eq(data.games_played, 1)
	assert_eq(data.max_depth_reached, 70)
	assert_eq(data.total_deaths(), 0)

	controller.record_progress(5, 1.0)
	controller.end_run()
	assert_eq(controller.statistics().runs_started, 2)
	assert_eq(controller.statistics().max_depth_reached, 70)
	controller.free()


func test_end_run_is_idempotent() -> void:
	var controller := _controller(true)
	watch_signals(controller)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(40, 2.0)
	controller.end_run()
	controller.end_run()

	assert_false(controller.is_run_active())
	assert_signal_emit_count(controller, "statistics_changed", 1)
	assert_eq(controller.statistics().runs_started, 1)
	assert_eq(controller.statistics().total_depth_traveled, 40)
	controller.free()


func test_end_run_persists_lifetime_totals() -> void:
	var controller := _controller(true)
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(40, 2.0)
	controller.record_item_used(7)
	assert_false(FileAccess.file_exists(_statistics_path), "Events must not write to disk before the run ends.")
	controller.record_death(&"poison")
	controller.end_run()

	var reloaded := _controller(true)
	var data := reloaded.statistics()
	assert_eq(data.runs_started, 1)
	assert_eq(data.games_played, 1)
	assert_eq(PlayerStatisticsScript.count_in(data.item_uses, 7), 1)
	assert_eq(PlayerStatisticsScript.count_in(data.deaths_by_cause, &"poison"), 1)
	controller.free()
	reloaded.free()


func test_progress_does_not_save_or_emit() -> void:
	var controller := _controller(true)
	watch_signals(controller)
	controller.begin_run(WORLD_DEPTH)
	for frame in 120:
		controller.record_progress(frame, 1.0 / 60.0)

	assert_false(FileAccess.file_exists(_statistics_path))
	assert_signal_not_emitted(controller, "statistics_changed")
	controller.free()


func test_disabled_persistence_never_reads_or_writes() -> void:
	var seeded = PlayerStatisticsScript.new()
	seeded.runs_started = 8
	var file := FileAccess.open(_statistics_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(seeded.to_dictionary()))
	file.close()
	var controller := _controller(false)

	assert_eq(controller.statistics().runs_started, 0)
	DirAccess.remove_absolute(_statistics_path)
	_play_run(controller, 50, true)
	controller.reset_statistics()

	assert_false(FileAccess.file_exists(_statistics_path))
	assert_eq(FileAccess.file_exists("user://claim_earth_statistics.json"), _default_path_existed)
	controller.free()


func test_unconfigured_controller_does_not_touch_disk() -> void:
	var controller = StatisticsControllerScript.new()
	_play_run(controller, 50, true)

	assert_eq(controller.statistics().runs_started, 1)
	assert_eq(FileAccess.file_exists("user://claim_earth_statistics.json"), _default_path_existed)
	controller.free()


func test_reset_clears_lifetime_totals_saves_and_emits() -> void:
	var controller := _controller(true)
	_play_run(controller, 50, true)
	controller.begin_run(WORLD_DEPTH)
	controller.record_item_used(2)
	controller.end_run()
	watch_signals(controller)

	controller.reset_statistics()

	assert_signal_emit_count(controller, "statistics_changed", 1)
	assert_eq(controller.statistics().to_dictionary(), PlayerStatisticsScript.new().to_dictionary())
	var reloaded := _controller(true)
	assert_eq(reloaded.statistics().to_dictionary(), PlayerStatisticsScript.new().to_dictionary())
	controller.free()
	reloaded.free()


func _controller(persistence_enabled: bool, with_rules: bool = true) -> StatisticsController:
	var controller = StatisticsControllerScript.new()
	if with_rules:
		controller.rules = StatisticsRulesScript.new()
	controller.configure(_statistics_path, persistence_enabled)
	return controller


func _play_run(controller: StatisticsController, depth: int, plant_flag: bool = false, death_cause: StringName = &"") -> void:
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(depth, 1.0)
	if plant_flag:
		controller.record_flag_planted(depth)
	elif not death_cause.is_empty():
		controller.record_death(death_cause)
	controller.end_run()


func _play_victory(controller: StatisticsController, seconds: float) -> void:
	controller.begin_run(WORLD_DEPTH)
	controller.record_progress(150, seconds)
	assert_true(controller.record_flag_planted(195))
	controller.end_run()


func _assert_streak(controller: StatisticsController, current: int, best: int) -> void:
	var data := controller.statistics()
	assert_eq(data.current_flag_streak, current, "current flag streak")
	assert_eq(data.best_flag_streak, best, "best flag streak")


func _remove_statistics() -> void:
	if FileAccess.file_exists(_statistics_path):
		DirAccess.remove_absolute(_statistics_path)
	if FileAccess.file_exists("%s.tmp" % _statistics_path):
		DirAccess.remove_absolute("%s.tmp" % _statistics_path)
