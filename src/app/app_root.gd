class_name AppRoot
extends Control


signal generation_started
signal gameplay_started

@export var generation_profile: GenerationProfile = preload("res://config/generation/default_profile.tres")
@export var player_scene: PackedScene
@export var leaderboard_config: LeaderboardConfig = preload("res://config/leaderboard/simpleboards.tres")

@onready var ui: AppUiController = %UiLayer
@onready var score_controller: ScoreController = %ScoreController
@onready var item_controller: RunItemController = %RunItemController
@onready var world_controller: RunWorldController = %RunWorldController
@onready var world_presenter: WorldPresenter = %WorldPresenter
@onready var depth_markers: Node2D = %DepthMarkers
@onready var gameplay_feedback: GameplayFeedback = %GameplayFeedback
@onready var audio_director: AudioDirector = %AudioDirector
@onready var world_side_boundaries: WorldSideBoundaries = %WorldSideBoundaries

var _run_coordinator := RunCoordinator.new()
var _current_seed := 0
var _pending_score_depth := -1
var _terminal_outcome_locked := false
var _previous_play_state: StringName = RunPhase.PLAYING
var _enable_menu_preview := true
var _test_mode := false
var _configured_save_path := ""
var _injected_leaderboard_service: LeaderboardService


func _ready() -> void:
	_current_seed = _initial_run_seed()
	world_controller.configure(generation_profile, player_scene, world_presenter, depth_markers, world_side_boundaries)
	item_controller.configure_catalog(world_controller.item_registry(), world_presenter.hex_radius)
	if not _configured_save_path.is_empty():
		score_controller.configure_save_path(_configured_save_path)
	score_controller.configure(leaderboard_config, _test_mode, _injected_leaderboard_service)
	_connect_controller_signals()
	_apply_state(_run_coordinator.current_state)
	if _enable_menu_preview:
		world_controller.start_preview(_current_seed)
	if score_controller.has_service():
		_refresh_leaderboard()
		score_controller.retry_pending()


func _connect_controller_signals() -> void:
	_run_coordinator.state_changed.connect(_on_state_changed)
	ui.start_requested.connect(_on_start_requested)
	ui.leaderboard_requested.connect(_on_leaderboard_requested)
	ui.menu_requested.connect(_on_menu_requested)
	ui.score_confirmed.connect(_on_confirm_score_requested)
	ui.restart_requested.connect(_on_restart_requested)
	world_controller.generation_progressed.connect(ui.show_generation_progress)
	world_controller.run_ready.connect(_on_run_ready)
	world_controller.player_died.connect(_on_player_death_requested)
	score_controller.profile_changed.connect(_update_depth_markers)
	score_controller.leaderboard_changed.connect(_on_leaderboard_top_loaded)
	score_controller.submission_finished.connect(_on_leaderboard_submission_finished)
	score_controller.pending_retry_finished.connect(_on_pending_retry_finished)
	item_controller.player_killed.connect(_on_player_death_requested)
	item_controller.bomb_exploded.connect(_on_bomb_exploded)
	item_controller.flag_planted.connect(_on_flag_planted)
	item_controller.flag_destroyed.connect(_on_flag_destroyed)
	item_controller.flag_flight_changed.connect(_on_flag_flight_changed)
	item_controller.item_thrown.connect(audio_director.play_throw)


func _initial_run_seed() -> int:
	if _test_mode:
		return SeedUtils.seed_from_text("claim-earth-default-seed")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi())


func get_run_state() -> StringName:
	return _run_coordinator.current_state


func transition_to(next_state: StringName) -> void:
	_run_coordinator.transition_to(next_state)


func configure_save_path_for_test(save_path: String) -> void:
	_configured_save_path = save_path


func set_test_mode(enabled: bool) -> void:
	_test_mode = enabled
	if enabled:
		_enable_menu_preview = false


func set_menu_preview_enabled(enabled: bool) -> void:
	_enable_menu_preview = enabled


