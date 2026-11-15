## Delivers terrain wake checks to sleeping item chests so resting containers run no physics steps.
class_name ItemChestSleepScheduler
extends RefCounted


var _chests: Array[ItemChest] = []
var _due_times := PackedFloat64Array()
var _clock := 0.0
var _tick_interval := INF
var _next_tick_time := 0.0


## Lets the chest sleep and takes over waking it when its watched terrain changes.
func track(chest: ItemChest) -> void:
	if chest == null or chest.spawn_data == null or chest.spawn_data.definition == null or _chests.has(chest):
		return
	_chests.append(chest)
	_due_times.append(_clock)
	_tick_interval = minf(_tick_interval, chest.spawn_data.definition.grounded_check_interval_seconds)
	_next_tick_time = _clock
	chest.set_sleep_enabled(true)


func clear() -> void:
	_chests.clear()
	_due_times.clear()
	_clock = 0.0
	_tick_interval = INF
	_next_tick_time = 0.0


func tracked_count() -> int:
	return _chests.size()


## Advances the wake clock; sleeping chests whose check is due compare their watched terrain.
func advance(delta: float, view: Rect2) -> void:
	_clock += maxf(0.0, delta)
	if _chests.is_empty() or _clock < _next_tick_time:
		return
	_next_tick_time = _clock + _tick_interval
	for index in range(_chests.size() - 1, -1, -1):
		var chest := _tracked_chest(index)
		if chest == null:
			_chests.remove_at(index)
			_due_times.remove_at(index)
			continue
		if not chest.is_sleeping() or _clock < _due_times[index]:
			continue
		_due_times[index] = _clock + chest.sleep_check_interval(view)
		chest.wake_if_terrain_changed()


## Checks sleeping chests that watch the changed cells at once, regardless of their check interval.
func notify_terrain_changed(changed_cells: Rect2i) -> void:
	if not changed_cells.has_area():
		return
	for index in _chests.size():
		var chest := _tracked_chest(index)
		if chest != null and chest.is_sleeping() and chest.watched_cells().intersects(changed_cells):
			chest.wake_if_terrain_changed()


func _tracked_chest(index: int) -> ItemChest:
	var entry: Variant = _chests[index]
	if not is_instance_valid(entry):
		return null
	var chest := entry as ItemChest
	return null if chest.is_queued_for_deletion() else chest
