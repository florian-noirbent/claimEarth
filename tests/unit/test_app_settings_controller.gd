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
	assert_eq(int(migrated_source["version"]), AppSettingsData.CURRENT_VERSION)
	assert_true(bool(migrated_source["phone_controls_override"]))
	controller.free()


func _remove_settings() -> void:
	if FileAccess.file_exists(_settings_path):
		DirAccess.remove_absolute(_settings_path)
	if FileAccess.file_exists("%s.tmp" % _settings_path):
		DirAccess.remove_absolute("%s.tmp" % _settings_path)


func test_volume_and_shake_default_to_full_and_round_trip() -> void:
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)
	for channel in AppSettingsData.VOLUME_CHANNELS:
		assert_eq(controller.volume(channel), 1.0)
	assert_eq(controller.screen_shake(), 1.0)
	watch_signals(controller)

	controller.set_volume(AppSettingsData.VOLUME_MASTER, 0.8)
	controller.set_volume(AppSettingsData.VOLUME_SFX, 0.35)
	controller.set_volume(AppSettingsData.VOLUME_MUSIC, 0.0)
	controller.set_screen_shake(1.5)
	assert_signal_emitted_with_parameters(controller, "volume_changed", [AppSettingsData.VOLUME_MUSIC, 0.0])
	assert_signal_emitted_with_parameters(controller, "screen_shake_changed", [1.5])
	controller.set_volume(AppSettingsData.VOLUME_MUSIC, 0.0)
	controller.set_screen_shake(1.5)
	assert_signal_emit_count(controller, "volume_changed", 3, "An unchanged value is not reported again.")
	assert_signal_emit_count(controller, "screen_shake_changed", 1)

	var reloaded = AppSettingsControllerScript.new()
	reloaded.configure(_settings_path)
	assert_almost_eq(reloaded.volume(AppSettingsData.VOLUME_MASTER), 0.8, 0.0001)
	assert_almost_eq(reloaded.volume(AppSettingsData.VOLUME_SFX), 0.35, 0.0001)
	assert_eq(reloaded.volume(AppSettingsData.VOLUME_MUSIC), 0.0)
	assert_almost_eq(reloaded.screen_shake(), 1.5, 0.0001)
	assert_false(reloaded.has_phone_controls_override(), "Feedback settings do not create other overrides.")
	assert_false(reloaded.has_frame_limit_override())
	controller.free()
	reloaded.free()


func test_volume_and_shake_are_clamped_to_their_ranges() -> void:
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)

	controller.set_volume(AppSettingsData.VOLUME_SFX, 1.7)
	assert_eq(controller.volume(AppSettingsData.VOLUME_SFX), 1.0)
	controller.set_volume(AppSettingsData.VOLUME_SFX, -0.4)
	assert_eq(controller.volume(AppSettingsData.VOLUME_SFX), 0.0)
	controller.set_screen_shake(9.0)
	assert_eq(controller.screen_shake(), AppSettingsData.MAX_SCREEN_SHAKE)
	controller.set_screen_shake(-1.0)
	assert_eq(controller.screen_shake(), 0.0)
	controller.free()


func test_version_two_settings_migrate_with_default_volume_and_shake() -> void:
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 2,
		"phone_controls_override_set": true,
		"phone_controls_override": true,
		"frame_limit_override_set": true,
		"frame_limit_fps": 60,
	}))
	file.close()
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)

	assert_true(controller.phone_controls_enabled())
	assert_eq(controller.frame_limit_fps(), 60)
	for channel in AppSettingsData.VOLUME_CHANNELS:
		assert_eq(controller.volume(channel), AppSettingsData.DEFAULT_VOLUME)
	assert_eq(controller.screen_shake(), AppSettingsData.DEFAULT_SCREEN_SHAKE)

	controller.set_volume(AppSettingsData.VOLUME_MUSIC, 0.5)
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_settings_path))
	assert_eq(int(migrated["version"]), 3)
	assert_eq(int(migrated["frame_limit_fps"]), 60)
	assert_true(bool(migrated["phone_controls_override"]))
	assert_almost_eq(float(migrated["music_volume"]), 0.5, 0.0001)
	assert_almost_eq(float(migrated["master_volume"]), 1.0, 0.0001)
	assert_almost_eq(float(migrated["sfx_volume"]), 1.0, 0.0001)
	assert_almost_eq(float(migrated["screen_shake"]), 1.0, 0.0001)
	controller.free()


func test_invalid_persisted_volume_and_shake_fall_back_or_clamp() -> void:
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 3,
		"master_volume": "loud",
		"sfx_volume": 4.0,
		"music_volume": -2,
		"screen_shake": [1.0],
	}))
	file.close()
	var controller = AppSettingsControllerScript.new()
	controller.configure(_settings_path)

	assert_eq(controller.volume(AppSettingsData.VOLUME_MASTER), 1.0, "A non-number falls back to the default.")
	assert_eq(controller.volume(AppSettingsData.VOLUME_SFX), 1.0, "A number is clamped.")
	assert_eq(controller.volume(AppSettingsData.VOLUME_MUSIC), 0.0)
	assert_eq(controller.screen_shake(), 1.0)
	controller.free()
