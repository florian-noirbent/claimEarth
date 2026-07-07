## Pure model for player acceleration, gravity, jump buffering, and coyote time.
class_name PlayerMovementModel
extends RefCounted


var config: PlayerMovementConfig
var velocity := Vector2.ZERO
var current_state: StringName = PlayerMovementState.IDLE
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0


func _init(config_value: PlayerMovementConfig) -> void:
	config = config_value


func step(input_frame: PlayerInputFrame, grounded: bool, delta: float) -> void:
	var jumped_this_frame := false
	if grounded:
		_coyote_timer = config.coyote_time_seconds
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if input_frame.jump_pressed:
		_jump_buffer_timer = config.jump_buffer_seconds
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = config.jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		grounded = false
		jumped_this_frame = true

	var target_speed := input_frame.move_axis * (config.max_ground_speed if grounded else config.max_air_speed)
	var acceleration := config.ground_acceleration if grounded else config.air_acceleration

	if absf(input_frame.move_axis) > 0.001:
		if not _is_preserving_horizontal_overspeed(input_frame.move_axis, target_speed):
			velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	elif grounded:
		velocity.x = move_toward(velocity.x, 0.0, config.ground_friction * delta)

	if not grounded and not jumped_this_frame:
		velocity.y = minf(config.terminal_velocity, velocity.y + config.gravity * delta)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	_update_state(grounded)


func sync_after_move(updated_velocity: Vector2, grounded: bool) -> void:
	velocity = updated_velocity
	if grounded and velocity.y > 0.0:
		velocity.y = 0.0
	_update_state(grounded)


func _update_state(grounded: bool) -> void:
	if grounded:
		current_state = PlayerMovementState.RUN if absf(velocity.x) > 1.0 else PlayerMovementState.IDLE
	elif velocity.y < 0.0:
		current_state = PlayerMovementState.JUMP
	else:
		current_state = PlayerMovementState.FALL


func _is_preserving_horizontal_overspeed(move_axis: float, target_speed: float) -> bool:
	return signf(move_axis) == signf(velocity.x) and absf(velocity.x) > absf(target_speed)
