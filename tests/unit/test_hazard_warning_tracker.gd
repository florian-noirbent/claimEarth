extends GutTest


const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")


func test_warning_is_due_once_an_active_meter_reaches_the_level() -> void:
	var tracker := HazardWarningTracker.new()

	assert_eq(tracker.advance([_status(&"cooked", 0.59, true)], 0.1, 0.6, 1.0).size(), 0)
	var due := tracker.advance([_status(&"cooked", 0.6, true)], 0.1, 0.6, 1.0)

	assert_eq(due.size(), 1)
	assert_eq(due[0].cause, &"cooked")


func test_warning_repeats_only_after_the_repeat_interval() -> void:
	var tracker := HazardWarningTracker.new()
	var statuses := [_status(&"cooked", 0.8, true)]

	assert_eq(tracker.advance(statuses, 0.25, 0.6, 1.0).size(), 1)
	assert_eq(tracker.advance(statuses, 0.5, 0.6, 1.0).size(), 0)
	assert_eq(tracker.advance(statuses, 0.25, 0.6, 1.0).size(), 0)
	assert_eq(tracker.advance(statuses, 0.25, 0.6, 1.0).size(), 1)


func test_recovering_meters_never_warn_and_causes_are_limited_separately() -> void:
	var tracker := HazardWarningTracker.new()

	assert_eq(tracker.advance([_status(&"cooked", 0.9, false)], 0.1, 0.6, 1.0).size(), 0)
	assert_eq(tracker.advance([_status(&"cooked", 0.9, true)], 0.1, 0.6, 1.0).size(), 1)
	var due := tracker.advance([_status(&"cooked", 0.9, true), _status(&"acid", 0.7, true)], 0.1, 0.6, 1.0)

	assert_eq(due.size(), 1)
	assert_eq(due[0].cause, &"acid")
	tracker.reset()
	assert_eq(tracker.advance([_status(&"cooked", 0.9, true)], 0.1, 0.6, 1.0).size(), 1)


func _status(cause: StringName, level: float, active: bool) -> HazardStatus:
	var effect := HazardEffectScript.new() as HazardEffect
	effect.cause = cause
	return HazardStatus.new(effect, level, active)
