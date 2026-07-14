## Coordinates player physics, movement model, grapple model, and environment sampling.
class_name PlayerController
extends CharacterBody2D


signal bounds_exited
signal death_requested(cause: StringName)
signal hazard_status_changed(statuses: Array)

const GrappleModelScript = preload("res://src/player/grapple_model.gd")
const GrappleInputFrameScript = preload("res://src/player/grapple_input_frame.gd")
const EnvironmentStatusScript = preload("res://src/player/environment_status.gd")
const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")
const DeathCauseScript = preload("res://src/player/death_cause.gd")
const TerrainCollisionQueryScript = preload("res://src/world/terrain_collision_query.gd")
const TerrainBodyMotionSolverScript = preload("res://src/world/terrain_body_motion_solver.gd")
const TerrainBodyUnstuckSolverScript = preload("res://src/world/terrain_body_unstuck_solver.gd")
const GameplayInputControllerScript = preload("res://src/input/gameplay_input_controller.gd")

@export var movement_config: PlayerMovementConfig
@export var grapple_config: GrappleConfig
@export var suffocation_hazard_behavior: TerrainHazardBehavior
@export var world_bottom_y := 100000.0
@export var step_up_height := 14.0
@export var support_probe_distance := 8.0
@export var horizontal_collision_radius := 14.0
@export var terrain_unstuck_search_ring := 8
@export var terrain_unstuck_push_speed := 900.0
@export var hook_launch_animation_seconds := 0.08

@onready var body_polygon: Polygon2D = %BodyPolygon
@onready var body_visual: Node2D = %BodyVisual
@onready var camera: DescendingCameraController = %FollowCamera
@onready var rope_line: Line2D = %RopeLine
@onready var hook_indicator: Polygon2D = %HookIndicator
@onready var world_light_source: WorldLightSource2D = %WorldLightSource

var _movement_model: PlayerMovementModel
var _grapple_model
var _environment_status = EnvironmentStatusScript.new()
var _impact_hazard_effect: HazardEffect
var _terrain_registry: TerrainRegistry
var _world: WorldGrid
var _terrain_query = TerrainCollisionQueryScript.new()
var _terrain_motion_solver = TerrainBodyMotionSolverScript.new()
var _terrain_unstuck_solver = TerrainBodyUnstuckSolverScript.new()
var _hex_radius := 16.0
var _physics_frame_count := 0
var _pending_anchor_query: GrappleAnchorQuery
var _horizontal_bounds_enabled := false
var _horizontal_min_x := 0.0
var _horizontal_max_x := 0.0
var _grounded := false
var _hook_launch_elapsed := 0.0
var _hook_launch_duration := 0.0
var _hook_launch_target := Vector2.ZERO
var _input_controller: GameplayInputController
var _owns_input_controller := false
var _ragdoll_remaining := 0.0
var _ragdoll_spin_direction := 1.0


func _ready() -> void:
	_movement_model = PlayerMovementModel.new(movement_config)
	_grapple_model = GrappleModelScript.new(grapple_config)
	_impact_hazard_effect = _create_impact_hazard_effect()
	_terrain_motion_solver.configure(_terrain_query)
	if _pending_anchor_query != null:
		_grapple_model.set_anchor_query(_pending_anchor_query)
	if camera != null:
		camera.target = self
	if _input_controller == null:
		# Standalone player scenes use the same adapter as the composed application.
		_input_controller = GameplayInputControllerScript.new()
		_owns_input_controller = true


func _exit_tree() -> void:
	if _owns_input_controller and is_instance_valid(_input_controller):
		_input_controller.free()
		_input_controller = null


func _physics_process(delta: float) -> void:
	_physics_frame_count += 1
	_advance_ragdoll(delta)
	var input_frame = GrappleInputFrameScript.new() if is_ragdolling() else _create_input_frame()
	if is_ragdolling():
		_grapple_model.detach()
	var grounded_for_input := _is_grounded_for_movement()
	_movement_model.step(input_frame, grounded_for_input, delta)
	velocity = _grapple_model.update(input_frame, global_position, _movement_model.velocity, delta)
	_apply_fluid_drag(delta)
	if input_frame.hook_pressed:
		_start_hook_launch_animation(input_frame.aim_position)
	elif input_frame.hook_released:
		_stop_hook_launch_animation()
	var attached_before_constraint: bool = _grapple_model.state.is_attached
	var motion_result = _terrain_motion_solver.move_circle(
		global_position,
		velocity,
		delta,
		horizontal_collision_radius,
		step_up_height,
		support_probe_distance,
		grounded_for_input and not attached_before_constraint
	)
	global_position = motion_result.position
	velocity = motion_result.velocity
	_grounded = motion_result.grounded
	var grapple_resolution: Dictionary = _grapple_model.constrain_position(global_position, velocity, delta)
	global_position = grapple_resolution["position"] as Vector2
	velocity = grapple_resolution["velocity"] as Vector2
	var post_grapple_result = _terrain_motion_solver.resolve_circle(global_position, velocity, horizontal_collision_radius)
	global_position = post_grapple_result.position
	velocity = post_grapple_result.velocity
	_grounded = _grounded or post_grapple_result.grounded
	_enforce_horizontal_bounds()
	var unstuck_result := _apply_terrain_unstuck(delta)
	_handle_physics_impacts(motion_result, post_grapple_result, unstuck_result)
	_movement_model.sync_after_move(velocity, _is_grounded_for_movement())
	velocity = _movement_model.velocity
	_update_visual_state(delta)
	_update_grapple_visuals(delta)
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


