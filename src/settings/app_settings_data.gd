## Serializable user preferences kept separate from score persistence.
class_name AppSettingsData
extends RefCounted


const CURRENT_VERSION := 2
const VALID_FRAME_LIMITS := [0, 30, 60, 90, 120]

var version := CURRENT_VERSION
var phone_controls_override_set := false
var phone_controls_override := false
var frame_limit_override_set := false
var frame_limit_fps := 0


static func from_dictionary(source: Dictionary) -> AppSettingsData:
	var data := AppSettingsData.new()
	data.version = CURRENT_VERSION
	data.phone_controls_override_set = bool(source.get("phone_controls_override_set", false))
	data.phone_controls_override = bool(source.get("phone_controls_override", false))
	var loaded_frame_limit := int(source.get("frame_limit_fps", 0))
	data.frame_limit_override_set = bool(source.get("frame_limit_override_set", false)) and loaded_frame_limit in VALID_FRAME_LIMITS
	data.frame_limit_fps = loaded_frame_limit if loaded_frame_limit in VALID_FRAME_LIMITS else 0
	return data


func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"phone_controls_override_set": phone_controls_override_set,
		"phone_controls_override": phone_controls_override,
		"frame_limit_override_set": frame_limit_override_set,
		"frame_limit_fps": frame_limit_fps,
	}
