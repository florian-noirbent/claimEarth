class_name AppRoot
extends Control


signal generation_started
signal gameplay_started

const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")
const CooperativeChunkBackendScript = preload("res://src/simulation/cooperative_chunk_backend.gd")
const BUILD_DIAGNOSTIC_ID := "web-debug-2026-06-14-a"

@export var generation_profile: GenerationProfile = preload("res://config/generation/default_profile.tres")
@export var player_scene: PackedScene
@export var leaderboard_config = preload("res://config/leaderboard/simpleboards.tres")

@onready var ui: AppUiController = %UiLayer
@onready var score_controller: ScoreController = %ScoreController
@onready var item_controller: RunItemController = %RunItemController
@onready var title_label: Label = ui.title_label
@onready var owner_label: Label = ui.owner_label
@onready var status_label: Label = ui.status_label
@onready var menu_background: ColorRect = ui.menu_background
@onready var menu_root: CenterContainer = ui.menu_root
@onready var menu_panel: VBoxContainer = ui.menu_panel
@onready var menu_start_button: Button = ui.menu_start_button
@onready var overlay_root: MarginContainer = ui.overlay_root
@onready var playing_panel: VBoxContainer = ui.playing_panel
@onready var back_to_menu_button: Button = ui.back_to_menu_button
@onready var name_entry_panel: PanelContainer = ui.name_entry_panel
@onready var player_name_input: LineEdit = ui.player_name_input
@onready var confirm_score_button: Button = ui.confirm_score_button
@onready var result_panel: PanelContainer = ui.result_panel
@onready var result_status: Label = ui.result_status
@onready var leaderboard_rows: RichTextLabel = ui.leaderboard_rows
@onready var world_presenter: WorldPresenter = %WorldPresenter
@onready var depth_markers: Node2D = %DepthMarkers
@onready var gameplay_feedback = %GameplayFeedback
@onready var audio_director = %AudioDirector
@onready var world_side_boundaries: WorldSideBoundaries = %WorldSideBoundaries

var _run_coordinator := RunCoordinator.new()
var _terrain_registry := TerrainRegistry.new()
var _item_registry := ItemRegistry.new()
var _generation_task := WorldGenerationTask.new()
var _last_generation_result: WorldGenerationResult
var _current_seed := 0
var _chunk_activity_index: ChunkActivityIndex
var _player: PlayerController
var _grapple_anchor_query = WorldGrappleAnchorQueryScript.new()
var _simulation_backend = CooperativeChunkBackendScript.new()
var _simulation_accumulator := 0.0
var _pending_score_depth := -1
var _terminal_outcome_locked := false
var _previous_play_state: StringName = RunPhase.PLAYING
var _enable_menu_preview := true
var _test_mode := false
var _configured_save_path := ""
var _injected_leaderboard_service


func _ready() -> void:
	_diag("ready: begin")
	_current_seed = _initial_run_seed()
	_diag("ready: seed initialized")
	_configure_registries()
	item_controller.configure_catalog(_item_registry, world_presenter.hex_radius)
	_diag("ready: registries configured")
	if not _configured_save_path.is_empty():
		score_controller.configure_save_path(_configured_save_path)
	score_controller.configure(leaderboard_config, _test_mode, _injected_leaderboard_service)
	_diag("ready: local state loaded")
	_diag("ready: leaderboard configured")
	_run_coordinator.state_changed.connect(_on_state_changed)
	_generation_task.progress_changed.connect(_on_generation_progress_changed)
	ui.start_requested.connect(_on_start_pressed)
	ui.leaderboard_requested.connect(_on_leaderboard_pressed)
	ui.menu_requested.connect(_on_back_to_menu_pressed)
	ui.score_confirmed.connect(_on_confirm_score_requested)
	ui.restart_requested.connect(_on_restart_pressed)
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
	_apply_state(_run_coordinator.current_state)
	_start_menu_preview()
	if score_controller.has_service():
		_refresh_leaderboard()
		_retry_pending_submissions()
	_diag("ready: complete")


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


func configure_leaderboard_service_for_test(service) -> void:
	_injected_leaderboard_service = service


func start_run_for_test(seed: int) -> void:
	_current_seed = seed
	_enable_menu_preview = false
	transition_to(RunPhase.GENERATING)


func get_player() -> PlayerController:
	return _player


func active_projectile_count() -> int:
	return item_controller.active_projectile_count()


func select_item_for_test(index: int) -> void:
	item_controller.select_index(index)


func throw_selected_item_for_test(aim_position: Vector2, bypass_cooldown: bool = false) -> bool:
	return item_controller.throw_selected(aim_position, bypass_cooldown)


func pending_score_depth() -> int:
	return _pending_score_depth


func simulation_backend():
	return _simulation_backend


