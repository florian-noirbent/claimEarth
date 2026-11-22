## Serializable user preferences kept separate from score persistence.
class_name AppSettingsData
extends RefCounted


const CURRENT_VERSION := 3
const VALID_FRAME_LIMITS := [0, 30, 60, 90, 120]
const VOLUME_MASTER := &"master"
const VOLUME_SFX := &"sfx"
const VOLUME_MUSIC := &"music"
const VOLUME_CHANNELS: Array[StringName] = [VOLUME_MASTER, VOLUME_SFX, VOLUME_MUSIC]
const DEFAULT_VOLUME := 1.0
const DEFAULT_SCREEN_SHAKE := 1.0
const MAX_SCREEN_SHAKE := 2.0

var version := CURRENT_VERSION
var phone_controls_override_set := false
var phone_controls_override := false
var frame_limit_override_set := false
var frame_limit_fps := 0
## Slider share from 0 to 1 per VOLUME_* channel.
var volumes: Dictionary[StringName, float] = {
	VOLUME_MASTER: DEFAULT_VOLUME,
	VOLUME_SFX: DEFAULT_VOLUME,
	VOLUME_MUSIC: DEFAULT_VOLUME,
}
## Camera shake strength from 0 (off) to MAX_SCREEN_SHAKE; 1 is the authored strength.
var screen_shake := DEFAULT_SCREEN_SHAKE


static func from_dictionary(source: Dictionary) -> AppSettingsData:
	var data := AppSettingsData.new()
	data.version = CURRENT_VERSION
	data.phone_controls_override_set = bool(source.get("phone_controls_override_set", false))
	data.phone_controls_override = bool(source.get("phone_controls_override", false))
	var loaded_frame_limit := int(source.get("frame_limit_fps", 0))
	data.frame_limit_override_set = bool(source.get("frame_limit_override_set", false)) and loaded_frame_limit in VALID_FRAME_LIMITS
	data.frame_limit_fps = loaded_frame_limit if loaded_frame_limit in VALID_FRAME_LIMITS else 0
	for channel in VOLUME_CHANNELS:
		data.volumes[channel] = _share(source.get(volume_key(channel)), DEFAULT_VOLUME, 1.0)
	data.screen_shake = _share(source.get("screen_shake"), DEFAULT_SCREEN_SHAKE, MAX_SCREEN_SHAKE)
	return data


## The stored field name of a volume channel.
static func volume_key(channel: StringName) -> String:
	return "%s_volume" % channel


## Reads a stored number clamped to 0..maximum; anything else falls back to the default.
static func _share(value: Variant, default_value: float, maximum: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return default_value
	return clampf(float(value), 0.0, maximum)


func to_dictionary() -> Dictionary:
	var result := {
		"version": version,
		"phone_controls_override_set": phone_controls_override_set,
		"phone_controls_override": phone_controls_override,
		"frame_limit_override_set": frame_limit_override_set,
		"frame_limit_fps": frame_limit_fps,
		"screen_shake": screen_shake,
	}
	for channel in VOLUME_CHANNELS:
		result[volume_key(channel)] = volumes[channel]
	return result
