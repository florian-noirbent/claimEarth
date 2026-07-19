## Owns the persistent application shell and routes UI intents to run-state changes.
class_name AppRoot
extends Control


signal generation_started
signal gameplay_started

@export var run_session_scene: PackedScene
@export var generation_profile: GenerationProfile
@export var player_scene: PackedScene
@export var leaderboard_config: LeaderboardConfig

@onready var ui: AppUiController = %UiLayer
@onready var score_controller: ScoreController = %ScoreController
@onready var audio_director: AudioDirector = %AudioDirector

var item_controller: RunItemController:
	get:
		return _session.item_controller if is_instance_valid(_session) else null
var perk_controller: RunPerkController:
	get:
		return _session.perk_controller if is_instance_valid(_session) else null
var world_controller: RunWorldController:
	get:
		return _session.world_controller if is_instance_valid(_session) else null
var world_presenter: WorldPresenter:
	get:
		return _session.world_presenter if is_instance_valid(_session) else null
var depth_markers: DepthMarkerPresenter:
	get:
		return _session.depth_markers if is_instance_valid(_session) else null
var gameplay_feedback: GameplayFeedback:
	get:
		return _session.gameplay_feedback if is_instance_valid(_session) else null
var world_side_boundaries: WorldSideBoundaries:
	get:
		return _session.world_side_boundaries if is_instance_valid(_session) else null

var _run_coordinator := RunCoordinator.new()
var _session: RunSession
var _session_change_serial := 0
var _current_seed := 0
var _pending_score_depth := -1
var _terminal_outcome_locked := false
var _relentless_flag_drop_pending := false
var _previous_play_state: StringName = RunPhase.PLAYING
var _reward_return_state: StringName = RunPhase.PLAYING
var _test_mode := false
var _configured_save_path := ""
var _configured_settings_path := ""
var _injected_leaderboard_service: LeaderboardService
var _input_controller: GameplayInputController
var _settings_controller: AppSettingsController
var _developer_tools: DeveloperToolsController


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_session):
		_session.reset_simulation_clock()


func _ready() -> void:
	_current_seed = _initial_run_seed()
	_input_controller = GameplayInputController.new()
	add_child(_input_controller)
	_settings_controller = AppSettingsController.new()
	add_child(_settings_controller)
	if OS.is_debug_build():
		_developer_tools = DeveloperToolsController.new()
		add_child(_developer_tools)
		_developer_tools.configure(self)
	if not _configured_settings_path.is_empty():
		_settings_controller.configure(_configured_settings_path)
	else:
		_settings_controller.configure()
	if not _configured_save_path.is_empty():
		score_controller.configure_save_path(_configured_save_path)
	score_controller.configure(leaderboard_config, _test_mode, _injected_leaderboard_service)
	_connect_persistent_signals()
	ui.set_web_fullscreen_available(OS.has_feature("web"))
	_refresh_fullscreen_state()
	get_viewport().size_changed.connect(_refresh_fullscreen_state)
	_apply_phone_controls_enabled(false if _test_mode else _settings_controller.phone_controls_enabled())
	_apply_frame_limit(0 if _test_mode else _settings_controller.frame_limit_fps())
	_apply_state(_run_coordinator.current_state)
	if score_controller.has_service():
		_refresh_leaderboard()
		score_controller.retry_pending()


func _connect_persistent_signals() -> void:
	_run_coordinator.state_changed.connect(_on_state_changed)
	ui.start_requested.connect(_on_start_requested)
	ui.leaderboard_requested.connect(_on_leaderboard_requested)
	ui.menu_requested.connect(_on_menu_requested)
	ui.pause_requested.connect(_toggle_pause)
	ui.fullscreen_requested.connect(_toggle_fullscreen)
	ui.item_selected.connect(_on_item_selected)
	ui.reward_selected.connect(_on_reward_selected)
	ui.score_confirmed.connect(_on_confirm_score_requested)
	ui.restart_requested.connect(_on_restart_requested)
	ui.phone_controls_changed.connect(_settings_controller.set_phone_controls_enabled)
	ui.frame_limit_changed.connect(_settings_controller.set_frame_limit_fps)
	ui.touch_move_changed.connect(_input_controller.set_touch_move)
	ui.touch_aim_changed.connect(_input_controller.set_touch_aim)
	ui.touch_aim_released.connect(_input_controller.release_touch_aim)
	ui.touch_hook_pressed.connect(_input_controller.press_touch_hook)
	ui.touch_hook_released.connect(_input_controller.release_touch_hook)
	_input_controller.throw_requested.connect(_on_throw_requested)
	_input_controller.item_cycle_requested.connect(_on_item_cycle_requested)
	_input_controller.item_selected_requested.connect(_on_item_selected)
	_input_controller.item_shortcut_requested.connect(_on_item_shortcut_requested)
	_input_controller.pause_requested.connect(_toggle_pause)
	_settings_controller.phone_controls_changed.connect(_apply_phone_controls_enabled)
	_settings_controller.frame_limit_changed.connect(_apply_frame_limit)
	score_controller.profile_changed.connect(_update_depth_markers)
	score_controller.leaderboard_changed.connect(_on_leaderboard_top_loaded)
	score_controller.submission_finished.connect(_on_leaderboard_submission_finished)
	score_controller.pending_retry_finished.connect(_on_pending_retry_finished)