func current_world() -> WorldGrid:
	return _last_generation_result.world if _last_generation_result != null else null


func terrain_registry() -> TerrainRegistry:
	return _terrain_registry


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


func _on_start_pressed() -> void:
	_diag("start button pressed")
	transition_to(RunPhase.GENERATING)


func _on_leaderboard_pressed() -> void:
	transition_to(RunPhase.LEADERBOARD)


func _on_back_to_menu_pressed() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _on_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	_apply_state(next_state)


func _apply_state(next_state: StringName) -> void:
	ui.apply_state(next_state, _current_seed, score_controller.storage_warning, _pending_score_depth, score_controller.last_player_name)

	match next_state:
		RunPhase.MAIN_MENU:
			_set_player_active(false)
		RunPhase.LEADERBOARD:
			_refresh_leaderboard()
			_set_player_active(false)
		RunPhase.GENERATING:
			_set_player_active(false)
			generation_started.emit()
			_begin_generation()
		RunPhase.PLAYING:
			ui.dismiss_menu_shell()
			if _last_generation_result != null:
				_attach_world(_last_generation_result)
			_set_player_active(true)
			gameplay_started.emit()
		RunPhase.FLAG_IN_FLIGHT:
			ui.dismiss_menu_shell()
			_set_player_active(true)
		RunPhase.NAME_ENTRY:
			_set_player_active(false)
		RunPhase.PAUSED:
			_set_player_active(false)
		RunPhase.SUBMITTING:
			_set_player_active(false)
		RunPhase.DEATH:
			_set_player_active(false)
		RunPhase.RESULT:
			_set_player_active(false)
		_:
			push_error("Unknown run state: %s" % [next_state])


func _begin_generation() -> void:
	var generation_started_msec := Time.get_ticks_msec()
	_diag("generation: begin seed=%d" % _current_seed)
	_terminal_outcome_locked = false
	_pending_score_depth = -1
	item_controller.clear_run()
	_simulation_accumulator = 0.0
	_clear_preview_player()
	_chunk_activity_index = null
	world_presenter.reset()
	_last_generation_result = await _generation_task.generate_async(
		self,
		generation_profile,
		_terrain_registry,
		_current_seed
	)
	_diag("generation: generated in %d ms" % (Time.get_ticks_msec() - generation_started_msec))
	_current_seed = SeedUtils.derive_seed(_current_seed, "next_run")
	if _run_coordinator.current_state == RunPhase.GENERATING and _last_generation_result != null:
		_diag("generation: transitioning to playing")
		transition_to(RunPhase.PLAYING)


func _on_generation_progress_changed(progress: float, label: String) -> void:
	ui.show_generation_progress(progress, label)


func _process(delta: float) -> void:
	if _player == null or _last_generation_result == null:
		return
	if _run_coordinator.current_state != RunPhase.PLAYING and _run_coordinator.current_state != RunPhase.FLAG_IN_FLIGHT:
		return

	item_controller.handle_input(get_global_mouse_position())
	var player_offset := HexMetrics.offset_for_world(_player.global_position, world_presenter.hex_radius)
	var visible_start_row := maxi(0, player_offset.y - int(world_presenter.visible_row_count / 3))
	if _chunk_activity_index != null:
		_simulation_backend.schedule(
			_chunk_activity_index.visible_chunks_for_depth_window(visible_start_row, world_presenter.visible_row_count)
		)
	_simulation_accumulator += delta
	if _simulation_accumulator >= _simulation_backend.commit_interval_seconds:
		_simulation_accumulator = 0.0
		_simulation_backend.advance(1000)
		var commit = _simulation_backend.commit_if_ready()
		if commit.did_commit and _chunk_activity_index != null:
			_chunk_activity_index.mark_dirty_rect(commit.dirty_rect)
	world_presenter.refresh_visible_chunks(visible_start_row)
	_refresh_play_status()


func _on_bomb_exploded(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool) -> void:
	audio_director.play_explosion(is_large)
	gameplay_feedback.spawn_ring(impact_position, color, blast_radius * world_presenter.hex_radius * 0.75)
	if _player != null:
		_player.camera.apply_shake(10.0 if is_large else 6.0)


func _on_flag_planted(depth: int, impact_position: Vector2) -> void:
	if _terminal_outcome_locked:
		return
	_pending_score_depth = depth
	audio_director.play_flag_plant()
	gameplay_feedback.spawn_ring(impact_position, Color(0.98, 0.86, 0.32, 0.9), 18.0)
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