func configure_input_controller(input_controller: GameplayInputController) -> void:
	if _owns_input_controller and is_instance_valid(_input_controller):
		_input_controller.free()
	_owns_input_controller = false
	_input_controller = input_controller


func configure_environment(world: WorldGrid, terrain_registry: TerrainRegistry, hex_radius: float) -> void:
	_world = world
	_terrain_registry = terrain_registry
	_hex_radius = hex_radius
	_terrain_query.configure(world, CompiledTerrainData.compile(terrain_registry), hex_radius)
	_environment_status.reset()
	hazard_status_changed.emit([])


func configure_horizontal_bounds(left_edge: float, right_edge: float) -> void:
	_horizontal_min_x = _snap_min_bound(left_edge + horizontal_collision_radius)
	_horizontal_max_x = _snap_max_bound(right_edge - horizontal_collision_radius)
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


func is_ragdolling() -> bool:
	return _ragdoll_remaining > 0.0


func ragdoll_remaining() -> float:
	return _ragdoll_remaining


func _create_input_frame():
	return _input_controller.sample_player_input(global_position, _grapple_model.state.is_attached)


func _is_grounded_for_movement() -> bool:
	if velocity.y < 0.0:
		return false
	return _grounded


func _update_visual_state(delta: float) -> void:
	if is_ragdolling():
		body_visual.rotation += _ragdoll_spin_direction * movement_config.ragdoll_spin_speed * delta
		body_visual.scale = Vector2(1.06, 0.94)
		return

	body_visual.rotation = 0.0
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


func _advance_ragdoll(delta: float) -> void:
	if _ragdoll_remaining <= 0.0:
		return
	_ragdoll_remaining = maxf(0.0, _ragdoll_remaining - delta)


func _handle_terrain_impact(impact_speed: float) -> void:
	if movement_config == null or impact_speed <= movement_config.impact_hazard_minimum_speed:
		return
	var hazard_span := movement_config.lethal_impact_speed - movement_config.impact_hazard_minimum_speed
	if hazard_span <= 0.0 or _impact_hazard_effect == null:
		return
	var contribution := (impact_speed - movement_config.impact_hazard_minimum_speed) / hazard_span
	var cause := _environment_status.add_instant(_impact_hazard_effect, contribution)
	var accumulated_level := _environment_status.level_for(DeathCauseScript.IMPACT)
	var knockout_level := (
		(movement_config.medium_impact_speed - movement_config.impact_hazard_minimum_speed)
		/ hazard_span
	)
	if cause == DeathCauseScript.NONE and accumulated_level < knockout_level:
		return
	_grapple_model.detach()
	_stop_hook_launch_animation()
	if cause == DeathCauseScript.IMPACT:
		death_requested.emit(DeathCauseScript.IMPACT)
		return
	_ragdoll_remaining = maxf(_ragdoll_remaining, movement_config.ragdoll_seconds)
	_ragdoll_spin_direction = -1.0 if velocity.x < 0.0 else 1.0


func _create_impact_hazard_effect() -> HazardEffect:
	if movement_config == null:
		return null
	var hazard_span := movement_config.lethal_impact_speed - movement_config.impact_hazard_minimum_speed
	if hazard_span <= 0.0 or movement_config.impact_hazard_recovery_seconds <= 0.0:
		return null
	var effect := HazardEffectScript.new() as HazardEffect
	effect.cause = DeathCauseScript.IMPACT
	effect.icon = movement_config.impact_hazard_icon
	effect.bar_color = movement_config.impact_hazard_bar_color
	effect.recovery_seconds = movement_config.impact_hazard_recovery_seconds
	effect.display_order = movement_config.impact_hazard_display_order
	effect.secondary_threshold = clampf(
		(movement_config.medium_impact_speed - movement_config.impact_hazard_minimum_speed)
		/ hazard_span,
		0.0,
		1.0
	)
	effect.lethal_end = true
	return effect


func _handle_physics_impacts(
	motion_result: TerrainBodyMotionResult,
	post_grapple_result: TerrainBodyMotionResult,
	unstuck_result: TerrainBodyUnstuckResult
) -> void:
	var greatest_velocity_change := maxf(
		maxf(
			motion_result.velocity_change.length(),
			post_grapple_result.velocity_change.length()
		),
		unstuck_result.velocity_change.length()
	)
	_handle_terrain_impact(greatest_velocity_change)


