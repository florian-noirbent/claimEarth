class_name PlayerController
extends CharacterBody2D


signal bounds_exited


@export var movement_config: PlayerMovementConfig = preload("res://config/player/default_movement.tres")
@export var world_bottom_y := 100000.0

@onready var body_polygon: Polygon2D = %BodyPolygon
@onready var camera: DescendingCameraController = %FollowCamera

var _movement_model: PlayerMovementModel


func _ready() -> void:
	_movement_model = PlayerMovementModel.new(movement_config)


func _physics_process(delta: float) -> void:
	var input_frame := _create_input_frame()
	_movement_model.step(input_frame, is_on_floor(), delta)
	velocity = _movement_model.velocity
	move_and_slide()
	_movement_model.sync_after_move(velocity, is_on_floor())
	velocity = _movement_model.velocity
	_update_visual_state()
	if global_position.y > world_bottom_y:
		bounds_exited.emit()


func set_spawn_position(world_position: Vector2) -> void:
	global_position = world_position
	if camera != null:
		camera.global_position = world_position


func _create_input_frame() -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.move_axis = Input.get_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT)
	frame.jump_pressed = Input.is_action_just_pressed(InputActions.JUMP)
	frame.jump_held = Input.is_action_pressed(InputActions.JUMP)
	frame.jump_released = Input.is_action_just_released(InputActions.JUMP)
	return frame


func _update_visual_state() -> void:
	match _movement_model.current_state:
		PlayerMovementState.RUN:
			body_polygon.scale = Vector2(1.05, 0.95)
		PlayerMovementState.JUMP:
			body_polygon.scale = Vector2(0.95, 1.08)
		PlayerMovementState.FALL:
			body_polygon.scale = Vector2(0.98, 1.03)
		_:
			body_polygon.scale = Vector2.ONE

	if absf(velocity.x) > 0.001:
		body_polygon.scale.x = absf(body_polygon.scale.x) * signf(velocity.x)
