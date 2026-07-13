## Draws and owns one lower-corner virtual touch control without leaking pointer input.
class_name VirtualTouchPad
extends Control

signal stick_changed(vector: Vector2)
signal stick_released
signal hook_pressed(aim: Vector2)
signal hook_released

enum Kind { MOVE, AIM_AND_HOOK }

@export var kind: Kind = Kind.MOVE
@export var inner_radius := 58.0
@export var outer_radius := 112.0

var _touch_index := -1
var _active_kind: Kind = Kind.MOVE
var _vector := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var center := size * 0.5
	var outline := Color(0.96, 0.75, 0.19, 0.78)
	var fill := Color(0.08, 0.055, 0.035, 0.46)
	if kind == Kind.AIM_AND_HOOK:
		draw_arc(center, outer_radius, 0.0, TAU, 48, outline, 4.0, true)
		draw_arc(center, inner_radius + 10.0, 0.0, TAU, 40, Color(outline, 0.5), 2.0, true)
	else:
		draw_circle(center, outer_radius, fill)
		draw_arc(center, outer_radius, 0.0, TAU, 48, outline, 4.0, true)
	draw_circle(center, inner_radius, Color(0.25, 0.12, 0.06, 0.55))
	draw_arc(center, inner_radius, 0.0, TAU, 40, Color(0.92, 0.89, 0.85, 0.5), 2.0, true)
	if not _vector.is_zero_approx():
		draw_circle(center + _vector * (inner_radius * 0.55), 19.0, Color(0.96, 0.75, 0.19, 0.85))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index < 0:
			_begin_touch(touch.index, touch.position)
		elif touch.index == _touch_index and (not touch.pressed or touch.canceled):
			_end_touch()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_touch(drag.position)
		accept_event()
	elif event is InputEventMouse:
		# Browsers can synthesize mouse events after a handled touch. Consume them here.
		accept_event()


func reset() -> void:
	if _touch_index >= 0:
		_end_touch()


func _begin_touch(index: int, position: Vector2) -> void:
	_touch_index = index
	var distance := position.distance_to(size * 0.5)
	_active_kind = Kind.MOVE if kind == Kind.MOVE or distance <= inner_radius + 10.0 else Kind.AIM_AND_HOOK
	_update_touch(position)
	if _active_kind == Kind.AIM_AND_HOOK:
		hook_pressed.emit(_vector)


func _update_touch(position: Vector2) -> void:
	var offset := position - size * 0.5
	_vector = (offset / maxf(outer_radius, 0.001)).limit_length(1.0)
	queue_redraw()
	if _active_kind == Kind.AIM_AND_HOOK:
		return
	stick_changed.emit(_vector)


func _end_touch() -> void:
	var ended_kind := _active_kind
	_touch_index = -1
	_vector = Vector2.ZERO
	queue_redraw()
	if ended_kind == Kind.AIM_AND_HOOK:
		hook_released.emit()
	else:
		stick_released.emit()
		stick_changed.emit(Vector2.ZERO)
