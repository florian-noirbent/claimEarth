## Routes gameplay facts to the audio and visual feedback sinks. It converts units only;
## how a moment sounds or looks is decided by AudioDirector and GameplayFeedback.
class_name FeedbackRouter
extends RefCounted


var _audio: AudioDirector
var _session: RunSession
var _visuals: GameplayFeedback


func _init(audio: AudioDirector) -> void:
	_audio = audio


## Connects the feedback facts of a fresh session; its GameplayFeedback becomes the visual sink.
func attach(session: RunSession) -> void:
	_session = session
	_visuals = session.gameplay_feedback
	session.player_jumped.connect(_on_player_jumped)
	session.player_landed.connect(_on_player_landed)
	session.player_hard_impact.connect(_on_player_hard_impact)
	session.player_knocked_out.connect(_on_player_knocked_out)
	session.player_hook_launched.connect(_on_player_hook_launched)
	session.player_hook_attached.connect(_on_player_hook_attached)
	session.player_hook_missed.connect(_on_player_hook_missed)
	session.player_hook_released.connect(_on_player_hook_released)
	session.player_liquid_entered.connect(_on_player_liquid_changed.bind(true))
	session.player_liquid_exited.connect(_on_player_liquid_changed.bind(false))
	session.player_sand_burrow_changed.connect(_on_player_sand_burrow_changed)
	session.player_hazard_warning.connect(_on_player_hazard_warning)
	session.item_thrown.connect(_on_item_thrown)
	session.tool_used.connect(_on_tool_used)
	session.item_selected.connect(_audio.play_item_select)
	session.projectile_spawned.connect(_on_projectile_spawned)
	session.projectile_bounced.connect(_on_projectile_bounced)
	session.projectile_resolved.connect(_on_projectile_resolved)
	session.fluid_bottle_burst.connect(_on_fluid_bottle_burst)
	session.explosion_resolved.connect(_on_explosion_resolved)
	session.explosive_fuse_armed.connect(_on_explosive_fuse_armed)
	session.world_object_destroyed.connect(_on_world_object_destroyed)
	session.barrel_bumped.connect(_on_barrel_bumped)
	session.excavator_deployed.connect(_on_excavator_deployed)
	session.excavator_drilled.connect(_on_excavator_drilled)
	session.terrain_pulse_started.connect(_on_terrain_pulse_started)
	session.flag_flight_changed.connect(_on_flag_flight_changed)
	session.reward_container_opened.connect(_on_reward_container_opened)


## Points camera shake at the run's player camera once the player exists.
func use_camera(camera: DescendingCameraController) -> void:
	if _has_visuals():
		_visuals.set_camera(camera)


# --- Moments decided by AppRoot's run-state rules ---

func run_started() -> void:
	_audio.play_run_start()


func pause_changed(is_paused: bool) -> void:
	_audio.play_pause(is_paused)


func game_over() -> void:
	_audio.play_game_over()


func score_confirmed() -> void:
	_audio.play_ui_confirm()


func ui(kind: StringName) -> void:
	_audio.play_ui(kind)


func player_died(world_position: Vector2, cause: StringName) -> void:
	_audio.play_death(cause)
	if _has_visuals():
		_visuals.spawn_death(world_position, cause)


func flag_planted(world_position: Vector2, is_victory: bool) -> void:
	_audio.play_flag_plant()
	if _has_visuals():
		_visuals.spawn_flag_planted(world_position)
	if not is_victory:
		return
	_audio.play_victory()
	if _has_visuals():
		_visuals.spawn_victory(world_position)


func flag_destroyed(world_position: Vector2, cause: StringName) -> void:
	_audio.play_flag_destroyed(cause)
	if _has_visuals():
		_visuals.spawn_flag_destroyed(world_position, cause)


func reward_choices_shown() -> void:
	_audio.play_reward_choices()


func reward_claimed(claim: RewardClaim) -> void:
	var is_perk := claim.picked_perk != null
	_audio.play_reward_claimed(is_perk)
	if _has_visuals():
		_visuals.spawn_reward_claimed(claim.world_position, is_perk)


# --- Session facts ---

func _on_player_jumped(world_position: Vector2, is_air_jump: bool) -> void:
	_audio.play_jump(is_air_jump)
	_visuals.spawn_jump_dust(world_position, is_air_jump)


func _on_player_landed(world_position: Vector2, impact_speed: float, airborne_seconds: float) -> void:
	_audio.play_land(impact_speed, airborne_seconds)
	_visuals.spawn_landing_dust(world_position, impact_speed, airborne_seconds)


func _on_player_hard_impact(world_position: Vector2, impact_speed: float) -> void:
	_audio.play_hard_impact(impact_speed)
	_visuals.spawn_impact_flash(world_position, impact_speed)


func _on_player_knocked_out(world_position: Vector2, impact_speed: float, duration_seconds: float) -> void:
	_audio.play_knockout(impact_speed)
	_visuals.spawn_knockout_stars(world_position, duration_seconds)


