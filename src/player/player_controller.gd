## Coordinates player physics, movement model, grapple model, and environment sampling.
class_name PlayerController
extends CharacterBody2D


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
const FLOOR_CONTACT_NORMAL_Y := -0.35

@export var movement_config: PlayerMovementConfig
@export var grapple_config: GrappleConfig
@export var suffocation_hazard_behavior: TerrainHazardBehavior
@export var step_up_height := 14.0
@export var support_probe_distance := 8.0
@export var horizontal_collision_radius := 14.0
@export var terrain_unstuck_search_ring := 8
@export var terrain_unstuck_push_speed := 900.0

@onready var presentation: PlayerPresentationController = %PlayerPresentation
@onready var camera: DescendingCameraController = %FollowCamera
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
var _grounded := false
var _input_controller: GameplayInputController
var _owns_input_controller := false
var _ragdoll_remaining := 0.0
var _ragdoll_spin_direction := 1.0
var _base_movement_config: PlayerMovementConfig
var _base_grapple_config: GrappleConfig
var _runtime_tuning: PlayerRuntimeTuning


func _ready() -> void:
	_capture_base_configs()
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
	if _runtime_tuning == null:
		_rebuild_perk_tuning(null)


func set_perk_modifiers(modifiers: PerkModifierSnapshot) -> void:
	_capture_base_configs()
	_rebuild_perk_tuning(modifiers)


func apply_blast_impulse(origin: Vector2, maximum_impulse: float, radius: float) -> void:
	if maximum_impulse <= 0.0 or radius <= 0.0:
		return
	var displacement := global_position - origin
	var distance := displacement.length()
	if distance > radius:
		return
	var direction := Vector2.UP if distance <= 0.001 else displacement / distance
	velocity += direction * maximum_impulse * (1.0 - distance / radius)


func _capture_base_configs() -> void:
	if _base_movement_config == null:
		_base_movement_config = movement_config
	if _base_grapple_config == null:
		_base_grapple_config = grapple_config


func _rebuild_perk_tuning(modifiers: PerkModifierSnapshot) -> void:
	if _base_movement_config == null or _base_grapple_config == null:
		return
	_runtime_tuning = PlayerRuntimeTuning.compile(
		_base_movement_config,
		_base_grapple_config,
		modifiers
	)
	movement_config = _runtime_tuning.movement
	grapple_config = _runtime_tuning.grapple
	_apply_runtime_collision_policy()
	if _movement_model != null:
		_movement_model.config = movement_config
	if _grapple_model != null:
		_grapple_model.config = grapple_config
	_impact_hazard_effect = _create_impact_hazard_effect()


func _apply_runtime_collision_policy() -> void:
	var ignored_ids := PackedInt32Array()
	if _runtime_tuning != null and _runtime_tuning.sand_passable and _terrain_registry != null:
		for definition in _terrain_registry.all_definitions():
			if definition.perk_tags.has("sand"):
				ignored_ids.append(definition.stable_id)
	_terrain_query.set_ignored_solid_ids(ignored_ids)


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
	_movement_model.step(
		input_frame,
		grounded_for_input,
		delta,
		_has_jelly_liquid_jump_support(),
		_is_horizontal_air_control_enabled()
	)
	velocity = _grapple_model.update(input_frame, global_position, _movement_model.velocity, delta)
	_apply_fluid_drag(delta)
	if input_frame.hook_pressed:
		presentation.start_hook_launch(_hook_launch_target(input_frame.aim_position))
	elif input_frame.hook_released:
		presentation.cancel_hook_launch()
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
	var unstuck_result := _apply_terrain_unstuck(delta)
	_handle_physics_impacts(motion_result, post_grapple_result, unstuck_result)
	_movement_model.sync_after_move(velocity, _is_grounded_for_movement())
	velocity = _movement_model.velocity
	presentation.update_body(
		_movement_model.current_state,
		velocity,
		is_ragdolling(),
		_ragdoll_spin_direction,
		movement_config.ragdoll_spin_speed,
		delta
	)
	presentation.update_grapple(
		_grapple_model.state.is_attached and _grapple_model.state.anchor != null,
		current_grapple_anchor_position(),
		delta
	)
	_sample_environment(delta)
	_update_sand_presentation()


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
	_apply_runtime_collision_policy()
	_environment_status.reset()
	hazard_status_changed.emit([])


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


func _has_jelly_liquid_jump_support() -> bool:
	return _runtime_tuning != null \
		and _runtime_tuning.liquid_gravity_cancelled \
		and _body_intersects_perk_tag("liquid")


func _is_horizontal_air_control_enabled() -> bool:
	if _runtime_tuning == null:
		return true
	if not _runtime_tuning.free_air_control_disabled:
		return true
	return _grapple_model != null and _grapple_model.state.is_attached


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
	presentation.cancel_hook_launch()
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
	_apply_jelly_surface_bounce(motion_result, post_grapple_result)


func _apply_jelly_surface_bounce(
	motion_result: TerrainBodyMotionResult,
	post_grapple_result: TerrainBodyMotionResult
) -> bool:
	if _runtime_tuning == null or _body_intersects_perk_tag("liquid"):
		return false
	var restitution := _runtime_tuning.hard_surface_restitution
	if restitution <= 0.0:
		return false
	var settle_speed := _runtime_tuning.bounce_settle_speed
	var impact_speed := maxf(
		_downward_floor_impact_speed(motion_result),
		_downward_floor_impact_speed(post_grapple_result)
	)
	if impact_speed <= settle_speed:
		return false
	velocity.y = -impact_speed * restitution
	_grounded = false
	return true


