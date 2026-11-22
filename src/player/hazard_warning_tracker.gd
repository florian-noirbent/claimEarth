## Rate-limits warning cues for hazard meters that keep filling above a warning level.
class_name HazardWarningTracker
extends RefCounted


var _cooldowns := {}


## Returns the statuses due a warning this step: active meters at or above the level
## whose previous warning is at least the repeat interval old.
func advance(statuses: Array, delta: float, warning_level: float, repeat_seconds: float) -> Array[HazardStatus]:
	for cause in _cooldowns.keys():
		_cooldowns[cause] = float(_cooldowns[cause]) - maxf(0.0, delta)
		if _cooldowns[cause] <= 0.0:
			_cooldowns.erase(cause)
	var due: Array[HazardStatus] = []
	for status_value in statuses:
		var status := status_value as HazardStatus
		if status == null or not status.is_active or status.level < warning_level:
			continue
		if _cooldowns.has(status.cause):
			continue
		_cooldowns[status.cause] = repeat_seconds
		due.append(status)
	return due


func reset() -> void:
	_cooldowns.clear()