func _on_player_hook_launched(origin: Vector2, target_position: Vector2) -> void:
	_audio.play_hook_launch()
	_visuals.spawn_hook_launch(origin, target_position)


func _on_player_hook_attached(anchor_position: Vector2, is_moving_target: bool) -> void:
	_audio.play_hook_attach(is_moving_target)
	_visuals.spawn_hook_spark(anchor_position, is_moving_target)


func _on_player_hook_missed(_origin: Vector2, target_position: Vector2) -> void:
	_audio.play_hook_miss()
	_visuals.spawn_hook_miss(target_position)


func _on_player_hook_released(anchor_position: Vector2, by_input: bool) -> void:
	_audio.play_hook_release(by_input)
	_visuals.spawn_hook_release(anchor_position, by_input)


func _on_player_liquid_changed(world_position: Vector2, color: Color, speed: float, is_entering: bool) -> void:
	_audio.play_splash(speed, is_entering)
	_visuals.spawn_splash(world_position, color, speed, is_entering)


func _on_player_sand_burrow_changed(world_position: Vector2, is_burrowing: bool) -> void:
	_audio.play_sand_burrow(is_burrowing)
	_visuals.spawn_sand_burst(world_position, is_burrowing)


func _on_player_hazard_warning(cause: StringName, level: float, color: Color) -> void:
	_audio.play_hazard_warning(cause, level)
	var player := _session.world_controller.player()
	if player != null:
		_visuals.show_hazard_warning(player.global_position, cause, level, color)


func _on_item_thrown(definition: ItemDefinition, origin: Vector2, direction: Vector2) -> void:
	_audio.play_throw(definition)
	_visuals.spawn_throw(origin, direction, definition)


func _on_tool_used(definition: ItemDefinition, origin: Vector2, direction: Vector2) -> void:
	_audio.play_tool_use(definition)
	_visuals.spawn_tool_swing(origin, direction, definition)


func _on_projectile_spawned(projectile: ItemProjectile, definition: ItemDefinition) -> void:
	_visuals.show_projectile_effect(projectile, definition)


func _on_projectile_bounced(world_position: Vector2, impact_speed: float, definition: ItemDefinition) -> void:
	_audio.play_projectile_bounce(world_position, impact_speed, definition)
	_visuals.spawn_bounce_spark(world_position, impact_speed)


func _on_projectile_resolved(world_position: Vector2, definition: ItemDefinition, resolution_kind: StringName) -> void:
	_audio.play_projectile_end(world_position, definition, resolution_kind)
	_visuals.spawn_projectile_end(world_position, definition, resolution_kind)


func _on_fluid_bottle_burst(world_position: Vector2, color: Color) -> void:
	_audio.play_bottle_burst(world_position)
	_visuals.spawn_bottle_burst(world_position, color)


func _on_explosion_resolved(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool) -> void:
	var radius_world := blast_radius * _hex_radius()
	_audio.play_explosion(impact_position, radius_world, is_large)
	_visuals.spawn_explosion(impact_position, color, radius_world, is_large)


func _on_explosive_fuse_armed(world_position: Vector2, fuse_seconds: float) -> void:
	_audio.play_fuse_armed(world_position, fuse_seconds)
	_visuals.spawn_fuse_warning(world_position, fuse_seconds)


func _on_world_object_destroyed(object_key: StringName, world_position: Vector2) -> void:
	_audio.play_object_destroyed(world_position, object_key)
	_visuals.spawn_object_debris(world_position, object_key)


func _on_barrel_bumped(world_position: Vector2, impact_speed: float) -> void:
	_audio.play_barrel_bump(world_position, impact_speed)
	_visuals.spawn_barrel_bump(world_position, impact_speed)


func _on_excavator_deployed(world_position: Vector2) -> void:
	_audio.play_excavator_deploy(world_position)
	_visuals.spawn_excavator_deploy(world_position)


func _on_excavator_drilled(world_position: Vector2, dug_cell_count: int) -> void:
	_audio.play_excavator_drill(world_position, dug_cell_count)
	_visuals.spawn_drill_debris(world_position, dug_cell_count)


func _on_terrain_pulse_started(origin: Vector2, definition: DirectionalTerrainPulseDefinition) -> void:
	if definition == null:
		return
	var duration_seconds := definition.pulse_tick_count * definition.step_interval_seconds
	_audio.play_terrain_pulse(origin, duration_seconds)
	_visuals.spawn_directional_pulse(
		origin,
		definition.color,
		definition.width * _hex_radius() * 1.5,
		definition.step_count * sqrt(3.0) * _hex_radius(),
		duration_seconds,
		definition.front_load_decay
	)


func _on_flag_flight_changed(in_flight: bool) -> void:
	_audio.play_flag_flight(in_flight)
	_visuals.show_flag_flight(in_flight)


func _on_reward_container_opened(world_position: Vector2, container_key: StringName) -> void:
	_audio.play_container_open(container_key)
	_visuals.spawn_chest_burst(world_position, container_key)


func _has_visuals() -> bool:
	return is_instance_valid(_visuals)


func _hex_radius() -> float:
	return _session.world_presenter.hex_radius
