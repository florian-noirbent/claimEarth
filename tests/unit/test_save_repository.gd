extends GutTest


const SaveRepositoryScript = preload("res://src/save/save_repository.gd")
const SaveDataScript = preload("res://src/save/save_data.gd")

var _save_path := "user://gut_claim_earth_save.json"


func before_each() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists("%s.tmp" % _save_path):
		DirAccess.remove_absolute("%s.tmp" % _save_path)


func test_missing_save_returns_defaults() -> void:
	var repository = SaveRepositoryScript.new()
	repository.configure(_save_path)

	var save_data = repository.load_data()

	assert_eq(save_data.last_player_name, "Player")
	assert_eq(save_data.personal_best_depth, -1)
	assert_eq(save_data.pending_submissions.size(), 0)


func test_save_roundtrip_persists_name_and_best() -> void:
	var repository = SaveRepositoryScript.new()
	repository.configure(_save_path)
	var save_data = SaveDataScript.new()
	save_data.last_player_name = "Florian"
	save_data.personal_best_depth = 87
	save_data.pending_submissions.append({"player_name": "Florian", "depth": 87})

	assert_true(repository.save_data(save_data))

	var reloaded = repository.load_data()
	assert_eq(reloaded.last_player_name, "Florian")
	assert_eq(reloaded.personal_best_depth, 87)
	assert_eq(reloaded.pending_submissions.size(), 1)


func test_corrupt_save_falls_back_to_defaults() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	file.store_string("{ definitely not json")
	file.close()

	var repository = SaveRepositoryScript.new()
	repository.configure(_save_path)
	var save_data = repository.load_data()

	assert_eq(save_data.last_player_name, "Player")
	assert_eq(save_data.personal_best_depth, -1)