func _downward_floor_impact_speed(result: TerrainBodyMotionResult) -> float:
	if result == null or not result.collided:
		return 0.0
	var has_floor_contact := false
	for normal in result.hit_normals:
		if normal.y < FLOOR_CONTACT_NORMAL_Y:
			has_floor_contact = true
			break
	if not has_floor_contact:
		return 0.0
	return maxf(0.0, -result.velocity_change.y)


func _hook_launch_target(aim_position: Vector2) -> Vector2:
	if _grapple_model.state.is_attached and _grapple_model.state.anchor != null:
		return _grapple_model.state.anchor.position

	var aim_delta := aim_position - global_position
	var aim_distance := aim_delta.length()
	if aim_distance <= 0.001:
		return global_position
	return global_position + aim_delta / aim_distance * grapple_config.effective_attach_range()


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
	var jelly_in_liquid := _runtime_tuning != null \
		and _runtime_tuning.liquid_gravity_cancelled \
		and _body_intersects_perk_tag("liquid")
	var liquid_drag_disabled := _runtime_tuning != null \
		and _runtime_tuning.liquid_drag_disabled
	if not (jelly_in_liquid and liquid_drag_disabled):
		velocity *= exp(-average_viscosity * delta)
	if jelly_in_liquid:
		var buoyancy := _runtime_tuning.liquid_buoyancy_multiplier
		velocity.y -= movement_config.gravity * buoyancy * _liquid_submersion_fraction() * delta


func _liquid_submersion_fraction() -> float:
	var sample_positions := _occupied_sample_positions()
	if sample_positions.is_empty():
		return 0.0
	var submerged_count := 0
	for sample_position in sample_positions:
		var offset := HexMetrics.offset_for_world(sample_position, _hex_radius)
		if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
			continue
		var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
		if definition != null and definition.perk_tags.has("liquid"):
			submerged_count += 1
	return float(submerged_count) / float(sample_positions.size())


func _update_sand_presentation() -> void:
	presentation.set_sand_burrow_visible(
		_runtime_tuning != null
			and _runtime_tuning.sand_passable
			and _body_intersects_perk_tag("sand")
	)


func _average_body_fluid_viscosity() -> float:
	if not _terrain_query.is_configured():
		return 0.0
	var sample_positions := _occupied_sample_positions()
	if sample_positions.is_empty():
		return 0.0
	var summed_viscosity := 0.0
	for sample_position in sample_positions:
		summed_viscosity += _terrain_query.quantity_weighted_viscosity_at_world(sample_position)
	return summed_viscosity / float(sample_positions.size())


func _hazard_effect_at(world_position: Vector2):
	var offset := HexMetrics.offset_for_world(world_position, _hex_radius)
	if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return null
	var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
	if definition == null:
		return null
	if _runtime_tuning != null and _runtime_tuning.all_hazards_immune:
		return null
	if _runtime_tuning != null \
		and _runtime_tuning.sulfur_dioxide_immune \
		and definition.perk_tags.has("sulfur_dioxide"):
		return null
	var effect = definition.hazard_behavior.resolve_for_quantity(_world.get_committed_quantity_by_offset(offset.x, offset.y))
	if effect != null and _runtime_tuning != null and definition.perk_tags.has("lava"):
		effect.fill_seconds += _runtime_tuning.lava_duration_seconds_add
	if effect != null and _runtime_tuning != null and definition.perk_tags.has("acid"):
		effect.fill_seconds += _runtime_tuning.acid_duration_seconds_add
	return effect


func _suffocation_effect_at_head():
	if suffocation_hazard_behavior == null or _head_has_breathable_air() or (_runtime_tuning != null and _runtime_tuning.all_hazards_immune):
		return null
	var effect = suffocation_hazard_behavior.resolve()
	if _runtime_tuning != null and _head_has_perk_tag("water"):
		effect.fill_seconds += _runtime_tuning.suffocation_duration_seconds_add
	return effect


func _head_has_breathable_air() -> bool:
	var offset := HexMetrics.offset_for_world(global_position + Vector2(0.0, -10.0), _hex_radius)
	while _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
		if definition == null or definition.is_empty_space:
			return true
		if _runtime_tuning != null and definition.perk_tags.has("sand") and _runtime_tuning.sand_breathable:
			return true
		if _runtime_tuning != null and definition.perk_tags.has("sulfur_dioxide") and _runtime_tuning.sulfur_dioxide_breathable:
			return true
		if _world.get_committed_quantity_by_offset(offset.x, offset.y) >= definition.maximum_quantity:
			return false
		offset = HexCoord.from_offset_odd_q(offset.x, offset.y).neighbor(2).to_offset_odd_q()
	return true


func _head_has_perk_tag(tag: String) -> bool:
	if _world == null or _terrain_registry == null:
		return false
	var offset := HexMetrics.offset_for_world(global_position + Vector2(0.0, -10.0), _hex_radius)
	if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return false
	var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
	return definition != null and definition.perk_tags.has(tag)


func _body_intersects_perk_tag(tag: String) -> bool:
	if _world == null or _terrain_registry == null:
		return false
	for sample_position in _occupied_sample_positions():
		var offset := HexMetrics.offset_for_world(sample_position, _hex_radius)
		if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
			continue
		var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
		if definition != null and definition.perk_tags.has(tag):
			return true
	return false
