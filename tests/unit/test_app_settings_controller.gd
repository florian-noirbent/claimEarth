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


func _remove_settings() -> void:
	if FileAccess.file_exists(_settings_path):
		DirAccess.remove_absolute(_settings_path)
	if FileAccess.file_exists("%s.tmp" % _settings_path):
		DirAccess.remove_absolute("%s.tmp" % _settings_path)