func _refresh_play_status() -> void:
	var item_status := item_controller.inventory_status()
	if item_status.selected_name.is_empty() or _player == null:
		ui.show_play_status("No items configured", "")
		return
	var player_depth := HexMetrics.offset_for_world(_player.global_position, world_presenter.hex_radius).y
	var best_text := "PB:%d" % score_controller.personal_best_depth if score_controller.personal_best_depth >= 0 else "PB:-"
	var rope_text := "Hooked" if _player.is_grapple_attached() else "Free"
	var status_text := "Depth %d | %s | %s | %s" % [
		player_depth,
		best_text,
		rope_text,
		" | ".join(item_status.counts),
	]
	var hint_text := "Selected: %s" % item_status.selected_name
	if item_status.flag_in_flight:
		hint_text += " | Flag in flight"
	ui.show_play_status(status_text, hint_text)


func _on_player_death_requested(cause: StringName) -> void:
	audio_director.play_death()
	if _player != null:
		_player.camera.apply_shake(14.0)
	_complete_terminal_outcome("Cause: %s" % String(cause).capitalize(), RunPhase.DEATH)


func _on_confirm_score_requested(player_name: String) -> void:
	var seed := _last_generation_result.final_seed if _last_generation_result != null else _current_seed
	var result := score_controller.confirm_score(player_name, _pending_score_depth, seed)
	if not result.accepted:
		ui.show_name_error(result.error)
		return
	audio_director.play_ui_confirm()
	_update_depth_markers()
	if not result.submitted:
		ui.show_result("%s claimed depth %d. Personal best: %d." % [
			score_controller.last_player_name,
			_pending_score_depth,
			score_controller.personal_best_depth,
		])
		transition_to(RunPhase.RESULT)
		return
	ui.show_result("%s claimed depth %d. Personal best: %d.\nSubmitting score..." % [
		score_controller.last_player_name,
		_pending_score_depth,
		score_controller.personal_best_depth,
	])
	transition_to(RunPhase.SUBMITTING)


func _on_restart_pressed() -> void:
	transition_to(RunPhase.GENERATING)


func _complete_terminal_outcome(message: String, next_state: StringName) -> void:
	if _terminal_outcome_locked:
		return
	_terminal_outcome_locked = true
	ui.show_result(message)
	transition_to(next_state)


func _set_player_active(is_active: bool) -> void:
	if _player == null:
		return
	_player.set_physics_process(is_active)


func _ensure_player() -> void:
	if player_scene == null or _last_generation_result == null:
		return
	if _player == null:
		_player = player_scene.instantiate() as PlayerController
		add_child(_player)
		_player.death_requested.connect(_on_player_death_requested)
	var spawn_col := _last_generation_result.spawn_rect.position.x + int(_last_generation_result.spawn_rect.size.x / 2)
	var spawn_row := _last_generation_result.spawn_rect.position.y + 1
	var spawn_position := HexMetrics.center_for_offset(spawn_col, spawn_row, world_presenter.hex_radius)
	_player.world_bottom_y = HexMetrics.center_for_offset(0, generation_profile.depth + 6, world_presenter.hex_radius).y
	_player.set_spawn_position(spawn_position)
	_grapple_anchor_query.configure(
		_last_generation_result.world,
		_terrain_registry,
		world_presenter.hex_radius,
		_player.grapple_config.attach_radius,
		_player.grapple_config.probe_step
	)
	_player.configure_grapple_anchor_query(_grapple_anchor_query)
	_player.configure_environment(_last_generation_result.world, _terrain_registry, world_presenter.hex_radius)
	_simulation_backend.initialize(_last_generation_result.world, _terrain_registry, _last_generation_result.final_seed)
	_simulation_backend.schedule([])
	_configure_world_bounds()
	item_controller.configure_run(_player, _last_generation_result.world, _terrain_registry, _chunk_activity_index, world_presenter.hex_radius)
	_update_depth_markers()


func _attach_world(result: WorldGenerationResult) -> void:
	_diag("world: attach begin")
	if _chunk_activity_index == null:
		_chunk_activity_index = ChunkActivityIndex.new(result.world.dimensions)
	world_presenter.configure(result.world, _terrain_registry, _chunk_activity_index)
	_diag("world: presenter configured")
	_ensure_player()
	_diag("world: player ready")


func _configure_registries() -> void:
	var terrain_catalog := load("res://config/terrain/catalog.tres") as TerrainCatalog
	if not _terrain_registry.try_configure(terrain_catalog):
		push_error("\n".join(_terrain_registry.validation_errors))
	var item_catalog := load("res://config/items/catalog.tres") as ItemCatalog
	if not _item_registry.try_configure(item_catalog):
		push_error("\n".join(_item_registry.validation_errors))