func _connect_session_signals(session: RunSession) -> void:
	session.generation_progressed.connect(ui.show_generation_progress)
	session.run_ready.connect(_on_run_ready)
	session.player_died.connect(_on_player_death_requested)
	session.player_hazard_status_changed.connect(ui.show_hazard_statuses)
	session.player_killed.connect(_on_player_death_requested)
	session.explosion_resolved.connect(_on_explosion_resolved)
	session.flag_planted.connect(_on_flag_planted)
	session.flag_destroyed.connect(_on_flag_destroyed)
	session.flag_flight_changed.connect(_on_flag_flight_changed)
	session.item_thrown.connect(audio_director.play_throw)
	session.reward_choices_requested.connect(_on_reward_choices_requested)
	session.pending_reward_invalidated.connect(_on_pending_reward_invalidated)
	session.terrain_pulse_started.connect(_on_terrain_pulse_started)
	session.perks_changed.connect(_on_perks_changed)


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


func configure_settings_path_for_test(settings_path: String) -> void:
	_configured_settings_path = settings_path


func set_test_mode(enabled: bool) -> void:
	_test_mode = enabled


func configure_leaderboard_service_for_test(service: LeaderboardService) -> void:
	_injected_leaderboard_service = service


func start_run_for_test(run_seed: int) -> void:
	_current_seed = run_seed
	transition_to(RunPhase.GENERATING)


func get_player() -> PlayerController:
	return world_controller.player() if world_controller != null else null


func active_projectile_count() -> int:
	return item_controller.active_projectile_count() if item_controller != null else 0


func active_session_count() -> int:
	var count := 0
	for child in get_children():
		if child is RunSession and not child.is_queued_for_deletion():
			count += 1
	return count


func select_item_for_test(index: int) -> void:
	if item_controller != null:
		item_controller.select_index(index)


func throw_selected_item_for_test(aim_position: Vector2, bypass_cooldown: bool = false) -> bool:
	return item_controller.throw_selected(aim_position, bypass_cooldown) if item_controller != null else false


func inventory_status_for_test() -> Dictionary:
	return item_controller.inventory_status() if item_controller != null else {}


func item_chest_count_for_test() -> int:
	return item_controller.item_chest_count() if item_controller != null else 0


func last_generation_result_for_test() -> WorldGenerationResult:
	return world_controller.generation_result() if world_controller != null else null


func pending_score_depth() -> int:
	return _pending_score_depth


func simulation_backend() -> TerrainSimulationBackend:
	return world_controller.simulation_backend() if world_controller != null else null


func current_world() -> WorldGrid:
	return world_controller.current_world() if world_controller != null else null


func terrain_registry() -> TerrainRegistry:
	return world_controller.terrain_registry() if world_controller != null else null


func _on_start_requested() -> void:
	transition_to(RunPhase.GENERATING)


func _on_leaderboard_requested() -> void:
	transition_to(RunPhase.LEADERBOARD)


func _on_menu_requested() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _on_restart_requested() -> void:
	transition_to(RunPhase.GENERATING)


func _on_item_selected(index: int) -> void:
	if _run_coordinator.current_state != RunPhase.PLAYING or item_controller == null:
		return
	item_controller.select_index(index)


func _on_item_shortcut_requested(shortcut: int) -> void:
	if _run_coordinator.current_state != RunPhase.PLAYING or item_controller == null:
		return
	item_controller.select_dynamic_shortcut(shortcut)


