extends GutTest


const StatisticsRepositoryScript = preload("res://src/statistics/statistics_repository.gd")
const PlayerStatisticsScript = preload("res://src/statistics/player_statistics.gd")

var _statistics_path := "user://gut_statistics_repository.json"


func before_each() -> void:
	_remove_statistics()


func after_each() -> void:
	_remove_statistics()


func test_default_path_is_separate_from_scores_and_settings() -> void:
	var repository = StatisticsRepositoryScript.new()

	assert_eq(repository.statistics_path(), "user://claim_earth_statistics.json")


func test_missing_statistics_returns_defaults() -> void:
	var repository = StatisticsRepositoryScript.new()
	repository.configure(_statistics_path)

	var data = repository.load_data()

	assert_eq(data.to_dictionary(), PlayerStatisticsScript.new().to_dictionary())


func test_statistics_round_trip_persists_totals_and_counters() -> void:
	var repository = StatisticsRepositoryScript.new()
	repository.configure(_statistics_path)
	var data = PlayerStatisticsScript.new()
	data.runs_started = 5
	data.games_played = 3
	data.victories = 1
	data.total_play_seconds = 98.5
	data.fastest_victory_seconds = 40.25
	data.item_uses = {"4": 11}
	data.containers_opened = {"perk_geode": 2}
	data.deaths_by_cause = {"suffocation": 1}

	assert_true(repository.save_data(data))
	assert_false(FileAccess.file_exists("%s.tmp" % _statistics_path))

	var reloaded = repository.load_data()
	assert_eq(reloaded.to_dictionary(), data.to_dictionary())
	assert_eq(PlayerStatisticsScript.count_in(reloaded.item_uses, 4), 11)


func test_save_overwrites_previous_statistics() -> void:
	var repository = StatisticsRepositoryScript.new()
	repository.configure(_statistics_path)
	var first = PlayerStatisticsScript.new()
	first.runs_started = 1
	first.item_uses = {"1": 1}
	var second = PlayerStatisticsScript.new()
	second.runs_started = 2

	assert_true(repository.save_data(first))
	assert_true(repository.save_data(second))

	var reloaded = repository.load_data()
	assert_eq(reloaded.runs_started, 2)
	assert_eq(reloaded.item_uses.size(), 0)


func test_corrupt_statistics_fall_back_to_defaults() -> void:
	_write_raw("{ definitely not json")
	var repository = StatisticsRepositoryScript.new()
	repository.configure(_statistics_path)

	var data = repository.load_data()

	assert_eq(data.to_dictionary(), PlayerStatisticsScript.new().to_dictionary())


func test_non_dictionary_json_falls_back_to_defaults() -> void:
	_write_raw("[1, 2, 3]")
	var repository = StatisticsRepositoryScript.new()
	repository.configure(_statistics_path)

	var data = repository.load_data()

	assert_eq(data.runs_started, 0)
	assert_eq(data.item_uses.size(), 0)


func test_partially_invalid_file_keeps_valid_fields() -> void:
	_write_raw(JSON.stringify({
		"runs_started": 4,
		"games_played": -1,
		"item_picks": {"2": 3, "5": "bad"},
	}))
	var repository = StatisticsRepositoryScript.new()
	repository.configure(_statistics_path)

	var data = repository.load_data()

	assert_eq(data.runs_started, 4)
	assert_eq(data.games_played, 0)
	assert_eq(data.item_picks, {"2": 3})


func _write_raw(text: String) -> void:
	var file := FileAccess.open(_statistics_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_statistics() -> void:
	if FileAccess.file_exists(_statistics_path):
		DirAccess.remove_absolute(_statistics_path)
	if FileAccess.file_exists("%s.tmp" % _statistics_path):
		DirAccess.remove_absolute("%s.tmp" % _statistics_path)
