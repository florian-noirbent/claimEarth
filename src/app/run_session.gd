## Composes the disposable gameplay session for one active run.
class_name RunSession
extends Node


signal generation_progressed(progress: float, label: String)
signal run_ready(next_seed: int)
signal player_died(cause: StringName)
signal player_hazard_status_changed(statuses: Array)
signal player_killed(cause: StringName)
signal explosion_resolved(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool)
signal flag_planted(depth: int, landing_position: Vector2)
signal flag_destroyed(cause: StringName, world_position: Vector2)
signal flag_flight_changed(in_flight: bool)
signal item_thrown(definition: ItemDefinition, origin: Vector2, direction: Vector2)
signal item_used(definition: ItemDefinition)
signal reward_choices_requested(title: String, choices: Array)
signal pending_reward_invalidated
signal reward_claimed(claim: RewardClaim)
signal world_object_destroyed(container_key: StringName, world_position: Vector2)
signal perks_changed(perks: Array)
signal terrain_pulse_started(origin: Vector2, definition: DirectionalTerrainPulseDefinition)
## Feedback facts relayed unchanged from the player and the item controller.
signal player_jumped(world_position: Vector2, is_air_jump: bool)
signal player_landed(world_position: Vector2, impact_speed: float, airborne_seconds: float)
signal player_hard_impact(world_position: Vector2, impact_speed: float)
signal player_knocked_out(world_position: Vector2, impact_speed: float, duration_seconds: float)
signal player_hook_launched(origin: Vector2, target_position: Vector2)
signal player_hook_attached(anchor_position: Vector2, is_moving_target: bool)
signal player_hook_missed(origin: Vector2, target_position: Vector2)
signal player_hook_released(anchor_position: Vector2, by_input: bool)
signal player_liquid_entered(world_position: Vector2, color: Color, speed: float)
signal player_liquid_exited(world_position: Vector2, color: Color, speed: float)
signal player_sand_burrow_changed(world_position: Vector2, is_burrowing: bool)
signal player_hazard_warning(cause: StringName, level: float, color: Color)
signal item_selected(definition: ItemDefinition)
signal tool_used(definition: ItemDefinition, origin: Vector2, direction: Vector2)
signal projectile_spawned(projectile: ItemProjectile, definition: ItemDefinition)
signal projectile_bounced(world_position: Vector2, impact_speed: float, definition: ItemDefinition)
signal projectile_resolved(world_position: Vector2, definition: ItemDefinition, resolution_kind: StringName)
signal fluid_bottle_burst(world_position: Vector2, color: Color)
signal explosive_fuse_armed(world_position: Vector2, fuse_seconds: float)
signal barrel_bumped(world_position: Vector2, impact_speed: float)
signal excavator_deployed(world_position: Vector2)
signal excavator_drilled(world_position: Vector2, dug_cell_count: int)
signal reward_container_opened(world_position: Vector2, container_key: StringName)

@onready var item_controller: RunItemController = %RunItemController
@onready var perk_controller: RunPerkController = %RunPerkController
@onready var world_controller: RunWorldController = %RunWorldController
@onready var world_background: WorldBackground = %WorldBackground
@onready var world_presenter: WorldPresenter = %WorldPresenter
@onready var depth_markers: DepthMarkerPresenter = %DepthMarkers
@onready var gameplay_feedback: GameplayFeedback = %GameplayFeedback

var _configured := false
## Shared by the item controller, which registers barrels, and the player's hook query.
var _grapple_targets := GrappleTargetRegistry.new()


