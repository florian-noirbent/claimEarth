## Owns persisted app preferences and resolves the platform-derived default.
class_name AppSettingsController
extends Node


signal phone_controls_changed(enabled: bool)
signal frame_limit_changed(fps: int)


const AppSettingsRepositoryScript = preload("res://src/settings/app_settings_repository.gd")
const AppSettingsDataScript = preload("res://src/settings/app_settings_data.gd")

var _repository: AppSettingsRepository = AppSettingsRepositoryScript.new()
var _data: AppSettingsData = AppSettingsDataScript.new()
var _configured := false


func configure(settings_path: String = "") -> void:
	if not settings_path.is_empty():
		_repository.configure(settings_path)
	_data = _repository.load_data()
	_configured = true
	phone_controls_changed.emit(phone_controls_enabled())
	frame_limit_changed.emit(frame_limit_fps())


func configure_settings_path(settings_path: String) -> void:
	_repository.configure(settings_path)


func configure_save_path(settings_path: String) -> void:
	_repository.configure(settings_path)


func phone_controls_enabled() -> bool:
	if _data.phone_controls_override_set:
		return _data.phone_controls_override
	return _is_mobile_runtime()


func set_phone_controls_enabled(enabled: bool) -> void:
	if not _configured:
		configure()
	if _data.phone_controls_override_set and _data.phone_controls_override == enabled:
		return
	_data.phone_controls_override_set = true
	_data.phone_controls_override = enabled
	_repository.save_data(_data)
	phone_controls_changed.emit(enabled)


func has_phone_controls_override() -> bool:
	return _data.phone_controls_override_set


func frame_limit_fps() -> int:
	if _data.frame_limit_override_set and _data.frame_limit_fps in AppSettingsDataScript.VALID_FRAME_LIMITS:
		return _data.frame_limit_fps
	return default_frame_limit(_is_mobile_runtime())


func set_frame_limit_fps(fps: int) -> void:
	if fps not in AppSettingsDataScript.VALID_FRAME_LIMITS:
		push_error("Unsupported frame limit: %d" % fps)
		return
	if not _configured:
		configure()
	if _data.frame_limit_override_set and _data.frame_limit_fps == fps:
		return
	_data.frame_limit_override_set = true
	_data.frame_limit_fps = fps
	_repository.save_data(_data)
	frame_limit_changed.emit(fps)


func has_frame_limit_override() -> bool:
	return _data.frame_limit_override_set


static func default_frame_limit(is_mobile_runtime: bool) -> int:
	return 30 if is_mobile_runtime else 0


func _is_mobile_runtime() -> bool:
	return not OS.has_feature("editor") and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))