func _update_grapple_visuals(delta: float) -> void:
	if _hook_launch_duration > 0.0:
		_hook_launch_elapsed = minf(_hook_launch_duration, _hook_launch_elapsed + delta)
		var progress := _hook_launch_elapsed / _hook_launch_duration
		rope_line.visible = true
		hook_indicator.visible = true
		var local_target := to_local(_hook_launch_target)
		var animated_end := local_target * progress
		rope_line.points = PackedVector2Array([
			Vector2.ZERO,
			animated_end,
		])
		hook_indicator.position = animated_end
		if _hook_launch_elapsed < _hook_launch_duration:
			return
		_stop_hook_launch_animation()

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


func _start_hook_launch_animation(aim_position: Vector2) -> void:
	_hook_launch_elapsed = 0.0
	_hook_launch_duration = maxf(hook_launch_animation_seconds, 0.001)
	if _grapple_model.state.is_attached and _grapple_model.state.anchor != null:
		_hook_launch_target = _grapple_model.state.anchor.position
		return

	var aim_delta := aim_position - global_position
	var aim_distance := aim_delta.length()
	if aim_distance <= 0.001:
		_hook_launch_target = global_position
		return
	_hook_launch_target = global_position + aim_delta / aim_distance * grapple_config.effective_attach_range()


func _stop_hook_launch_animation() -> void:
	_hook_launch_elapsed = 0.0
	_hook_launch_duration = 0.0


func _sample_environment(delta: float) -> void:
	if _world == null or _terrain_registry == null:
		return
	var effects: Array = []
	for sample_position in _occupied_sample_positions():
		var effect = _hazard_effect_at(sample_position)
		if effect != null:
			effects.append(effect)
	var suffocation_effect = _suffocation_effect_at_head()
	if suffocation_effect != null:
		effects.append(suffocation_effect)
	var cause := _environment_status.evaluate(effects, delta)
	hazard_status_changed.emit(_environment_status.statuses())
	if cause != DeathCauseScript.NONE:
		death_requested.emit(cause)


func _enforce_horizontal_bounds() -> void:
	if not _horizontal_bounds_enabled:
		return
	if global_position.x >= _horizontal_min_x and global_position.x <= _horizontal_max_x:
		return
	var clamped_x := clampf(global_position.x, _horizontal_min_x, _horizontal_max_x)
	global_position.x = clamped_x
	if global_position.x <= _horizontal_min_x and velocity.x < 0.0:
		velocity.x = 0.0
	elif global_position.x >= _horizontal_max_x and velocity.x > 0.0:
		velocity.x = 0.0


func _apply_terrain_unstuck(delta: float) -> TerrainBodyUnstuckResult:
	var result: TerrainBodyUnstuckResult = _terrain_unstuck_solver.resolve_circle(
		global_position,
		velocity,
		delta,
		_terrain_query,
		horizontal_collision_radius,
		terrain_unstuck_search_ring,
		terrain_unstuck_push_speed
	)
	global_position = result.position
	velocity = result.velocity
	return result


func _snap_min_bound(value: float) -> float:
	return ceilf(value * 1000.0) / 1000.0


func _snap_max_bound(value: float) -> float:
	return floorf(value * 1000.0) / 1000.0


func _occupied_sample_positions() -> Array[Vector2]:
	return [
		global_position + Vector2(0.0, -10.0),
		global_position,
		global_position + Vector2(0.0, 10.0),
	]


func _apply_fluid_drag(delta: float) -> void:
	if delta <= 0.0 or not _terrain_query.is_configured():
		return
	var average_viscosity := _average_body_fluid_viscosity()
	if average_viscosity <= 0.0:
		return
	velocity *= exp(-average_viscosity * delta)


func _average_body_fluid_viscosity() -> float:
	if not _terrain_query.is_configured():
		return 0.0
	var sample_positions := _occupied_sample_positions()
	if sample_positions.is_empty():
		return 0.0
	var summed_viscosity := 0.0
	for sample_position in sample_positions:
		summed_viscosity += _terrain_query.fill_weighted_viscosity_at_world(sample_position)
	return summed_viscosity / float(sample_positions.size())


func _hazard_effect_at(world_position: Vector2):
	var offset := HexMetrics.offset_for_world(world_position, _hex_radius)
	if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return null
	var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
	if definition == null:
		return null
	return definition.hazard_behavior.resolve_for_fill(_world.get_committed_fill_by_offset(offset.x, offset.y))


func _suffocation_effect_at_head():
	if suffocation_hazard_behavior == null or _head_has_breathable_air():
		return null
	return suffocation_hazard_behavior.resolve()


func _head_has_breathable_air() -> bool:
	var offset := HexMetrics.offset_for_world(global_position + Vector2(0.0, -10.0), _hex_radius)
	while _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
		if definition == null or definition.is_empty_space:
			return true
		if _world.get_committed_fill_by_offset(offset.x, offset.y) >= 255:
			return false
		offset = HexCoord.from_offset_odd_q(offset.x, offset.y).neighbor(2).to_offset_odd_q()
	return true
