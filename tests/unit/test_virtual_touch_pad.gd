extends GutTest


const PAD_SIZE := Vector2(244.0, 244.0)
const CENTER := PAD_SIZE * 0.5
const PAD_OFFSET := Vector2(317.0, 263.0)


func test_local_center_is_neutral_when_pad_is_offset_from_viewport_origin() -> void:
	var pad := _make_pad()
	watch_signals(pad)

	_send_touch(pad, 1, CENTER, true)

	_assert_latest_stick(pad, Vector2.ZERO)


func test_local_cardinal_positions_are_not_biased_by_global_pad_position() -> void:
	var pad := _make_pad()
	watch_signals(pad)
	var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

	for index in directions.size():
		var direction := directions[index]
		_send_touch(pad, index, CENTER + direction * pad.outer_radius, true)
		_assert_latest_stick(pad, direction)
		_send_touch(pad, index, CENTER, false)


func test_stick_strength_is_analog_and_clamped_to_unit_length() -> void:
	var pad := _make_pad()
	watch_signals(pad)

	_send_touch(pad, 1, CENTER + Vector2.RIGHT * pad.outer_radius * 0.5, true)
	_assert_latest_stick(pad, Vector2(0.5, 0.0))
	_send_drag(pad, 1, CENTER + Vector2(2.0, -2.0) * pad.outer_radius)
	_assert_latest_stick(pad, Vector2(1.0, -1.0).normalized())


func test_release_and_cancellation_return_to_zero_exactly_once() -> void:
	var pad := _make_pad()
	watch_signals(pad)

	_send_touch(pad, 3, CENTER + Vector2.LEFT * pad.outer_radius, true)
	_send_touch(pad, 3, CENTER, false)
	_send_touch(pad, 3, CENTER, false)
	assert_signal_emit_count(pad, "stick_changed", 2)
	assert_signal_emit_count(pad, "stick_released", 1)
	_assert_latest_stick(pad, Vector2.ZERO)

	_send_touch(pad, 4, CENTER + Vector2.DOWN * pad.outer_radius, true)
	_send_touch(pad, 4, CENTER, true, true)
	_send_touch(pad, 4, CENTER, true, true)
	assert_signal_emit_count(pad, "stick_changed", 4)
	assert_signal_emit_count(pad, "stick_released", 2)
	_assert_latest_stick(pad, Vector2.ZERO)


func test_only_the_owning_finger_can_drag_or_release_a_stick() -> void:
	var pad := _make_pad()
	watch_signals(pad)

	_send_touch(pad, 6, CENTER + Vector2.RIGHT * pad.outer_radius, true)
	_send_drag(pad, 7, CENTER + Vector2.LEFT * pad.outer_radius)
	_send_touch(pad, 7, CENTER, false)

	assert_signal_emit_count(pad, "stick_changed", 1)
	assert_signal_emit_count(pad, "stick_released", 0)
	_assert_latest_stick(pad, Vector2.RIGHT)


func _make_pad(kind: VirtualTouchPad.Kind = VirtualTouchPad.Kind.MOVE) -> VirtualTouchPad:
	var pad := VirtualTouchPad.new()
	pad.kind = kind
	pad.position = PAD_OFFSET
	pad.size = PAD_SIZE
	add_child_autofree(pad)
	return pad


func _send_touch(
	pad: VirtualTouchPad,
	index: int,
	local_position: Vector2,
	pressed: bool,
	canceled := false
) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = local_position
	event.pressed = pressed
	event.canceled = canceled
	pad._gui_input(event)


func _send_drag(pad: VirtualTouchPad, index: int, local_position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = local_position
	pad._gui_input(event)


func _assert_latest_stick(pad: VirtualTouchPad, expected: Vector2) -> void:
	var parameters: Array = get_signal_parameters(pad, "stick_changed")
	var actual := parameters[0] as Vector2
	assert_almost_eq(actual.x, expected.x, 0.001)
	assert_almost_eq(actual.y, expected.y, 0.001)
