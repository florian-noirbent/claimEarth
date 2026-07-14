extends GutTest


const AppSettingsControllerScript = preload("res://src/settings/app_settings_controller.gd")

var _settings_path := "user://gut_app_settings.json"


func before_each() -> void:
	_remove_settings()


func after_each() -> void:
	_remove_settings()


func test_missing_settings_uses_platform_default_without_override() -> void:
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)

	assert_false(controller.has_phone_controls_override())
	assert_eq(controller.phone_controls_enabled(), not OS.has_feature("editor") and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")))
	controller.free()


func test_explicit_phone_control_setting_persists() -> void:
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)
	controller.set_phone_controls_enabled(true)

	var reloaded = AppSettingsControllerScript.new()
	reloaded.configure(_settings_path)

	assert_true(reloaded.has_phone_controls_override())
	assert_true(reloaded.phone_controls_enabled())
	controller.free()
	reloaded.free()


func test_frame_limit_defaults_and_explicit_value_persist() -> void:
	assert_eq(AppSettingsControllerScript.default_frame_limit(true), 30)
	assert_eq(AppSettingsControllerScript.default_frame_limit(false), 0)
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)

	assert_false(controller.has_frame_limit_override())
	assert_eq(controller.frame_limit_fps(), 0)
	watch_signals(controller)
	for fps in [30, 60, 90, 120, 0]:
		controller.set_frame_limit_fps(fps)
		assert_eq(controller.frame_limit_fps(), fps)
		assert_signal_emitted_with_parameters(controller, "frame_limit_changed", [fps])

	var reloaded = AppSettingsControllerScript.new()
	reloaded.configure(_settings_path)
	assert_true(reloaded.has_frame_limit_override())
	assert_eq(reloaded.frame_limit_fps(), 0)
	controller.free()
	reloaded.free()


func test_invalid_persisted_frame_limit_falls_back_to_platform_default() -> void:
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 2,
		"frame_limit_override_set": true,
		"frame_limit_fps": 45,
	}))
	file.close()
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)

	assert_false(controller.has_frame_limit_override())
	assert_eq(controller.frame_limit_fps(), 0)
	controller.free()


func test_version_one_phone_preference_migrates_without_creating_a_frame_limit_override() -> void:
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1,
		"phone_controls_override_set": true,
		"phone_controls_override": true,
	}))
	file.close()
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)

	assert_true(controller.phone_controls_enabled())
	assert_false(controller.has_frame_limit_override())
	assert_eq(controller.frame_limit_fps(), 0)
	controller.set_frame_limit_fps(60)
	var migrated_source = JSON.parse_string(FileAccess.get_file_as_string(_settings_path))
	assert_eq(int(migrated_source["version"]), 2)
	assert_true(bool(migrated_source["phone_controls_override"]))
	controller.free()


func _remove_settings() -> void:
	if FileAccess.file_exists(_settings_path):
		DirAccess.remove_absolute(_settings_path)
	if FileAccess.file_exists("%s.tmp" % _settings_path):
		DirAccess.remove_absolute("%s.tmp" % _settings_path)
