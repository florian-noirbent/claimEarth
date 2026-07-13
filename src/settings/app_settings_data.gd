## Serializable user preferences kept separate from score persistence.
class_name AppSettingsData
extends RefCounted


const CURRENT_VERSION := 1

var version := CURRENT_VERSION
var phone_controls_override_set := false
var phone_controls_override := false


static func from_dictionary(source: Dictionary) -> AppSettingsData:
	var data := AppSettingsData.new()
	data.version = int(source.get("version", CURRENT_VERSION))
	data.phone_controls_override_set = bool(source.get("phone_controls_override_set", false))
	data.phone_controls_override = bool(source.get("phone_controls_override", false))
	return data


func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"phone_controls_override_set": phone_controls_override_set,
		"phone_controls_override": phone_controls_override,
	}
