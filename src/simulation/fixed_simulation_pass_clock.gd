## Accumulates a frame-rate-independent budget of terrain simulation passes.
class_name FixedSimulationPassClock
extends RefCounted


const PASSES_PER_SECOND := 60.0
const WHOLE_PASS_EPSILON := 0.000001

var _pass_debt := 0.0


func add_time(delta_seconds: float) -> void:
	_pass_debt += maxf(0.0, delta_seconds) * PASSES_PER_SECOND


func available_passes(maximum: int) -> int:
	if maximum <= 0:
		return 0
	return mini(maximum, floori(_pass_debt + WHOLE_PASS_EPSILON))


func consume(pass_count: int) -> void:
	_pass_debt = maxf(0.0, _pass_debt - maxi(0, pass_count))


func reset() -> void:
	_pass_debt = 0.0


func pending_passes() -> float:
	return _pass_debt
