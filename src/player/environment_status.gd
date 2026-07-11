## Tracks independently filling and recovering player hazard meters.
class_name EnvironmentStatus
extends RefCounted

const DeathCauseScript = preload("res://src/player/death_cause.gd")
const HazardStatusScript = preload("res://src/player/hazard_status.gd")

var _meters := {}


func evaluate(effects: Array, delta: float) -> StringName:
	var active_effects := {}
	for effect in effects:
		if effect == null or effect.cause == DeathCauseScript.NONE:
			continue
		if effect.fill_seconds <= 0.0 or effect.recovery_seconds <= 0.0:
			continue
		if not active_effects.has(effect.cause) or effect.fill_rate_multiplier > active_effects[effect.cause].fill_rate_multiplier:
			active_effects[effect.cause] = effect

	var death_cause := DeathCauseScript.NONE
	for cause_variant in active_effects.keys():
		var cause := cause_variant as StringName
		var effect: Variant = active_effects[cause]
		var meter: _HazardMeter = _meter_for(effect)
		meter.level = minf(1.0, meter.level + maxf(0.0, delta) * effect.fill_rate_multiplier / effect.fill_seconds)
		meter.is_active = true
		if meter.level >= 1.0 and death_cause == DeathCauseScript.NONE:
			death_cause = cause

	for cause_variant in _meters.keys():
		var cause := cause_variant as StringName
		if active_effects.has(cause):
			continue
		var meter: _HazardMeter = _meters[cause]
		meter.level = maxf(0.0, meter.level - maxf(0.0, delta) / meter.effect.recovery_seconds)
		meter.is_active = false

	return death_cause


func statuses() -> Array:
	var result: Array = []
	for meter in _meters.values():
		if meter.level > 0.0:
			result.append(HazardStatusScript.new(meter.effect, meter.level, meter.is_active))
	result.sort_custom(func(a, b) -> bool:
		if a.display_order == b.display_order:
			return String(a.cause) < String(b.cause)
		return a.display_order < b.display_order
	)
	return result


func reset() -> void:
	_meters.clear()


func _meter_for(effect) -> _HazardMeter:
	if _meters.has(effect.cause):
		var existing: _HazardMeter = _meters[effect.cause]
		existing.effect = effect
		return existing
	var meter: _HazardMeter = _HazardMeter.new()
	meter.effect = effect
	_meters[effect.cause] = meter
	return meter


class _HazardMeter:
	var effect
	var level := 0.0
	var is_active := false
