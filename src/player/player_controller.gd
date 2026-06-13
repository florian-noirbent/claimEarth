class_name PlayerController
extends CharacterBody2D


signal bounds_exited

const GrappleModelScript = preload("res://src/player/grapple_model.gd")
const GrappleInputFrameScript = preload("res://src/player/grapple_input_frame.gd")

@export var movement_config: PlayerMovementConfig = preload("res://config/player/default_movement.tres")
@export var grapple_config = preload("res://config/player/default_grapple.tres")
@export var world_bottom_y := 100000.0

@onready var body_polygon: Polygon2D = %BodyPolygon
@onready var camera: DescendingCameraController = %FollowCamera
@onready var rope_line: Line2D = %RopeLine
@onready var hook_indicator: Polygon2D = %HookIndicator

var _movement_model: PlayerMovementModel
var _grapple_model


func _ready() -> void:
	_movement_model = PlayerMovementModel.new(movement_config)
	_grapple_model = GrappleModelScript.new(grapple_config)


func _physics_process(delta: float) -> void:
	var input_frame = _create_input_frame()
	_movement_model.step(input_frame, is_on_floor(), delta)
	velocity = _grapple_model.update(input_frame, global_position, _movement_model.velocity, delta)
	move_and_slide()
	var grapple_resolution: Dictionary = _grapple_model.constrain_position(global_position, velocity)
	global_position = grapple_resolution.position
	velocity = grapple_resolution.velocity
	_movement_model.sync_after_move(velocity, is_on_floor())
	velocity = _movement_model.velocity
	_update_visual_state()
	_update_grapple_visuals()
	if global_position.y > world_bottom_y:
		bounds_exited.emit()


func set_spawn_position(world_position: Vector2) -> void:
	global_position = world_position
	_grapple_model.detach()
	if camera != null:
		camera.global_position = world_position


func configure_grapple_anchor_query(anchor_query) -> void:
	_grapple_model.set_anchor_query(anchor_query)


func is_grapple_attached() -> bool:
	return _grapple_model.state.is_attached


func current_grapple_anchor_position() -> Vector2:
	if not _grapple_model.state.is_attached or _grapple_model.state.anchor == null:
		return Vector2.ZERO
	return _grapple_model.state.anchor.position


func _create_input_frame():
	var frame = GrappleInputFrameScript.new()
	frame.move_axis = Input.get_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT)
	frame.jump_pressed = Input.is_action_just_pressed(InputActions.JUMP)
	frame.jump_held = Input.is_action_pressed(InputActions.JUMP)
	frame.jump_released = Input.is_action_just_released(InputActions.JUMP)
	frame.hook_pressed = Input.is_action_just_pressed(InputActions.HOOK)
	frame.hook_held = Input.is_action_pressed(InputActions.HOOK)
	frame.hook_released = Input.is_action_just_released(InputActions.HOOK)
	frame.rope_axis = Input.get_axis(InputActions.ROPE_UP, InputActions.ROPE_DOWN)
	frame.aim_position = get_global_mouse_position()
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


func _update_grapple_visuals() -> void:
	if not _grapple_model.state.is_attached or _grapple_model.state.anchor == null:
		rope_line.visible = false
		hook_indicator.visible = false
		return

	rope_line.visible = true
	hook_indicator.visible = true
	rope_line.points = PackedVector2Array([
		Vector2.ZERO,
		to_local(_grapple_model.state.anchor.position),
	])
	hook_indicator.position = to_local(_grapple_model.state.anchor.position)