func configure_leaderboard_service_for_test(service: LeaderboardService) -> void:
	_injected_leaderboard_service = service


func start_run_for_test(run_seed: int) -> void:
	_current_seed = run_seed
	_enable_menu_preview = false
	transition_to(RunPhase.GENERATING)


func get_player() -> PlayerController:
	return world_controller.player()


func active_projectile_count() -> int:
	return item_controller.active_projectile_count()


func select_item_for_test(index: int) -> void:
	item_controller.select_index(index)


func throw_selected_item_for_test(aim_position: Vector2, bypass_cooldown: bool = false) -> bool:
	return item_controller.throw_selected(aim_position, bypass_cooldown)


func last_generation_result_for_test() -> WorldGenerationResult:
	return world_controller.generation_result()


func pending_score_depth() -> int:
	return _pending_score_depth


func simulation_backend() -> TerrainSimulationBackend:
	return world_controller.simulation_backend()


func current_world() -> WorldGrid:
	return world_controller.current_world()


func terrain_registry() -> TerrainRegistry:
	return world_controller.terrain_registry()


func _on_start_requested() -> void:
	transition_to(RunPhase.GENERATING)


func _on_leaderboard_requested() -> void:
	transition_to(RunPhase.LEADERBOARD)


func _on_menu_requested() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _on_restart_requested() -> void:
	transition_to(RunPhase.GENERATING)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputActions.PAUSE):
		return
	match _run_coordinator.current_state:
		RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT:
			_previous_play_state = _run_coordinator.current_state
			transition_to(RunPhase.PAUSED)
		RunPhase.PAUSED:
			transition_to(_previous_play_state)
		RunPhase.LEADERBOARD:
			transition_to(RunPhase.MAIN_MENU)
		RunPhase.NAME_ENTRY:
			transition_to(RunPhase.RESULT)


func _on_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	_apply_state(next_state)


func _apply_state(next_state: StringName) -> void:
	ui.apply_state(next_state, _current_seed, score_controller.storage_warning, _pending_score_depth, score_controller.last_player_name)
	match next_state:
		RunPhase.MAIN_MENU, RunPhase.LEADERBOARD, RunPhase.NAME_ENTRY, RunPhase.PAUSED, RunPhase.SUBMITTING, RunPhase.DEATH, RunPhase.RESULT:
			world_controller.set_active(false)
		RunPhase.GENERATING:
			world_controller.set_active(false)
			_terminal_outcome_locked = false
			_pending_score_depth = -1
			item_controller.clear_run()
			generation_started.emit()
			world_controller.start_run(_current_seed)
		RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT:
			ui.dismiss_menu_shell()
			world_controller.set_active(true)
			if next_state == RunPhase.PLAYING:
				gameplay_started.emit()
		_:
			push_error("Unknown run state: %s" % [next_state])
	if next_state == RunPhase.LEADERBOARD:
		_refresh_leaderboard()


func _on_run_ready(next_seed: int) -> void:
	_current_seed = next_seed
	if _run_coordinator.current_state == RunPhase.GENERATING:
		_configure_items_for_current_world()
		transition_to(RunPhase.PLAYING)


func _configure_items_for_current_world() -> void:
	if get_player() == null or current_world() == null:
		return
	item_controller.configure_run(get_player(), current_world(), terrain_registry(), world_controller.chunk_activity_index(), world_presenter.hex_radius)


func _process(delta: float) -> void:
	if _run_coordinator.current_state not in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]:
		return
	if get_player() == null:
		return
	item_controller.handle_input(get_global_mouse_position())
	world_controller.advance(delta)
	_refresh_play_status()


func _refresh_play_status() -> void:
	var item_status: Dictionary = item_controller.inventory_status()
	if String(item_status["selected_name"]).is_empty() or get_player() == null:
		ui.show_play_status("No items configured", "")
		return
	var player_depth := HexMetrics.offset_for_world(get_player().global_position, world_presenter.hex_radius).y
	ui.show_run_status(player_depth, score_controller.personal_best_depth, get_player().is_grapple_attached(), item_status)