func _on_item_cycle_requested(direction: int) -> void:
	if _run_coordinator.current_state != RunPhase.PLAYING or item_controller == null:
		return
	item_controller.cycle_selection(direction)


func _on_throw_requested(aim_position: Vector2) -> void:
	if _run_coordinator.current_state not in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT] or item_controller == null:
		return
	if item_controller.is_flag_in_flight():
		return
	item_controller.throw_selected(aim_position)


func _unhandled_input(event: InputEvent) -> void:
	if ui.handle_reward_picker_input(event):
		get_viewport().set_input_as_handled()
		return
	if _input_controller != null and _input_controller.handle_unhandled_input(event, get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		return


func _toggle_pause() -> void:
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


func _toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	var next_mode := DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen_mode(current_mode) else DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(next_mode)
	_refresh_fullscreen_state()


func _refresh_fullscreen_state() -> void:
	ui.set_fullscreen_active(_is_fullscreen_mode(DisplayServer.window_get_mode()))


func _is_fullscreen_mode(mode: DisplayServer.WindowMode) -> bool:
	return mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _on_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	_apply_state(next_state)


func _apply_state(next_state: StringName) -> void:
	ui.apply_state(next_state, _current_seed, score_controller.storage_warning, _pending_score_depth, score_controller.last_player_name)
	if next_state not in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]:
		_input_controller.clear_virtual_input()
	match next_state:
		RunPhase.MAIN_MENU:
			_set_session_active(false)
			_enter_main_menu()
		RunPhase.LEADERBOARD, RunPhase.NAME_ENTRY, RunPhase.PAUSED, RunPhase.REWARD_PICKER, RunPhase.SUBMITTING, RunPhase.DEATH, RunPhase.RESULT:
			_set_session_active(false)
		RunPhase.GENERATING:
			_terminal_outcome_locked = false
			_relentless_flag_drop_pending = false
			_pending_score_depth = -1
			generation_started.emit()
			_start_new_run()
		RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT:
			ui.dismiss_menu_shell()
			_set_session_active(true)
			if next_state == RunPhase.PLAYING:
				gameplay_started.emit()
		_:
			push_error("Unknown run state: %s" % [next_state])
	if next_state == RunPhase.LEADERBOARD:
		_refresh_leaderboard()
func _start_new_run() -> void:
	var serial := _begin_session_change()
	var session := await _replace_session(serial)
	if session == null or serial != _session_change_serial or _run_coordinator.current_state != RunPhase.GENERATING:
		return
	session.start_run(_current_seed)


func _enter_main_menu() -> void:
	_begin_session_change()
	await _dispose_current_session()


func _begin_session_change() -> int:
	_session_change_serial += 1
	return _session_change_serial


func _replace_session(serial: int) -> RunSession:
	await _dispose_current_session()
	if serial != _session_change_serial:
		return null
	var session := run_session_scene.instantiate() as RunSession
	add_child(session)
	session.configure(generation_profile, player_scene)
	_connect_session_signals(session)
	_session = session
	_update_depth_markers()
	return session


func _dispose_current_session() -> void:
	if not is_instance_valid(_session):
		return
	_session.shutdown()
	_session.queue_free()
	_session = null
	await get_tree().process_frame


func _set_session_active(is_active: bool) -> void:
	if is_instance_valid(_session):
		_session.set_active(is_active)


func _on_run_ready(next_seed: int) -> void:
	_current_seed = next_seed
	if get_player() != null:
		get_player().configure_input_controller(_input_controller)
	if _run_coordinator.current_state == RunPhase.GENERATING:
		transition_to(RunPhase.PLAYING)


func _apply_phone_controls_enabled(enabled: bool) -> void:
	ui.set_phone_controls_enabled(enabled)
	_input_controller.set_phone_controls_enabled(enabled)


func _apply_frame_limit(fps: int) -> void:
	Engine.max_fps = fps
	ui.set_frame_limit_fps(fps)


func _process(delta: float) -> void:
	if _run_coordinator.current_state not in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]:
		return
	if not is_instance_valid(_session) or get_player() == null:
		return
	_session.advance(delta)
	_refresh_play_status()


