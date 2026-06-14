class_name SaveRepository
extends RefCounted


const SaveDataScript = preload("res://src/save/save_data.gd")

var _save_path := "user://claim_earth_save.json"


func configure(save_path: String) -> void:
	_save_path = save_path


func load_data() -> SaveData:
	if not FileAccess.file_exists(_save_path):
		return SaveDataScript.new()

	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return SaveDataScript.new()
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return SaveDataScript.new()
	var parsed: Variant = parser.data
	if parsed is not Dictionary:
		return SaveDataScript.new()
	return SaveDataScript.from_dictionary(parsed)


func save_data(data: SaveData) -> bool:
	var directory_path := _save_path.get_base_dir()
	if not directory_path.is_empty():
		DirAccess.make_dir_recursive_absolute(directory_path)
	var temp_path := "%s.tmp" % _save_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data.to_dictionary(), "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	var rename_error := DirAccess.rename_absolute(temp_path, _save_path)
	if rename_error != OK:
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return false
	return true


func storage_warning() -> String:
	if OS.is_userfs_persistent():
		return ""
	return "Browser storage is unavailable or temporary. Personal bests may reset after this session."
