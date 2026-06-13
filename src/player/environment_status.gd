class_name EnvironmentStatus
extends RefCounted

const DeathCauseScript = preload("res://src/player/death_cause.gd")

var _timers := {}


func evaluate(effects: Array, delta: float) -> StringName:
	var active_causes := {}
	for effect in effects:
		if effect == null or effect.cause == DeathCauseScript.NONE:
			continue
		active_causes[effect.cause] = true
		if effect.lethal_on_touch:
			return effect.cause
		if effect.exposure_seconds > 0.0:
			var next_value: float = float(_timers.get(effect.cause, 0.0)) + delta
			_timers[effect.cause] = next_value
			if next_value >= effect.exposure_seconds:
				return effect.cause

	for cause_variant in _timers.keys():
		var cause := cause_variant as StringName
		if not active_causes.has(cause):
			_timers[cause] = 0.0

	return DeathCauseScript.NONE


func reset() -> void:
	_timers.clear()
