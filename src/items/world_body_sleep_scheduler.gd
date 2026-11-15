## Delivers terrain wake checks to sleeping world bodies so resting chests and barrels run no physics steps.
class_name WorldBodySleepScheduler
extends RefCounted


var _sleeps: Array[WorldBodySleep] = []
var _due_times := PackedFloat64Array()
var _clock := 0.0
var _tick_interval := INF
var _next_tick_time := 0.0


## Lets the body sleep and takes over waking it when its watched terrain changes.
func track(sleep: WorldBodySleep) -> void:
	if sleep == null or not sleep.is_configured() or _sleeps.has(sleep):
		return
	_sleeps.append(sleep)
	_due_times.append(_clock)
	_tick_interval = minf(_tick_interval, sleep.grounded_check_interval())
	_next_tick_time = _clock
	sleep.set_enabled(true)


func clear() -> void:
	_sleeps.clear()
	_due_times.clear()
	_clock = 0.0
	_tick_interval = INF
	_next_tick_time = 0.0


func tracked_count() -> int:
	return _sleeps.size()


## Advances the wake clock; sleeping bodies whose check is due compare their watched terrain.
func advance(delta: float, view: Rect2) -> void:
	_clock += maxf(0.0, delta)
	if _sleeps.is_empty() or _clock < _next_tick_time:
		return
	_next_tick_time = _clock + _tick_interval
	for index in range(_sleeps.size() - 1, -1, -1):
		var sleep := _sleeps[index]
		if sleep.host() == null:
			_sleeps.remove_at(index)
			_due_times.remove_at(index)
			continue
		if not sleep.is_sleeping() or _clock < _due_times[index]:
			continue
		_due_times[index] = _clock + sleep.sleep_check_interval(view)
		sleep.wake_if_terrain_changed()


## Checks sleeping bodies that watch the changed cells at once, regardless of their check interval.
func notify_terrain_changed(changed_cells: Rect2i) -> void:
	if not changed_cells.has_area():
		return
	for sleep in _sleeps:
		if sleep.host() != null and sleep.is_sleeping() and sleep.watched_cells().intersects(changed_cells):
			sleep.wake_if_terrain_changed()
