## Converts physical and virtual control state into device-neutral gameplay input.
class_name GameplayInputController
extends Node


signal throw_requested(aim_position: Vector2)
signal item_cycle_requested(direction: int)
signal item_selected_requested(index: int)
signal pause_requested


const GrappleInputFrameScript = preload("res://src/player/grapple_input_frame.gd")

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const JUMP := &"jump"
const ROPE_UP := &"rope_up"
const ROPE_DOWN := &"rope_down"
const HOOK := &"hook"
const THROW_SELECTED := &"throw_selected"
const PAUSE := &"pause"
const SELECT_SMALL_BOMB := &"select_small_bomb"
const SELECT_LARGE_BOMB := &"select_large_bomb"
const SELECT_FLAG := &"select_flag"
const CYCLE_ITEM_PREVIOUS := &"cycle_item_previous"
const CYCLE_ITEM_NEXT := &"cycle_item_next"
const AIM_LEFT := &"aim_left"
const AIM_RIGHT := &"aim_right"
const AIM_UP := &"aim_up"
const AIM_DOWN := &"aim_down"

const AXIS_DEADZONE := 0.2
const AIM_DISTANCE := 320.0

var _phone_controls_enabled := false
var _touch_move := Vector2.ZERO
var _touch_aim := Vector2.ZERO
var _touch_aim_active := false
var _touch_throw_requested := false
var _touch_hook_aim := Vector2.ZERO
var _touch_hook_held := false
var _touch_hook_pressed := false
var _touch_hook_released := false
var _previous_touch_jump_held := false
var _last_aim_direction := Vector2.RIGHT
var _last_mouse_aim_position := Vector2.ZERO


func set_phone_controls_enabled(enabled: bool) -> void:
	_phone_controls_enabled = enabled
	if not enabled:
		clear_virtual_input()


func set_touch_move(vector: Vector2) -> void:
	_touch_move = _clamp_unit_vector(vector)


func set_touch_aim(vector: Vector2) -> void:
	_touch_aim = _clamp_unit_vector(vector)
	_touch_aim_active = _touch_aim.length() >= AXIS_DEADZONE
	if _touch_aim_active:
		_last_aim_direction = _touch_aim.normalized()


func release_touch_aim() -> void:
	if not _phone_controls_enabled:
		return
	if _touch_aim_active and _touch_aim.length() >= AXIS_DEADZONE:
		_touch_throw_requested = true


func press_touch_hook(aim: Vector2) -> void:
	if not _phone_controls_enabled:
		return
	_touch_hook_aim = _clamp_unit_vector(aim)
	if _touch_hook_aim.length() >= AXIS_DEADZONE:
		_last_aim_direction = _touch_hook_aim.normalized()
	if not _touch_hook_held:
		_touch_hook_pressed = true
	_touch_hook_held = true


func release_touch_hook() -> void:
	if _touch_hook_held:
		_touch_hook_released = true
	_touch_hook_held = false
	_touch_hook_aim = Vector2.ZERO


func clear_virtual_input() -> void:
	_touch_move = Vector2.ZERO
	_touch_aim = Vector2.ZERO
	_touch_aim_active = false
	_touch_throw_requested = false
	_touch_hook_aim = Vector2.ZERO
	_touch_hook_held = false
	_touch_hook_pressed = false
	_touch_hook_released = false
	_previous_touch_jump_held = false


