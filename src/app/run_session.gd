## Composes the disposable gameplay session for one preview or active run.
class_name RunSession
extends Node


signal generation_progressed(progress: float, label: String)
signal run_ready(next_seed: int)
signal player_died(cause: StringName)
signal player_killed(cause: StringName)
signal bomb_exploded(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool)
signal flag_planted(depth: int, landing_position: Vector2)
signal flag_destroyed
signal flag_flight_changed(in_flight: bool)
signal item_thrown

@onready var item_controller: RunItemController = %RunItemController
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
	item_controller.configure_catalog(world_controller.item_registry(), world_presenter.hex_radius)
	world_controller.generation_progressed.connect(generation_progressed.emit)
	world_controller.run_ready.connect(_on_run_ready)
	world_controller.player_died.connect(player_died.emit)
	item_controller.player_killed.connect(player_killed.emit)
	item_controller.bomb_exploded.connect(bomb_exploded.emit)
	item_controller.flag_planted.connect(flag_planted.emit)
	item_controller.flag_destroyed.connect(flag_destroyed.emit)
	item_controller.flag_flight_changed.connect(flag_flight_changed.emit)
	item_controller.item_thrown.connect(item_thrown.emit)


func start_run(run_seed: int) -> void:
	world_controller.start_run(run_seed)


func start_preview(run_seed: int) -> void:
	world_controller.start_preview(run_seed)


func set_active(is_active: bool) -> void:
	world_controller.set_active(is_active)


func advance(delta: float) -> void:
	item_controller.advance(delta)
	world_controller.advance(delta)


func handle_unhandled_input(event: InputEvent, aim_position: Vector2) -> void:
	item_controller.handle_unhandled_input(event, aim_position)


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
		world_controller.chunk_activity_index(),
		world_presenter.hex_radius,
		world_controller.simulation_backend()
	)
	run_ready.emit(next_seed)
