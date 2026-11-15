@tool
## Sleep state that a resting terrain-aware world body shares with the sleep scheduler.
class_name WorldBodySleep
extends RefCounted


## Emitted when a sleeping body must resume its physics steps.
signal woken

var _host_ref: WeakRef
var _grounded_check_interval := INF
var _offscreen_check_interval := INF
var _stuck_check_interval := INF
var _screen_margin := 0.0
var _enabled := false
var _sleeping := false
var _stuck := false
var _watch := TerrainRegionWatch.new()


## Sets the body whose position selects the check interval and the intervals in seconds.
## The screen margin is in world units. Reconfiguring keeps the enabled flag and ends sleep.
func configure(
	host: Node2D,
	grounded_check_interval: float,
	offscreen_check_interval: float,
	stuck_check_interval: float,
	screen_margin: float
) -> void:
	_host_ref = weakref(host) if host != null else null
	_grounded_check_interval = grounded_check_interval
	_offscreen_check_interval = offscreen_check_interval
	_stuck_check_interval = stuck_check_interval
	_screen_margin = screen_margin
	_sleeping = false
	_stuck = false


## Returns the owning body while it remains in the world, otherwise null.
func host() -> Node2D:
	var body := _host_ref.get_ref() as Node2D if _host_ref != null else null
	return null if body == null or body.is_queued_for_deletion() else body


func is_configured() -> bool:
	return host() != null and is_finite(_grounded_check_interval) and _grounded_check_interval > 0.0


func grounded_check_interval() -> float:
	return _grounded_check_interval


## Lets the resting body stop its physics steps; the caller must then deliver terrain wake checks.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		wake()


func is_enabled() -> bool:
	return _enabled


func is_sleeping() -> bool:
	return _sleeping


## Starts sleeping and remembers the terrain the last resting step read.
## Flagging Air makes fluid or gas arriving in an empty cell count as a change.
func fall_asleep(query: TerrainCollisionQuery, bounds: Rect2, include_air: bool, stuck: bool) -> void:
	_sleeping = true
	_stuck = stuck
	_watch.capture(query, bounds, include_air)


## Returns the offset-cell range a sleeping body depends on.
func watched_cells() -> Rect2i:
	return _watch.cells()


## Returns how long a sleeping body may wait before its watched terrain is read again.
func sleep_check_interval(view: Rect2) -> float:
	var interval := _grounded_check_interval
	if _stuck:
		interval = maxf(interval, _stuck_check_interval)
	var body := host()
	if body != null and not view.grow(_screen_margin).has_point(body.global_position):
		interval = maxf(interval, _offscreen_check_interval)
	return interval


## Wakes the body when the terrain it depends on changed.
func wake_if_terrain_changed() -> bool:
	if not _sleeping or not _watch.has_changed():
		return false
	wake()
	return true


func wake() -> void:
	if not _sleeping:
		return
	_sleeping = false
	woken.emit()