func configure(profile: GenerationProfile, player_scene: PackedScene) -> void:
	if _configured:
		return
	_configured = true
	world_controller.configure(profile, player_scene, world_background, world_presenter, depth_markers)
	world_controller.configure_grapple_targets(_grapple_targets)
	perk_controller.configure()
	item_controller.configure_catalog(world_controller.item_registry(), world_presenter.hex_radius)
	item_controller.configure_perk_controller(perk_controller)
	world_controller.generation_progressed.connect(generation_progressed.emit)
	world_controller.run_ready.connect(_on_run_ready)
	world_controller.player_died.connect(player_died.emit)
	world_controller.player_hazard_status_changed.connect(player_hazard_status_changed.emit)
	item_controller.player_killed.connect(player_killed.emit)
	item_controller.explosion_resolved.connect(explosion_resolved.emit)
	item_controller.flag_planted.connect(flag_planted.emit)
	item_controller.flag_destroyed.connect(flag_destroyed.emit)
	item_controller.flag_flight_changed.connect(flag_flight_changed.emit)
	item_controller.item_thrown.connect(item_thrown.emit)
	item_controller.item_used.connect(item_used.emit)
	item_controller.reward_choices_requested.connect(reward_choices_requested.emit)
	item_controller.pending_reward_invalidated.connect(pending_reward_invalidated.emit)
	item_controller.reward_claimed.connect(reward_claimed.emit)
	item_controller.world_object_destroyed.connect(world_object_destroyed.emit)
	item_controller.terrain_changed.connect(world_controller.refresh_terrain_presentation)
	item_controller.terrain_pulse_started.connect(terrain_pulse_started.emit)
	perk_controller.perks_changed.connect(perks_changed.emit)
	world_controller.player_jumped.connect(player_jumped.emit)
	world_controller.player_landed.connect(player_landed.emit)
	world_controller.player_hard_impact.connect(player_hard_impact.emit)
	world_controller.player_knocked_out.connect(player_knocked_out.emit)
	world_controller.player_hook_launched.connect(player_hook_launched.emit)
	world_controller.player_hook_attached.connect(player_hook_attached.emit)
	world_controller.player_hook_missed.connect(player_hook_missed.emit)
	world_controller.player_hook_released.connect(player_hook_released.emit)
	world_controller.player_liquid_entered.connect(player_liquid_entered.emit)
	world_controller.player_liquid_exited.connect(player_liquid_exited.emit)
	world_controller.player_sand_burrow_changed.connect(player_sand_burrow_changed.emit)
	world_controller.player_hazard_warning.connect(player_hazard_warning.emit)
	item_controller.item_selected.connect(item_selected.emit)
	item_controller.tool_used.connect(tool_used.emit)
	item_controller.projectile_spawned.connect(projectile_spawned.emit)
	item_controller.projectile_bounced.connect(projectile_bounced.emit)
	item_controller.projectile_resolved.connect(projectile_resolved.emit)
	item_controller.fluid_bottle_burst.connect(fluid_bottle_burst.emit)
	item_controller.explosive_fuse_armed.connect(explosive_fuse_armed.emit)
	item_controller.barrel_bumped.connect(barrel_bumped.emit)
	item_controller.excavator_deployed.connect(excavator_deployed.emit)
	item_controller.excavator_drilled.connect(excavator_drilled.emit)
	item_controller.reward_container_opened.connect(reward_container_opened.emit)
	perk_controller.modifiers_changed.connect(_on_perk_modifiers_changed)


func grapple_targets() -> GrappleTargetRegistry:
	return _grapple_targets


func start_run(run_seed: int) -> void:
	world_controller.start_run(run_seed)


func set_active(is_active: bool) -> void:
	world_controller.set_active(is_active)
	item_controller.set_active(is_active)
	if gameplay_feedback != null:
		gameplay_feedback.set_active(is_active)


func apply_pending_reward(choice_index: int) -> bool:
	return item_controller.apply_pending_reward(choice_index)


func cancel_pending_reward() -> void:
	item_controller.cancel_pending_reward()


func reset_simulation_clock() -> void:
	world_controller.reset_simulation_clock()


func advance(delta: float) -> void:
	item_controller.advance(delta)
	world_controller.advance(delta)


func shutdown() -> void:
	world_controller.cancel_generation()
	item_controller.clear_run()
	set_active(false)


func _on_run_ready(next_seed: int) -> void:
	var player := world_controller.player()
	var world := world_controller.current_world()
	if player == null or world == null:
		return
	item_controller.configure_run(
		player,
		world,
		world_controller.terrain_registry(),
		world_presenter.hex_radius,
		world_controller.simulation_backend(),
		world_controller.generation_result().item_chest_spawns,
		world_controller.generation_result().perk_geode_spawns,
		world_controller.generation_result().explosive_barrel_spawns,
		_grapple_targets
	)
	player.set_perk_modifiers(perk_controller.modifiers())
	item_controller.set_perk_modifiers(perk_controller.modifiers())
	_apply_presentation_perk_modifiers(perk_controller.modifiers())
	run_ready.emit(next_seed)


func _on_perk_modifiers_changed(modifiers: PerkModifierSnapshot) -> void:
	var player := world_controller.player()
	if player != null:
		player.set_perk_modifiers(modifiers)
	item_controller.set_perk_modifiers(modifiers)
	_apply_presentation_perk_modifiers(modifiers)


func _apply_presentation_perk_modifiers(modifiers: PerkModifierSnapshot) -> void:
	if world_presenter == null:
		return
	var offset := 0.0 if modifiers == null else float(modifiers.presentation.value("lighting_threshold_offset", 0.0))
	world_presenter.set_lighting_threshold_offset(offset)
