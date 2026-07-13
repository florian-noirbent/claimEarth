extends GutTest


func test_web_export_uses_canonical_all_resources_mode() -> void:
	var preset := ConfigFile.new()
	assert_eq(preset.load("res://export_presets.cfg"), OK)

	assert_eq(preset.get_value("preset.0", "platform", ""), "Web")
	assert_eq(preset.get_value("preset.0", "export_filter", ""), "all_resources")
	var export_files := preset.get_value(
		"preset.0", "export_files", PackedStringArray()
	) as PackedStringArray
	assert_true(export_files.is_empty(), "Canonical export must not maintain a file list.")
	assert_eq(preset.get_value("preset.0", "include_filter", ""), "")
	assert_eq(preset.get_value("preset.0", "exclude_filter", ""), "")


func test_generated_build_directory_is_ignored_by_godot() -> void:
	assert_true(
		FileAccess.file_exists("res://build/.gdignore"),
		"build/.gdignore must prevent generated exports and browser profiles from being imported.",
	)
