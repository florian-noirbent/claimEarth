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
const FLOOR_CONTACT_NORMAL_Y := -0.35

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
@onready var sand_outline: Line2D = %SandOutline
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
var _base_movement_config: PlayerMovementConfig
var _base_grapple_config: GrappleConfig
var _perk_modifiers: PerkModifierSnapshot


func _ready() -> void:
	_base_movement_config = movement_config
	_base_grapple_config = grapple_config
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
	_rebuild_perk_tuning()


func set_perk_modifiers(modifiers: PerkModifierSnapshot) -> void:
	_perk_modifiers = modifiers
	_rebuild_perk_tuning()


func apply_blast_impulse(origin: Vector2, maximum_impulse: float, radius: float) -> void:
	if maximum_impulse <= 0.0 or radius <= 0.0:
		return
	var displacement := global_position - origin
	var distance := displacement.length()
	if distance > radius:
		return
	var direction := Vector2.UP if distance <= 0.001 else displacement / distance
	velocity += direction * maximum_impulse * (1.0 - distance / radius)


func _rebuild_perk_tuning() -> void:
	if _base_movement_config == null or _base_grapple_config == null:
		return
	movement_config = _base_movement_config.duplicate() as PlayerMovementConfig
	grapple_config = _base_grapple_config.duplicate() as GrappleConfig
	var player_domain = _perk_modifiers.player if _perk_modifiers != null else null
	if player_domain != null:
		movement_config.gravity *= maxf(0.0, 1.0 + float(player_domain.value("gravity_multiplier_delta", 0.0)))
		var speed_multiplier := maxf(0.0, float(player_domain.value("movement_speed_multiplier", 1.0)))
		movement_config.max_ground_speed *= speed_multiplier
		movement_config.max_air_speed *= speed_multiplier
		movement_config.ground_friction *= float(player_domain.value("ground_friction_multiplier", 1.0))
		movement_config.extra_air_jumps += int(player_domain.value("extra_air_jumps_add", 0))
		grapple_config.max_rope_length *= maxf(0.0, 1.0 + float(player_domain.value("rope_length_multiplier_delta", 0.0)))
		var impact_mode := int(player_domain.value("impact_mode", 0))
		if bool(player_domain.value("impact_disabled", false)):
			movement_config.impact_hazard_minimum_speed = INF
		elif bool(player_domain.value("impact_death_disabled", false)):
			var threshold_add := float(player_domain.value("impact_threshold_add", 0.0))
			movement_config.impact_hazard_minimum_speed += threshold_add
			movement_config.medium_impact_speed += threshold_add
			movement_config.lethal_impact_speed += threshold_add
		elif impact_mode == 1: # Hard Skin: medium impacts ignored, previous lethal knocks out.
			movement_config.impact_hazard_minimum_speed = _base_movement_config.medium_impact_speed
			movement_config.medium_impact_speed = _base_movement_config.lethal_impact_speed
			movement_config.lethal_impact_speed = maxf(
				_base_movement_config.lethal_impact_speed + 1.0,
				_base_movement_config.lethal_impact_speed + (_base_movement_config.lethal_impact_speed - _base_movement_config.medium_impact_speed)
			)
		elif impact_mode == 2: # Jelly: no fall damage or knockout.
			movement_config.impact_hazard_minimum_speed = INF
		elif impact_mode == 3: # Glass Cannon: previous knockout becomes lethal.
			movement_config.impact_hazard_minimum_speed = _base_movement_config.impact_hazard_minimum_speed
			movement_config.medium_impact_speed = _base_movement_config.medium_impact_speed
			movement_config.lethal_impact_speed = _base_movement_config.medium_impact_speed
	var ignored_ids := PackedInt32Array()
	if _perk_modifiers != null and bool(_perk_modifiers.terrain.value("player_sand_passable", false)) and _terrain_registry != null:
		for definition in _terrain_registry.all_definitions():
			if definition.perk_tags.has("sand"):
				ignored_ids.append(definition.stable_id)
	_terrain_query.set_ignored_solid_ids(ignored_ids)
	if _movement_model != null:
		_movement_model.config = movement_config
	if _grapple_model != null:
		_grapple_model.config = grapple_config
	_impact_hazard_effect = _create_impact_hazard_effect()


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
	_update_sand_outline()
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


func _has_jelly_liquid_jump_support() -> bool:
	return _perk_modifiers != null \
		and bool(_perk_modifiers.player.value("liquid_gravity_cancelled", false)) \
		and _body_intersects_perk_tag("liquid")


func _is_horizontal_air_control_enabled() -> bool:
	if _perk_modifiers == null:
		return true
	if not bool(_perk_modifiers.player.value("free_air_control_disabled", false)):
		return true
	return _grapple_model != null and _grapple_model.state.is_attached


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
	_apply_jelly_surface_bounce(motion_result, post_grapple_result)


func _apply_jelly_surface_bounce(
	motion_result: TerrainBodyMotionResult,
	post_grapple_result: TerrainBodyMotionResult
) -> bool:
	if _perk_modifiers == null or _body_intersects_perk_tag("liquid"):
		return false
	var restitution := clampf(
		float(_perk_modifiers.player.value("hard_surface_restitution", 0.0)),
		0.0,
		1.0
	)
	if restitution <= 0.0:
		return false
	var settle_speed := maxf(
		0.0,
		float(_perk_modifiers.player.value("bounce_settle_speed", 0.0))
	)
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
	var jelly_in_liquid := _perk_modifiers != null \
		and bool(_perk_modifiers.player.value("liquid_gravity_cancelled", false)) \
		and _body_intersects_perk_tag("liquid")
	var liquid_drag_disabled := _perk_modifiers != null \
		and bool(_perk_modifiers.player.value("liquid_drag_disabled", false))
	if not (jelly_in_liquid and liquid_drag_disabled):
		velocity *= exp(-average_viscosity * delta)
	if jelly_in_liquid:
		var buoyancy := maxf(1.0, float(_perk_modifiers.player.value("liquid_buoyancy_multiplier", 1.0)))
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


func _update_sand_outline() -> void:
	if sand_outline == null:
		return
	var can_burrow := _perk_modifiers != null and bool(_perk_modifiers.terrain.value("player_sand_passable", false))
	sand_outline.visible = can_burrow and _body_intersects_perk_tag("sand")


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
	if _perk_modifiers != null and bool(_perk_modifiers.hazards.value("all_hazards_immune", false)):
		return null
	var effect = definition.hazard_behavior.resolve_for_quantity(_world.get_committed_quantity_by_offset(offset.x, offset.y))
	if effect != null and _perk_modifiers != null and definition.perk_tags.has("lava"):
		effect.fill_seconds += float(_perk_modifiers.hazards.value("lava_duration_seconds_add", 0.0))
	return effect


func _suffocation_effect_at_head():
	if suffocation_hazard_behavior == null or _head_has_breathable_air() or (_perk_modifiers != null and bool(_perk_modifiers.hazards.value("all_hazards_immune", false))):
		return null
	var effect = suffocation_hazard_behavior.resolve()
	if _perk_modifiers != null and _head_has_perk_tag("water"):
		effect.fill_seconds += float(_perk_modifiers.hazards.value("suffocation_duration_seconds_add", 0.0))
	return effect


func _head_has_breathable_air() -> bool:
	var offset := HexMetrics.offset_for_world(global_position + Vector2(0.0, -10.0), _hex_radius)
	while _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
		if definition == null or definition.is_empty_space:
			return true
		if _perk_modifiers != null and definition.perk_tags.has("sand") and bool(_perk_modifiers.hazards.value("sand_breathable", false)):
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
