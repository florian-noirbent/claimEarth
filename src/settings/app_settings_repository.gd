## Reads and writes user preferences under user storage with corrupt-data fallback.
class_name AppSettingsRepository
extends RefCounted


const AppSettingsDataScript = preload("res://src/settings/app_settings_data.gd")

var _settings_path := "user://claim_earth_settings.json"


func configure(settings_path: String) -> void:
	_settings_path = settings_path


func load_data() -> AppSettingsData:
	if not FileAccess.file_exists(_settings_path):
		return AppSettingsDataScript.new()
	var file := FileAccess.open(_settings_path, FileAccess.READ)
	if file == null:
		return AppSettingsDataScript.new()
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not (parser.data is Dictionary):
		return AppSettingsDataScript.new()
	return AppSettingsDataScript.from_dictionary(parser.data as Dictionary)


func save_data(data: AppSettingsData) -> bool:
	var directory_path := _settings_path.get_base_dir()
	if not directory_path.is_empty():
		DirAccess.make_dir_recursive_absolute(directory_path)
	var temporary_path := "%s.tmp" % _settings_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data.to_dictionary(), "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(_settings_path):
		DirAccess.remove_absolute(_settings_path)
	if DirAccess.rename_absolute(temporary_path, _settings_path) == OK:
		return true
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)
	return false