func _on_bomb_exploded(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool) -> void:
	audio_director.play_explosion(is_large)
	gameplay_feedback.spawn_ring(impact_position, color, blast_radius * world_presenter.hex_radius * 0.75)
	if get_player() != null:
		get_player().camera.apply_shake(10.0 if is_large else 6.0)


func _on_flag_planted(depth: int, landing_position: Vector2) -> void:
	if _terminal_outcome_locked:
		return
	_pending_score_depth = depth
	audio_director.play_flag_plant()
	gameplay_feedback.spawn_ring(landing_position, Color(0.98, 0.86, 0.32, 0.9), 18.0)
	transition_to(RunPhase.NAME_ENTRY)


func _on_flag_destroyed() -> void:
	_complete_terminal_outcome("The flag melted in lava.", RunPhase.DEATH)


func _on_flag_flight_changed(in_flight: bool) -> void:
	if _terminal_outcome_locked:
		return
	if in_flight:
		transition_to(RunPhase.FLAG_IN_FLIGHT)
	elif _run_coordinator.current_state == RunPhase.FLAG_IN_FLIGHT:
		transition_to(RunPhase.PLAYING)


func _on_player_death_requested(cause: StringName) -> void:
	audio_director.play_death()
	if get_player() != null:
		get_player().camera.apply_shake(14.0)
	_complete_terminal_outcome("Cause: %s" % String(cause).capitalize(), RunPhase.DEATH)


func _complete_terminal_outcome(message: String, next_state: StringName) -> void:
	if _terminal_outcome_locked:
		return
	_terminal_outcome_locked = true
	ui.show_result(message)
	transition_to(next_state)


func _on_confirm_score_requested(player_name: String) -> void:
	var result_data: WorldGenerationResult = world_controller.generation_result()
	var score_seed := result_data.final_seed if result_data != null else _current_seed
	var confirmation: Dictionary = score_controller.confirm_score(player_name, _pending_score_depth, score_seed)
	if not bool(confirmation["accepted"]):
		ui.show_name_error(String(confirmation["error"]))
		return
	audio_director.play_ui_confirm()
	_update_depth_markers()
	var summary := "%s claimed depth %d. Personal best: %d." % [score_controller.last_player_name, _pending_score_depth, score_controller.personal_best_depth]
	if not bool(confirmation["submitted"]):
		ui.show_result(summary)
		transition_to(RunPhase.RESULT)
		return
	ui.show_result(summary + "\nSubmitting score...")
	transition_to(RunPhase.SUBMITTING)


func _update_depth_markers() -> void:
	depth_markers.set_personal_depth(score_controller.personal_best_depth)
	depth_markers.set_global_depth(score_controller.global_best_depth, score_controller.global_best_player)


func _refresh_leaderboard() -> void:
	ui.show_leaderboard_loading()
	if not score_controller.fetch_top(10):
		ui.show_leaderboard("Leaderboard unavailable.", "[center]No entries loaded yet.[/center]")


func _on_leaderboard_top_loaded(entries: Array[LeaderboardEntry], failed: bool, message: String) -> void:
	ui.show_leaderboard_entries(entries, failed, message)
	_update_depth_markers()


func _on_leaderboard_submission_finished(submission: ScoreSubmission, _entry: LeaderboardEntry, failed: bool, message: String) -> void:
	ui.show_submission_result(submission.player_name, submission.score_depth, score_controller.personal_best_depth, failed, message)
	_update_depth_markers()
	if not failed:
		_refresh_leaderboard()
	transition_to(RunPhase.RESULT)


func _on_pending_retry_finished(successful_count: int, message: String) -> void:
	if successful_count > 0:
		_refresh_leaderboard()
	elif _run_coordinator.current_state == RunPhase.LEADERBOARD and not message.is_empty():
		ui.leaderboard_status.text = message
