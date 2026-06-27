## Coordinates player physics, movement model, grapple model, and environment sampling.
class_name PlayerController
extends CharacterBody2D


signal bounds_exited
signal death_requested(cause: StringName)

const GrappleModelScript = preload("res://src/player/grapple_model.gd")
const GrappleInputFrameScript = preload("res://src/player/grapple_input_frame.gd")
const EnvironmentStatusScript = preload("res://src/player/environment_status.gd")
const DeathCauseScript = preload("res://src/player/death_cause.gd")

@export var movement_config: PlayerMovementConfig = preload("res://config/player/default_movement.tres")
@export var grapple_config = preload("res://config/player/default_grapple.tres")
@export var world_bottom_y := 100000.0
@export var floor_snap_distance := 18.0
@export var step_up_height := 14.0
@export var support_probe_distance := 8.0
@export var horizontal_collision_radius := 14.0

@onready var body_polygon: Polygon2D = %BodyPolygon
@onready var body_visual: Node2D = %BodyVisual
@onready var camera: DescendingCameraController = %FollowCamera
@onready var rope_line: Line2D = %RopeLine
@onready var hook_indicator: Polygon2D = %HookIndicator

var _movement_model: PlayerMovementModel
var _grapple_model
var _environment_status = EnvironmentStatusScript.new()
var _terrain_registry: TerrainRegistry
var _world: WorldGrid
var _hex_radius := 16.0
var _physics_frame_count := 0
var _pending_anchor_query: GrappleAnchorQuery
var _horizontal_bounds_enabled := false
var _horizontal_min_x := 0.0
var _horizontal_max_x := 0.0


func _ready() -> void:
	_movement_model = PlayerMovementModel.new(movement_config)
	_grapple_model = GrappleModelScript.new(grapple_config)
	floor_snap_length = floor_snap_distance
	if _pending_anchor_query != null:
		_grapple_model.set_anchor_query(_pending_anchor_query)
	if camera != null:
		camera.target = self


func _physics_process(delta: float) -> void:
	_physics_frame_count += 1
	var input_frame = _create_input_frame()
	var grounded_for_input := _is_grounded_for_movement()
	_movement_model.step(input_frame, grounded_for_input, delta)
	velocity = _grapple_model.update(input_frame, global_position, _movement_model.velocity, delta)
	_try_step_up(delta)
	if velocity.y >= 0.0:
		apply_floor_snap()
	move_and_slide()
	var grapple_resolution: Dictionary = _grapple_model.constrain_position(global_position, velocity)
	global_position = grapple_resolution.position
	velocity = grapple_resolution.velocity
	_movement_model.sync_after_move(velocity, _is_grounded_for_movement())
	velocity = _movement_model.velocity
	_enforce_horizontal_bounds()
	_update_visual_state()
	_update_grapple_visuals()
	_sample_environment(delta)
	if global_position.y > world_bottom_y:
		death_requested.emit(DeathCauseScript.BOUNDS)
		bounds_exited.emit()


func set_spawn_position(world_position: Vector2) -> void:
	global_position = world_position
	_grapple_model.detach()
	if camera != null:
		camera.global_position = world_position


func configure_grapple_anchor_query(anchor_query) -> void:
	_pending_anchor_query = anchor_query
	if _grapple_model == null:
		return
	_grapple_model.set_anchor_query(anchor_query)


func configure_environment(world: WorldGrid, terrain_registry: TerrainRegistry, hex_radius: float) -> void:
	_world = world
	_terrain_registry = terrain_registry
	_hex_radius = hex_radius
	_environment_status.reset()


func configure_horizontal_bounds(left_edge: float, right_edge: float) -> void:
	_horizontal_min_x = left_edge + horizontal_collision_radius
	_horizontal_max_x = right_edge - horizontal_collision_radius
	_horizontal_bounds_enabled = _horizontal_min_x <= _horizontal_max_x
	_enforce_horizontal_bounds()


func is_grapple_attached() -> bool:
	return _grapple_model.state.is_attached


func physics_frame_count() -> int:
	return _physics_frame_count


func current_grapple_anchor_position() -> Vector2:
	if not _grapple_model.state.is_attached or _grapple_model.state.anchor == null:
		return Vector2.ZERO
	return _grapple_model.state.anchor.position


func current_rope_length() -> float:
	return _grapple_model.state.rope_length


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


func _is_grounded_for_movement() -> bool:
	if is_on_floor():
		return true
	if velocity.y < 0.0:
		return false
	return test_move(global_transform, Vector2(0.0, support_probe_distance))


func _try_step_up(delta: float) -> void:
	if absf(velocity.x) < 1.0 or velocity.y < 0.0:
		return
	var horizontal_motion := Vector2(velocity.x * delta, 0.0)
	if horizontal_motion.length_squared() <= 0.0001:
		return
	if not test_move(global_transform, horizontal_motion):
		return

	var step_increments := [step_up_height * 0.34, step_up_height * 0.67, step_up_height]
	for step_height in step_increments:
		var upward_motion := Vector2(0.0, -step_height)
		if test_move(global_transform, upward_motion):
			continue
		var raised_transform := global_transform.translated(upward_motion)
		if test_move(raised_transform, horizontal_motion):
			continue
		global_position += upward_motion
		return


func _update_visual_state() -> void:
	match _movement_model.current_state:
		PlayerMovementState.RUN:
			body_visual.scale = Vector2(1.05, 0.95)
		PlayerMovementState.JUMP:
			body_visual.scale = Vector2(0.95, 1.08)
		PlayerMovementState.FALL:
			body_visual.scale = Vector2(0.98, 1.03)
		_:
			body_visual.scale = Vector2.ONE

	if absf(velocity.x) > 0.001:
		body_visual.scale.x = absf(body_visual.scale.x) * signf(velocity.x)


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


func _sample_environment(delta: float) -> void:
	if _world == null or _terrain_registry == null:
		return
	var effects: Array = []
	for sample_position in _occupied_sample_positions():
		var effect = _hazard_effect_at(sample_position)
		if effect != null:
			effects.append(effect)
	var cause := _environment_status.evaluate(effects, delta)
	if cause != DeathCauseScript.NONE:
		death_requested.emit(cause)


func _enforce_horizontal_bounds() -> void:
	if not _horizontal_bounds_enabled:
		return
	var clamped_x := clampf(global_position.x, _horizontal_min_x, _horizontal_max_x)
	if is_equal_approx(clamped_x, global_position.x):
		return
	global_position.x = clamped_x
	if global_position.x <= _horizontal_min_x and velocity.x < 0.0:
		velocity.x = 0.0
	elif global_position.x >= _horizontal_max_x and velocity.x > 0.0:
		velocity.x = 0.0


func _occupied_sample_positions() -> Array[Vector2]:
	return [
		global_position + Vector2(0.0, -10.0),
		global_position,
		global_position + Vector2(0.0, 10.0),
	]


func _hazard_effect_at(world_position: Vector2):
	var offset := HexMetrics.offset_for_world(world_position, _hex_radius)
	if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return null
	var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
	if definition == null:
		return null
	return definition.hazard_behavior.resolve_for_fill(_world.get_committed_fill_by_offset(offset.x, offset.y))
