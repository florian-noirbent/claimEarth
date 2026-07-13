extends GutTest


const GameplayInputControllerScript = preload("res://src/input/gameplay_input_controller.gd")


func test_touch_move_and_hook_edges_make_a_neutral_frame() -> void:
	var controller = GameplayInputControllerScript.new()
	controller.set_phone_controls_enabled(true)
	controller.set_touch_move(Vector2(0.6, -0.8))
	controller.press_touch_hook(Vector2(0.0, -1.0))

	var frame: GrappleInputFrame = controller.sample_player_input(Vector2(100.0, 100.0), false)

	assert_almost_eq(frame.move_axis, 0.6, 0.001)
	assert_true(frame.jump_pressed)
	assert_true(frame.jump_held)
	assert_true(frame.hook_pressed)
	assert_true(frame.hook_held)
	assert_lt(frame.aim_position.y, 100.0)
	controller.free()


func test_touch_rope_input_replaces_jump_while_attached() -> void:
	var controller = GameplayInputControllerScript.new()
	controller.set_phone_controls_enabled(true)
	controller.set_touch_move(Vector2(0.0, -1.0))

	var frame: GrappleInputFrame = controller.sample_player_input(Vector2.ZERO, true)

	assert_eq(frame.rope_axis, -1.0)
	assert_false(frame.jump_held)
	controller.free()


func test_releasing_touch_hook_emits_one_release_edge() -> void:
	var controller = GameplayInputControllerScript.new()
	controller.set_phone_controls_enabled(true)
	controller.press_touch_hook(Vector2.RIGHT)
	controller.sample_player_input(Vector2.ZERO, false)
	controller.release_touch_hook()

	var released: GrappleInputFrame = controller.sample_player_input(Vector2.ZERO, false)
	var settled: GrappleInputFrame = controller.sample_player_input(Vector2.ZERO, false)

	assert_true(released.hook_released)
	assert_false(settled.hook_released)
	controller.free()
