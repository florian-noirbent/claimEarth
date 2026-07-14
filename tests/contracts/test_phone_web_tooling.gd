extends GutTest


func test_phone_launcher_stops_its_managed_server_after_debugging() -> void:
	var launch_config := _read_json_object("res://.vscode/launch.json")
	var task_config := _read_json_object("res://.vscode/tasks.json")
	var phone_launcher := _find_named_entry(
		launch_config.get("configurations", []),
		"name",
		"Launch Phone Web Test (HTTPS + QR)",
	)
	var stop_task := _find_named_entry(
		task_config.get("tasks", []),
		"label",
		"Stop Phone Web Server",
	)

	assert_false(phone_launcher.is_empty(), "The phone Web launch configuration must exist.")
	assert_false(stop_task.is_empty(), "The managed phone Web stop task must exist.")
	assert_eq(
		phone_launcher.get("postDebugTask", ""),
		stop_task.get("label", ""),
		"Stopping the phone launch session must invoke the managed server cleanup task.",
	)


func _read_json_object(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_typeof(parsed, TYPE_DICTIONARY, "%s must contain a JSON object." % path)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _find_named_entry(entries: Variant, key: String, value: String) -> Dictionary:
	if not entries is Array:
		return {}
	for entry: Variant in entries as Array:
		if entry is Dictionary and entry.get(key, "") == value:
			return entry as Dictionary
	return {}
