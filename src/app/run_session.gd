## Composes the disposable gameplay session for one preview or active run.
class_name RunSession
extends Node


signal generation_progressed(progress: float, label: String)
signal run_ready(next_seed: int)
signal player_died(cause: StringName)
signal player_hazard_status_changed(statuses: Array)
signal player_killed(cause: StringName)
signal explosion_resolved(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool)
signal flag_planted(depth: int, landing_position: Vector2)
signal flag_destroyed
signal flag_flight_changed(in_flight: bool)
signal item_thrown
signal reward_choices_requested(title: String, choices: Array)
signal pending_reward_invalidated
signal perks_changed(perks: Array)
signal terrain_pulse_started(origin: Vector2, definition: DirectionalTerrainPulseDefinition)

@onready var item_controller: RunItemController = %RunItemController
@onready var perk_controller: RunPerkController = %RunPerkController
@onready var world_controller: RunWorldController = %RunWorldController
@onready var world_background: WorldBackground = %WorldBackground
@onready var world_presenter: WorldPresenter = %WorldPresenter
@onready var depth_markers: DepthMarkerPresenter = %DepthMarkers
@onready var gameplay_feedback: GameplayFeedback = %GameplayFeedback
@onready var world_side_boundaries: WorldSideBoundaries = %WorldSideBoundaries

var _configured := false


func configure(profile: GenerationProfile, player_scene: PackedScene) -> void:
	if _configured:
		return
	_configured = true
	world_controller.configure(profile, player_scene, world_background, world_presenter, depth_markers, world_side_boundaries)
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
	item_controller.reward_choices_requested.connect(reward_choices_requested.emit)
	item_controller.pending_reward_invalidated.connect(pending_reward_invalidated.emit)
	item_controller.terrain_changed.connect(world_controller.refresh_terrain_presentation)
	item_controller.terrain_pulse_started.connect(terrain_pulse_started.emit)
	perk_controller.perks_changed.connect(perks_changed.emit)
	perk_controller.modifiers_changed.connect(_on_perk_modifiers_changed)


func start_run(run_seed: int) -> void:
	world_controller.start_run(run_seed)


func start_preview(run_seed: int) -> void:
	world_controller.start_preview(run_seed)


func set_active(is_active: bool) -> void:
	world_controller.set_active(is_active)
	item_controller.set_active(is_active)


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
		world_controller.generation_result().perk_geode_spawns
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
