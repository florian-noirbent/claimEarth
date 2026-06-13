extends GutTest


func test_ground_input_accelerates_and_idle_friction_slows() -> void:
	var model := PlayerMovementModel.new(_config())
	var frame := PlayerInputFrame.new()
	frame.move_axis = 1.0
	model.step(frame, true, 0.1)
	assert_true(model.velocity.x > 0.0)
	assert_eq(model.current_state, PlayerMovementState.RUN)

	frame.move_axis = 0.0
	model.step(frame, true, 0.1)
	assert_true(model.velocity.x < model.config.max_ground_speed)


func test_jump_pressed_on_ground_uses_jump_velocity() -> void:
	var model := PlayerMovementModel.new(_config())
	var frame := PlayerInputFrame.new()
	frame.jump_pressed = true
	model.step(frame, true, 0.016)

	assert_eq(model.velocity.y, model.config.jump_velocity)
	assert_eq(model.current_state, PlayerMovementState.JUMP)


func test_coyote_time_allows_late_jump() -> void:
	var model := PlayerMovementModel.new(_config())
	model.step(PlayerInputFrame.new(), true, 0.016)

	var frame := PlayerInputFrame.new()
	frame.jump_pressed = true
	model.step(frame, false, 0.05)

	assert_eq(model.velocity.y, model.config.jump_velocity)


func test_jump_buffer_triggers_when_landing_shortly_after_press() -> void:
	var model := PlayerMovementModel.new(_config())
	var pressed := PlayerInputFrame.new()
	pressed.jump_pressed = true
	model.step(pressed, false, 0.016)

	model.step(PlayerInputFrame.new(), true, 0.016)

	assert_eq(model.velocity.y, model.config.jump_velocity)


func test_air_control_and_gravity_apply_in_air() -> void:
	var model := PlayerMovementModel.new(_config())
	var frame := PlayerInputFrame.new()
	frame.move_axis = -1.0
	model.step(frame, false, 0.1)

	assert_true(model.velocity.x < 0.0)
	assert_true(model.velocity.y > 0.0)
	assert_eq(model.current_state, PlayerMovementState.FALL)


func _config() -> PlayerMovementConfig:
	return load("res://config/player/default_movement.tres") as PlayerMovementConfig