func _configure_world_bounds() -> void:
	var left_edge := HexMetrics.center_for_offset(0, 0, world_presenter.hex_radius).x - world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(generation_profile.width - 1, 0, world_presenter.hex_radius).x + world_presenter.hex_radius
	var map_width := right_edge - left_edge
	var viewport_size := get_viewport_rect().size
	var horizontal_zoom := maxf(0.1, viewport_size.x ) / maxf(1.0, map_width - 16.0)
	var top_edge := HexMetrics.center_for_offset(0, 0, world_presenter.hex_radius).y - world_presenter.hex_radius
	var bottom_edge := HexMetrics.center_for_offset(0, generation_profile.depth - 1, world_presenter.hex_radius).y + world_presenter.hex_radius
	_player.camera.configure_bounds(0.0, _player.world_bottom_y)
	_player.camera.configure_horizontal_lock((left_edge + right_edge) * 0.5, Vector2(horizontal_zoom, horizontal_zoom))
	_player.configure_horizontal_bounds(left_edge, right_edge)
	world_side_boundaries.configure(left_edge, right_edge, top_edge, bottom_edge)
	depth_markers.configure_bounds(left_edge, right_edge, world_presenter.hex_radius)


func _update_depth_markers() -> void:
	depth_markers.set_personal_depth(score_controller.personal_best_depth)
	depth_markers.set_global_depth(score_controller.global_best_depth, score_controller.global_best_player)


func _start_menu_preview() -> void:
	if not _enable_menu_preview:
		return
	call_deferred("_generate_menu_preview")


func _generate_menu_preview() -> void:
	if _last_generation_result != null:
		return
	var preview_task := WorldGenerationTask.new()
	var preview_result = await preview_task.generate_async(
		self,
		generation_profile,
		_terrain_registry,
		SeedUtils.derive_seed(_current_seed, "menu_preview")
	)
	if preview_result == null or _run_coordinator.current_state != RunPhase.MAIN_MENU:
		return
	_last_generation_result = preview_result
	_attach_preview_world(preview_result)


func _refresh_leaderboard() -> void:
	ui.show_leaderboard_loading()
	if not score_controller.fetch_top(10):
		ui.show_leaderboard("Leaderboard unavailable.", "[center]No entries loaded yet.[/center]")


func _retry_pending_submissions() -> void:
	score_controller.retry_pending()


func _on_leaderboard_top_loaded(entries: Array, failed: bool, message: String) -> void:
	if failed:
		ui.show_leaderboard(message if not message.is_empty() else "Leaderboard unavailable.", "[center]Retry later. Local best still saves.[/center]")
		return
	if entries.is_empty():
		ui.show_leaderboard("Nobody has claimed Earth yet.", "[center]No entries yet.[/center]", "Earth owned by: Nobody yet")
		_update_depth_markers()
		return
	var status := "Top depths"
	var lines := PackedStringArray()
	for entry in entries:
		lines.append("%d. %s - %d" % [entry.rank, entry.player_name, entry.score_depth])
	var top_entry = entries[0]
	var owner := "Earth owned by: %s" % top_entry.player_name
	ui.show_leaderboard(status, "[code]%s[/code]" % "\n".join(lines), owner)
	_update_depth_markers()


func _on_leaderboard_submission_finished(submission, entry, failed: bool, message: String) -> void:
	if failed:
		ui.show_result("%s claimed depth %d. Personal best: %d.\nOnline submit failed: %s" % [
			submission.player_name,
			submission.score_depth,
			score_controller.personal_best_depth,
			message,
		])
		transition_to(RunPhase.RESULT)
		return
	ui.show_result("%s claimed depth %d. Personal best: %d.\nScore submitted." % [
		submission.player_name,
		submission.score_depth,
		score_controller.personal_best_depth,
	])
	_update_depth_markers()
	_refresh_leaderboard()
	transition_to(RunPhase.RESULT)


func _on_pending_retry_finished(successful_count: int, message: String) -> void:
	if successful_count > 0:
		_refresh_leaderboard()
	if _run_coordinator.current_state == RunPhase.LEADERBOARD and not message.is_empty() and successful_count == 0:
		ui.leaderboard_status.text = message


func _attach_preview_world(result: WorldGenerationResult) -> void:
	_clear_preview_player()
	if _chunk_activity_index == null:
		_chunk_activity_index = ChunkActivityIndex.new(result.world.dimensions)
	world_presenter.configure(result.world, _terrain_registry, _chunk_activity_index)
	_configure_preview_bounds()


func _configure_preview_bounds() -> void:
	var left_edge := HexMetrics.center_for_offset(0, 0, world_presenter.hex_radius).x - world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(generation_profile.width - 1, 0, world_presenter.hex_radius).x + world_presenter.hex_radius
	depth_markers.configure_bounds(left_edge, right_edge, world_presenter.hex_radius)


func _clear_preview_player() -> void:
	if _player == null:
		return
	_player.queue_free()
	_player = null


func _diag(message: String) -> void:
	print("[CLAIM_EARTH][%s][%d] %s" % [BUILD_DIAGNOSTIC_ID, Time.get_ticks_msec(), message])
