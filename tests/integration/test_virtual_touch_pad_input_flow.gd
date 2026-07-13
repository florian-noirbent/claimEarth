extends GutTest


const PAD_SIZE := Vector2(244.0, 244.0)
const CENTER := PAD_SIZE * 0.5
const PLAYER_POSITION := Vector2(500.0, 300.0)


func test_viewport_routes_action_pad_press_and_release() -> void:
	var setup := _make_input_setup()
	var action_pad: VirtualTouchPad = setup.action_pad
	watch_signals(action_pad)
	await wait_process_frames(1)
	assert_eq(get_viewport().get_visible_rect().size, Vector2(1280.0, 720.0))
	assert_eq(action_pad.get_global_rect(), Rect2(Vector2(32.0, 32.0), PAD_SIZE))

	_send_touch(action_pad, 0, CENTER + Vector2.UP * action_pad.inner_radius, true)
	assert_signal_emit_count(action_pad, "stick_changed", 1)
	_send_touch(action_pad, 0, CENTER, false)
	assert_signal_emit_count(action_pad, "stick_released", 1)


func test_two_fingers_keep_move_held_while_aiming_and_throwing() -> void:
	var setup := _make_input_setup()
	var move_pad: VirtualTouchPad = setup.move_pad
	var action_pad: VirtualTouchPad = setup.action_pad
	var controller: GameplayInputController = setup.controller
	watch_signals(action_pad)
	watch_signals(controller)
	await wait_process_frames(1)

	_send_touch(move_pad, 0, CENTER + Vector2.RIGHT * move_pad.outer_radius * 0.75, true)
	_send_touch(action_pad, 1, CENTER + Vector2.UP * action_pad.inner_radius, true)
	var aiming_frame := controller.sample_player_input(PLAYER_POSITION, false)
	assert_almost_eq(aiming_frame.move_axis, 0.75, 0.001)
	assert_lt(aiming_frame.aim_position.y, PLAYER_POSITION.y)

	_send_touch(action_pad, 1, CENTER, false)
	assert_signal_emit_count(action_pad, "stick_released", 1)
	var throwing_frame := controller.sample_player_input(PLAYER_POSITION, false)
	assert_signal_emit_count(controller, "throw_requested", 1)
	assert_almost_eq(throwing_frame.move_axis, 0.75, 0.001)
	_send_touch(move_pad, 0, CENTER, false)


func test_two_fingers_keep_move_held_through_hook_press_hold_and_release() -> void:
	var setup := _make_input_setup()
	var move_pad: VirtualTouchPad = setup.move_pad
	var action_pad: VirtualTouchPad = setup.action_pad
	var controller: GameplayInputController = setup.controller
	watch_signals(action_pad)
	await wait_process_frames(1)

	_send_touch(move_pad, 0, CENTER + Vector2.LEFT * move_pad.outer_radius, true)
	_send_touch(action_pad, 1, CENTER + Vector2.UP * action_pad.outer_radius, true)
	assert_signal_emit_count(action_pad, "hook_pressed", 1)
	var pressed_frame := controller.sample_player_input(PLAYER_POSITION, false)
	assert_almost_eq(pressed_frame.move_axis, -1.0, 0.001)
	assert_true(pressed_frame.hook_pressed)
	assert_true(pressed_frame.hook_held)
	assert_lt(pressed_frame.aim_position.y, PLAYER_POSITION.y)

	var held_frame := controller.sample_player_input(PLAYER_POSITION, false)
	assert_almost_eq(held_frame.move_axis, -1.0, 0.001)
	assert_false(held_frame.hook_pressed)
	assert_true(held_frame.hook_held)

	_send_touch(action_pad, 1, CENTER, false)
	assert_signal_emit_count(action_pad, "hook_released", 1)
	var released_frame := controller.sample_player_input(PLAYER_POSITION, false)
	assert_almost_eq(released_frame.move_axis, -1.0, 0.001)
	assert_true(released_frame.hook_released)
	assert_false(released_frame.hook_held)
	_send_touch(move_pad, 0, CENTER, false)


func _make_input_setup() -> Dictionary:
	var overlay := Control.new()
	overlay.size = Vector2(1280.0, 720.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100
	add_child_autofree(overlay)

	var move_pad := VirtualTouchPad.new()
	move_pad.position = Vector2(32.0, 400.0)
	move_pad.size = PAD_SIZE
	overlay.add_child(move_pad)

	var action_pad := VirtualTouchPad.new()
	action_pad.kind = VirtualTouchPad.Kind.AIM_AND_HOOK
	action_pad.position = Vector2(32.0, 32.0)
	action_pad.size = PAD_SIZE
	overlay.add_child(action_pad)

	var controller := GameplayInputController.new()
	controller.set_phone_controls_enabled(true)
	add_child_autofree(controller)
	move_pad.stick_changed.connect(controller.set_touch_move)
	action_pad.stick_changed.connect(controller.set_touch_aim)
	action_pad.stick_released.connect(controller.release_touch_aim)
	action_pad.hook_pressed.connect(controller.press_touch_hook)
	action_pad.hook_released.connect(controller.release_touch_hook)
	return {
		"move_pad": move_pad,
		"action_pad": action_pad,
		"controller": controller,
	}


func _send_touch(
	pad: VirtualTouchPad,
	index: int,
	local_position: Vector2,
	pressed: bool
) -> void:
	var event := InputEventScreenTouch.new()
	event.device = 0
	event.index = index
	event.position = pad.get_global_transform_with_canvas() * local_position
	event.pressed = pressed
	get_viewport().push_input(event, true)
