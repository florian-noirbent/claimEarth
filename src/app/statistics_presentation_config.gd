## Icons and labels used to present lifetime statistics.
class_name StatisticsPresentationConfig
extends Resource


@export var runs_icon: Texture2D
@export var flag_icon: Texture2D
@export var victory_icon: Texture2D
@export var streak_icon: Texture2D
@export var time_icon: Texture2D
@export var depth_icon: Texture2D
@export var distance_icon: Texture2D
@export var death_icon: Texture2D
@export var item_icon: Texture2D
@export var perk_icon: Texture2D
## Fallback for keys that have no presentation entry.
@export var unknown_icon: Texture2D
@export var death_causes: Array[StatisticKeyPresentation] = []
@export var flag_loss_causes: Array[StatisticKeyPresentation] = []
@export var containers: Array[StatisticKeyPresentation] = []
@export var destroyed_containers: Array[StatisticKeyPresentation] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var icons := {
		"runs_icon": runs_icon,
		"flag_icon": flag_icon,
		"victory_icon": victory_icon,
		"streak_icon": streak_icon,
		"time_icon": time_icon,
		"depth_icon": depth_icon,
		"distance_icon": distance_icon,
		"death_icon": death_icon,
		"item_icon": item_icon,
		"perk_icon": perk_icon,
		"unknown_icon": unknown_icon,
	}
	for icon_name: String in icons:
		if icons[icon_name] == null:
			errors.append("statistics presentation requires %s" % icon_name)
	_validate_entries("death_causes", death_causes, errors)
	_validate_entries("flag_loss_causes", flag_loss_causes, errors)
	_validate_entries("containers", containers, errors)
	_validate_entries("destroyed_containers", destroyed_containers, errors)
	return errors


## Returns the presentation registered for a key, or null when absent.
func presentation_for(entries: Array[StatisticKeyPresentation], key: StringName) -> StatisticKeyPresentation:
	for entry in entries:
		if entry != null and entry.key == key:
			return entry
	return null


func _validate_entries(list_name: String, entries: Array[StatisticKeyPresentation], errors: PackedStringArray) -> void:
	var seen := {}
	for entry in entries:
		if entry == null:
			errors.append("%s contains an empty entry" % list_name)
			continue
		for error in entry.validate():
			errors.append("%s: %s" % [list_name, error])
		if seen.has(entry.key):
			errors.append("%s contains duplicate key '%s'" % [list_name, entry.key])
		seen[entry.key] = true
