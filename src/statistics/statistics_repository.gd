## Reads and writes lifetime player statistics under user storage with corrupt-data fallback.
class_name StatisticsRepository
extends RefCounted


const PlayerStatisticsScript = preload("res://src/statistics/player_statistics.gd")

var _statistics_path := "user://claim_earth_statistics.json"


func configure(statistics_path: String) -> void:
	_statistics_path = statistics_path


func statistics_path() -> String:
	return _statistics_path


func load_data() -> PlayerStatistics:
	if not FileAccess.file_exists(_statistics_path):
		return PlayerStatisticsScript.new()
	var file := FileAccess.open(_statistics_path, FileAccess.READ)
	if file == null:
		return PlayerStatisticsScript.new()
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return PlayerStatisticsScript.new()
	var parsed: Variant = parser.data
	if parsed is not Dictionary:
		return PlayerStatisticsScript.new()
	return PlayerStatisticsScript.from_dictionary(parsed)


func save_data(data: PlayerStatistics) -> bool:
	var directory_path := _statistics_path.get_base_dir()
	if not directory_path.is_empty():
		DirAccess.make_dir_recursive_absolute(directory_path)
	var temp_path := "%s.tmp" % _statistics_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data.to_dictionary(), "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(_statistics_path):
		DirAccess.remove_absolute(_statistics_path)
	var rename_error := DirAccess.rename_absolute(temp_path, _statistics_path)
	if rename_error != OK:
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return false
	return true