func sample_player_input(player_position: Vector2, grapple_attached: bool) -> GrappleInputFrame:
	var frame: GrappleInputFrame = GrappleInputFrameScript.new()
	var touch_move := _touch_move if _phone_controls_enabled else Vector2.ZERO
	frame.move_axis = _combined_axis(_action_axis(MOVE_LEFT, MOVE_RIGHT), touch_move.x)
	frame.rope_axis = _action_axis(ROPE_UP, ROPE_DOWN)
	if grapple_attached:
		frame.rope_axis = _combined_axis(frame.rope_axis, touch_move.y)
	var touch_jump_held := _phone_controls_enabled and not grapple_attached and touch_move.y <= -AXIS_DEADZONE
	frame.jump_pressed = _action_just_pressed(JUMP) or (touch_jump_held and not _previous_touch_jump_held)
	frame.jump_held = _action_pressed(JUMP) or touch_jump_held
	frame.jump_released = _action_just_released(JUMP) or (not touch_jump_held and _previous_touch_jump_held)
	_previous_touch_jump_held = touch_jump_held
	frame.hook_pressed = _action_just_pressed(HOOK) or _touch_hook_pressed
	frame.hook_held = _action_pressed(HOOK) or _touch_hook_held
	frame.hook_released = _action_just_released(HOOK) or _touch_hook_released
	frame.aim_position = _aim_position_for(player_position)
	if _touch_throw_requested:
		throw_requested.emit(frame.aim_position)
		_touch_throw_requested = false
		_touch_aim = Vector2.ZERO
		_touch_aim_active = false
	_touch_hook_pressed = false
	_touch_hook_released = false
	return frame


func handle_unhandled_input(event: InputEvent, mouse_aim_position: Vector2) -> bool:
	_update_aim_from_mouse(mouse_aim_position)
	_last_mouse_aim_position = mouse_aim_position
	if _event_action_pressed(event, PAUSE):
		pause_requested.emit()
		return true
	if _event_action_pressed(event, SELECT_SMALL_BOMB):
		item_selected_requested.emit(0)
		return true
	if _event_action_pressed(event, SELECT_LARGE_BOMB):
		item_selected_requested.emit(1)
		return true
	if _event_action_pressed(event, SELECT_FLAG):
		item_selected_requested.emit(2)
		return true
	if _event_action_pressed(event, CYCLE_ITEM_PREVIOUS):
		item_cycle_requested.emit(-1)
		return true
	if _event_action_pressed(event, CYCLE_ITEM_NEXT):
		item_cycle_requested.emit(1)
		return true
	if _event_action_pressed(event, THROW_SELECTED):
		throw_requested.emit(mouse_aim_position)
		return true
	return false


func _aim_position_for(player_position: Vector2) -> Vector2:
	var direction := _physical_aim_direction()
	if _phone_controls_enabled and _touch_hook_held and _touch_hook_aim.length() >= AXIS_DEADZONE:
		direction = _touch_hook_aim.normalized()
	elif _phone_controls_enabled and _touch_aim_active and _touch_aim.length() >= AXIS_DEADZONE:
		direction = _touch_aim.normalized()
	elif _last_mouse_aim_position.distance_to(player_position) > 0.001:
		direction = (_last_mouse_aim_position - player_position).normalized()
	if direction.length() >= 0.001:
		_last_aim_direction = direction
	return player_position + _last_aim_direction * AIM_DISTANCE


func _physical_aim_direction() -> Vector2:
	var aim := Vector2(
		_action_axis(AIM_LEFT, AIM_RIGHT),
		_action_axis(AIM_UP, AIM_DOWN)
	)
	return aim.normalized() if aim.length() >= AXIS_DEADZONE else Vector2.ZERO


func _update_aim_from_mouse(mouse_aim_position: Vector2) -> void:
	if mouse_aim_position.length() <= 0.001:
		return
	var mouse_direction := mouse_aim_position - _last_mouse_aim_position
	if mouse_direction.length() >= 0.001:
		_last_aim_direction = mouse_direction.normalized()


func _action_axis(negative: StringName, positive: StringName) -> float:
	if not InputMap.has_action(negative) or not InputMap.has_action(positive):
		return 0.0
	return Input.get_axis(negative, positive)


func _action_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _action_just_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _action_just_released(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_released(action)


func _event_action_pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)


func _combined_axis(first: float, second: float) -> float:
	return clampf(first + second, -1.0, 1.0)


func _clamp_unit_vector(vector: Vector2) -> Vector2:
	return vector.limit_length(1.0)