func _refresh_play_status() -> void:
	var item_status: Dictionary = item_controller.inventory_status()
	if String(item_status["selected_name"]).is_empty() or get_player() == null:
		ui.show_play_status("No items configured", "")
		return
	var player_depth := HexMetrics.offset_for_world(get_player().global_position, world_presenter.hex_radius).y
	ui.show_run_status(player_depth, score_controller.personal_best_depth, get_player().is_grapple_attached(), item_status)


func _on_explosion_resolved(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool) -> void:
	audio_director.play_explosion(is_large)
	if gameplay_feedback != null and world_presenter != null:
		gameplay_feedback.spawn_ring(impact_position, color, blast_radius * world_presenter.hex_radius * 0.75)
	if get_player() != null:
		get_player().camera.apply_shake(10.0 if is_large else 6.0)


func _on_terrain_pulse_started(origin: Vector2, definition: DirectionalTerrainPulseDefinition) -> void:
	if gameplay_feedback == null or world_presenter == null or definition == null:
		return
	gameplay_feedback.spawn_directional_pulse(
		origin,
		definition.color,
		definition.width * world_presenter.hex_radius * 1.5,
		definition.step_count * sqrt(3.0) * world_presenter.hex_radius,
		definition.pulse_tick_count * definition.step_interval_seconds,
		definition.front_load_decay
	)


func _on_flag_planted(depth: int, landing_position: Vector2) -> void:
	if _terminal_outcome_locked:
		return
	_pending_score_depth = depth
	_cancel_pending_reward()
	audio_director.play_flag_plant()
	if gameplay_feedback != null:
		gameplay_feedback.spawn_ring(landing_position, Color(0.98, 0.86, 0.32, 0.9), 18.0)
	transition_to(RunPhase.NAME_ENTRY)


func _on_flag_destroyed(cause: StringName) -> void:
	var message := "The flag dissolved in acid." if cause == &"acid" else "The flag melted in lava."
	_complete_terminal_outcome(message, RunPhase.DEATH)


func _on_flag_flight_changed(in_flight: bool) -> void:
	if _terminal_outcome_locked:
		return
	if in_flight:
		transition_to(RunPhase.FLAG_IN_FLIGHT)
	elif _run_coordinator.current_state == RunPhase.FLAG_IN_FLIGHT:
		transition_to(RunPhase.PLAYING)


func _on_player_death_requested(cause: StringName) -> void:
	if _relentless_flag_drop_pending:
		return
	if item_controller != null and item_controller.drop_flag_on_player_death():
		_relentless_flag_drop_pending = true
		return
	audio_director.play_death()
	if get_player() != null:
		get_player().camera.apply_shake(14.0)
	_complete_terminal_outcome("Cause: %s" % String(cause).capitalize(), RunPhase.DEATH)


func _complete_terminal_outcome(message: String, next_state: StringName) -> void:
	if _terminal_outcome_locked:
		return
	_terminal_outcome_locked = true
	_relentless_flag_drop_pending = false
	_cancel_pending_reward()
	ui.show_result(message)
	transition_to(next_state)


func _on_confirm_score_requested(player_name: String) -> void:
	var result_data := last_generation_result_for_test()
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
	if depth_markers == null:
		return
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


func _on_reward_choices_requested(title: String, choices: Array) -> void:
	if _terminal_outcome_locked or _run_coordinator.current_state not in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]:
		_cancel_pending_reward()
		return
	_reward_return_state = _run_coordinator.current_state
	transition_to(RunPhase.REWARD_PICKER)
	ui.show_reward_choices(title, choices)


func _on_reward_selected(index: int) -> void:
	if _run_coordinator.current_state != RunPhase.REWARD_PICKER or not is_instance_valid(_session):
		return
	ui.set_reward_picker_enabled(false)
	if not _session.apply_pending_reward(index):
		ui.set_reward_picker_enabled(true)
		return
	transition_to(_reward_return_state)


func _cancel_pending_reward() -> void:
	if is_instance_valid(_session):
		_session.cancel_pending_reward()


func _on_pending_reward_invalidated() -> void:
	if _run_coordinator.current_state == RunPhase.REWARD_PICKER:
		transition_to(_reward_return_state)


func _on_perks_changed(perks: Array) -> void:
	var views: Array[PerkViewData] = []
	for perk_value in perks:
		var perk := perk_value as PerkDefinition
		if perk != null:
			views.append(PerkViewData.new(StringName(str(perk.stable_id)), perk.display_name, perk.description, perk.icon))
	ui.show_perks(views)
