class_name AppRoot
extends Control


signal generation_started
signal gameplay_started

const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")
const ItemInventoryScript = preload("res://src/items/item_inventory.gd")
const ItemTrajectoryServiceScript = preload("res://src/items/item_trajectory_service.gd")
const ItemProjectileScript = preload("res://src/items/item_projectile.gd")
const ExplosionServiceScript = preload("res://src/items/explosion_service.gd")
const CooperativeChunkBackendScript = preload("res://src/simulation/cooperative_chunk_backend.gd")
const SaveRepositoryScript = preload("res://src/save/save_repository.gd")
const SaveDataScript = preload("res://src/save/save_data.gd")
const ScoreSubmissionScript = preload("res://src/leaderboard/score_submission.gd")
const SimpleBoardsLeaderboardServiceScript = preload("res://src/leaderboard/simpleboards_leaderboard_service.gd")

@export var generation_profile: GenerationProfile = preload("res://config/generation/default_profile.tres")
@export var player_scene: PackedScene
@export var leaderboard_config = preload("res://config/leaderboard/simpleboards.tres")

@onready var title_label: Label = %Title
@onready var owner_label: Label = %OwnerLabel
@onready var status_label: Label = %Status
@onready var warning_label: Label = %WarningLabel
@onready var controls_label: Label = %ControlsLabel
@onready var menu_background: ColorRect = $Background
@onready var menu_root: CenterContainer = $Center
@onready var menu_panel: VBoxContainer = %MenuPanel
@onready var menu_start_button: Button = %StartButton
@onready var menu_leaderboard_button: Button = %LeaderboardButton
@onready var overlay_root: MarginContainer = %OverlayRoot
@onready var playing_panel: VBoxContainer = %PlayingPanel
@onready var play_status_label: Label = %PlayStatus
@onready var hint_label: Label = %HintLabel
@onready var back_to_menu_button: Button = %BackToMenuButton
@onready var name_entry_panel: PanelContainer = %NameEntryPanel
@onready var name_entry_status: Label = %NameEntryStatus
@onready var player_name_input: LineEdit = %PlayerNameInput
@onready var confirm_score_button: Button = %ConfirmScoreButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_status: Label = %ResultStatus
@onready var restart_button: Button = %RestartButton
@onready var result_menu_button: Button = %ResultMenuButton
@onready var pause_panel: PanelContainer = %PausePanel
@onready var leaderboard_panel: PanelContainer = %LeaderboardPanel
@onready var leaderboard_status: Label = %LeaderboardStatus
@onready var leaderboard_rows: RichTextLabel = %LeaderboardRows
@onready var leaderboard_back_button: Button = %LeaderboardBackButton
@onready var world_presenter: WorldPresenter = %WorldPresenter
@onready var depth_markers: Node2D = %DepthMarkers
@onready var gameplay_feedback = %GameplayFeedback
@onready var audio_director = %AudioDirector

var _run_coordinator := RunCoordinator.new()
var _terrain_registry := TerrainRegistry.new()
var _item_registry := ItemRegistry.new()
var _generation_task := WorldGenerationTask.new()
var _last_generation_result: WorldGenerationResult
var _current_seed := 0
var _chunk_activity_index: ChunkActivityIndex
var _player: PlayerController
var _grapple_anchor_query = WorldGrappleAnchorQueryScript.new()
var _item_inventory = ItemInventoryScript.new()
var _trajectory_service = ItemTrajectoryServiceScript.new()
var _explosion_service = ExplosionServiceScript.new()
var _simulation_backend = CooperativeChunkBackendScript.new()
var _save_repository = SaveRepositoryScript.new()
var _leaderboard_service
var _simulation_accumulator := 0.0
var _last_player_name := "Player"
var _pending_score_depth := -1
var _personal_best_depth := -1
var _global_best_depth := -1
var _global_best_player := ""
var _terminal_outcome_locked := false
var _active_flag_projectile = null
var _storage_warning := ""
var _previous_play_state: StringName = RunPhase.PLAYING
var _enable_menu_preview := true
var _pending_submissions: Array[Dictionary] = []
var _retrying_pending := false


func _ready() -> void:
	_current_seed = SeedUtils.seed_from_text("claim-earth-default-seed")
	_configure_registries()
	_load_local_state()
	_configure_leaderboard_service()
	_run_coordinator.state_changed.connect(_on_state_changed)
	_generation_task.progress_changed.connect(_on_generation_progress_changed)
	menu_start_button.pressed.connect(_on_start_pressed)
	menu_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	confirm_score_button.pressed.connect(_on_confirm_score_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	result_menu_button.pressed.connect(_on_result_menu_pressed)
	leaderboard_back_button.pressed.connect(_on_leaderboard_back_pressed)
	controls_label.text = "A/D move   Space jump   RMB hook   W/S rope   1/2/3 select   LMB throw   Esc pause"
	owner_label.text = "Earth owned by: Nobody yet"
	_apply_state(_run_coordinator.current_state)
	_start_menu_preview()
	_refresh_leaderboard()
	_retry_pending_submissions()
	print("Claim Earth app shell started")


func get_run_state() -> StringName:
	return _run_coordinator.current_state


func transition_to(next_state: StringName) -> void:
	_run_coordinator.transition_to(next_state)


func configure_save_path_for_test(save_path: String) -> void:
	_save_repository.configure(save_path)


func set_menu_preview_enabled(enabled: bool) -> void:
	_enable_menu_preview = enabled


func configure_leaderboard_service_for_test(service) -> void:
	_leaderboard_service = service


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
	transition_to(RunPhase.GENERATING)


func _on_leaderboard_pressed() -> void:
	transition_to(RunPhase.LEADERBOARD)


func _on_back_to_menu_pressed() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _on_leaderboard_back_pressed() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _on_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	_apply_state(next_state)


func _apply_state(next_state: StringName) -> void:
	var show_menu_shell := next_state in [RunPhase.MAIN_MENU, RunPhase.GENERATING, RunPhase.LEADERBOARD]
	menu_background.visible = show_menu_shell
	menu_root.visible = show_menu_shell
	title_label.visible = show_menu_shell and next_state != RunPhase.LEADERBOARD
	owner_label.visible = show_menu_shell and next_state != RunPhase.LEADERBOARD
	status_label.visible = show_menu_shell and next_state != RunPhase.LEADERBOARD
	warning_label.visible = show_menu_shell and not _storage_warning.is_empty()
	controls_label.visible = show_menu_shell and next_state == RunPhase.MAIN_MENU
	menu_panel.visible = next_state in [RunPhase.MAIN_MENU, RunPhase.GENERATING]
	overlay_root.visible = next_state in [
		RunPhase.PLAYING,
		RunPhase.FLAG_IN_FLIGHT,
		RunPhase.NAME_ENTRY,
		RunPhase.PAUSED,
		RunPhase.SUBMITTING,
		RunPhase.DEATH,
		RunPhase.RESULT,
	]
	playing_panel.visible = next_state in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT, RunPhase.PAUSED]
	name_entry_panel.visible = next_state == RunPhase.NAME_ENTRY
	result_panel.visible = next_state in [RunPhase.SUBMITTING, RunPhase.DEATH, RunPhase.RESULT]
	pause_panel.visible = next_state == RunPhase.PAUSED
	leaderboard_panel.visible = next_state == RunPhase.LEADERBOARD
	warning_label.text = _storage_warning

	match next_state:
		RunPhase.MAIN_MENU:
			title_label.text = "CLAIM EARTH"
			status_label.text = "Ready to descend | Seed %d" % _current_seed
			_set_player_active(false)
		RunPhase.LEADERBOARD:
			_refresh_leaderboard()
			_set_player_active(false)
		RunPhase.GENERATING:
			title_label.text = "CLAIM EARTH"
			status_label.text = "Generating run..."
			_set_player_active(false)
			generation_started.emit()
			_begin_generation()
		RunPhase.PLAYING:
			_dismiss_menu_shell()
			if _last_generation_result != null:
				_attach_world(_last_generation_result)
			_set_player_active(true)
			gameplay_started.emit()
		RunPhase.FLAG_IN_FLIGHT:
			_dismiss_menu_shell()
			_set_player_active(true)
		RunPhase.NAME_ENTRY:
			_set_player_active(false)
			name_entry_status.text = "Depth: %d" % _pending_score_depth
			player_name_input.text = _last_player_name
			player_name_input.grab_focus()
		RunPhase.PAUSED:
			_set_player_active(false)
		RunPhase.SUBMITTING:
			_set_player_active(false)
			result_title.text = "Flag Planted"
		RunPhase.DEATH:
			_set_player_active(false)
			result_title.text = "Run Lost"
		RunPhase.RESULT:
			_set_player_active(false)
			result_title.text = "Flag Planted"
		_:
			push_error("Unknown run state: %s" % [next_state])


func _dismiss_menu_shell() -> void:
	menu_background.visible = false
	menu_root.visible = false
	title_label.visible = false
	owner_label.visible = false
	status_label.visible = false
	warning_label.visible = false


func _begin_generation() -> void:
	_terminal_outcome_locked = false
	_pending_score_depth = -1
	_active_flag_projectile = null
	_simulation_accumulator = 0.0
	_chunk_activity_index = null
	_last_generation_result = await _generation_task.generate_async(
		self,
		generation_profile,
		_terrain_registry,
		_current_seed
	)
	_current_seed = SeedUtils.derive_seed(_current_seed, "next_run")
	if _run_coordinator.current_state == RunPhase.GENERATING and _last_generation_result != null:
		transition_to(RunPhase.PLAYING)


func _on_generation_progress_changed(progress: float, label: String) -> void:
	status_label.text = "%s %d%%" % [label, int(progress * 100.0)]


func _process(delta: float) -> void:
	if _player == null or _last_generation_result == null:
		return
	if _run_coordinator.current_state != RunPhase.PLAYING and _run_coordinator.current_state != RunPhase.FLAG_IN_FLIGHT:
		return

	_handle_item_input()
	var player_offset := HexMetrics.offset_for_world(_player.global_position, world_presenter.hex_radius)
	_simulation_accumulator += delta
	if _simulation_accumulator >= _simulation_backend.commit_interval_seconds:
		_simulation_accumulator = 0.0
		_simulation_backend.advance(1000)
		var commit = _simulation_backend.commit_if_ready()
		if commit.did_commit and _chunk_activity_index != null:
			_chunk_activity_index.mark_dirty_rect(commit.dirty_rect)
	world_presenter.refresh_visible_chunks(maxi(0, player_offset.y - int(world_presenter.visible_row_count / 3)))
	_refresh_play_status()


func resolve_bomb_explosion(item_action, impact_position: Vector2, _projectile) -> void:
	if _last_generation_result == null or _chunk_activity_index == null:
		return
	if _player != null and _player.global_position.distance_to(impact_position) <= item_action.factory.lethal_radius * world_presenter.hex_radius:
		_on_player_death_requested(DeathCause.BOMB)
	_explosion_service.explode(
		_last_generation_result.world,
		_terrain_registry,
		_chunk_activity_index,
		impact_position,
		world_presenter.hex_radius,
		item_action.factory.blast_radius
	)
	audio_director.play_explosion(item_action.factory.blast_radius >= 4)
	gameplay_feedback.spawn_ring(impact_position, item_action.factory.projectile_color, item_action.factory.blast_radius * world_presenter.hex_radius * 0.75)
	if _player != null:
		_player.camera.apply_shake(10.0 if item_action.factory.blast_radius >= 4 else 6.0)


func resolve_flag_landing(_item_action, impact_position: Vector2, _projectile, resolution_kind: StringName) -> void:
	if _terminal_outcome_locked:
		return
	_active_flag_projectile = null
	if resolution_kind == &"lava":
		_complete_terminal_outcome("The flag melted in lava.", RunPhase.DEATH)
		return
	if resolution_kind != &"impact":
		transition_to(RunPhase.PLAYING)
		return
	_pending_score_depth = HexMetrics.offset_for_world(impact_position, world_presenter.hex_radius).y
	audio_director.play_flag_plant()
	gameplay_feedback.spawn_ring(impact_position, Color(0.98, 0.86, 0.32, 0.9), 18.0)
	transition_to(RunPhase.NAME_ENTRY)


func _handle_item_input() -> void:
	if _run_coordinator.current_state == RunPhase.FLAG_IN_FLIGHT:
		return
	if Input.is_action_just_pressed(InputActions.SELECT_SMALL_BOMB):
		_item_inventory.select_index(0)
	if Input.is_action_just_pressed(InputActions.SELECT_LARGE_BOMB):
		_item_inventory.select_index(1)
	if Input.is_action_just_pressed(InputActions.SELECT_FLAG):
		_item_inventory.select_index(2)
	if Input.is_action_just_pressed(InputActions.THROW_SELECTED):
		_throw_selected_item()


func _throw_selected_item() -> void:
	if _player == null or _last_generation_result == null:
		return
	var definition := _item_inventory.selected_definition()
	if definition == null or not _item_inventory.consume(definition):
		return

	var action = definition.action_factory.create_action(definition)
	var projectile_data: Dictionary = action.create_projectile(
		_player.global_position,
		get_global_mouse_position(),
		_trajectory_service,
		_player.velocity
	)
	var projectile = ItemProjectileScript.new()
	projectile.action = action
	projectile.world = _last_generation_result.world
	projectile.terrain_registry = _terrain_registry
	projectile.hex_radius = world_presenter.hex_radius
	projectile.global_position = _player.global_position
	projectile.configure(projectile_data)
	projectile.resolved.connect(func(resolved_projectile, impact_position: Vector2, resolution_kind: StringName) -> void:
		action.resolve(self, impact_position, resolved_projectile, resolution_kind)
	)
	add_child(projectile)
	audio_director.play_throw()
	if action.locks_throwing_until_resolved():
		_active_flag_projectile = projectile
		transition_to(RunPhase.FLAG_IN_FLIGHT)


func _refresh_play_status() -> void:
	var selected_definition := _item_inventory.selected_definition()
	if selected_definition == null or _player == null:
		play_status_label.text = "No items configured"
		return
	var parts := PackedStringArray()
	for definition in _item_inventory.definitions():
		parts.append("%s:%d" % [definition.display_name, _item_inventory.count_for(definition)])
	var player_depth := HexMetrics.offset_for_world(_player.global_position, world_presenter.hex_radius).y
	var best_text := "PB:%d" % _personal_best_depth if _personal_best_depth >= 0 else "PB:-"
	var rope_text := "Hooked" if _player.is_grapple_attached() else "Free"
	play_status_label.text = "Depth %d | %s | %s | %s" % [
		player_depth,
		best_text,
		rope_text,
		" | ".join(parts),
	]
	hint_label.text = "Selected: %s" % selected_definition.display_name
	if _active_flag_projectile != null:
		hint_label.text += " | Flag in flight"


func _on_player_death_requested(cause: StringName) -> void:
	audio_director.play_death()
	if _player != null:
		_player.camera.apply_shake(14.0)
	_complete_terminal_outcome("Cause: %s" % String(cause).capitalize(), RunPhase.DEATH)


func _on_confirm_score_pressed() -> void:
	var trimmed_name := player_name_input.text.strip_edges()
	if trimmed_name.is_empty():
		name_entry_status.text = "Enter a name between 1 and 20 characters."
		return
	_last_player_name = trimmed_name.substr(0, 20)
	audio_director.play_ui_confirm()
	if _pending_score_depth > _personal_best_depth:
		_personal_best_depth = _pending_score_depth
	_update_depth_markers()
	_persist_local_state()
	var submission = ScoreSubmissionScript.new()
	submission.player_name = _last_player_name
	submission.score_depth = _pending_score_depth
	submission.seed = _last_generation_result.final_seed if _last_generation_result != null else _current_seed
	submission.game_version = leaderboard_config.game_version if leaderboard_config != null else "dev"
	if _leaderboard_service == null:
		result_status.text = "%s claimed depth %d. Personal best: %d." % [
			_last_player_name,
			_pending_score_depth,
			_personal_best_depth,
		]
		transition_to(RunPhase.RESULT)
		return
	result_status.text = "%s claimed depth %d. Personal best: %d." % [
		_last_player_name,
		_pending_score_depth,
		_personal_best_depth,
	]
	result_status.text += "\nSubmitting score..."
	transition_to(RunPhase.SUBMITTING)
	_leaderboard_service.submit_score(submission)


func _on_restart_pressed() -> void:
	transition_to(RunPhase.GENERATING)


func _on_result_menu_pressed() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _complete_terminal_outcome(message: String, next_state: StringName) -> void:
	if _terminal_outcome_locked:
		return
	_terminal_outcome_locked = true
	result_status.text = message
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
	var spawn_row := _last_generation_result.spawn_rect.end.y - 2
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
	_configure_world_bounds()
	_item_inventory.configure(_item_registry)
	_update_depth_markers()


func _attach_world(result: WorldGenerationResult) -> void:
	if _chunk_activity_index == null:
		_chunk_activity_index = ChunkActivityIndex.new(result.world.dimensions)
	world_presenter.configure(result.world, _terrain_registry, _chunk_activity_index)
	_ensure_player()


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
	var horizontal_zoom := maxf(1.0, map_width / maxf(1.0, viewport_size.x * 0.92))
	_player.camera.configure_bounds(0.0, _player.world_bottom_y)
	_player.camera.configure_horizontal_lock((left_edge + right_edge) * 0.5, Vector2(horizontal_zoom, horizontal_zoom))
	depth_markers.configure_bounds(left_edge, right_edge, world_presenter.hex_radius)


func _load_local_state() -> void:
	_storage_warning = _save_repository.storage_warning()
	var save_data = _save_repository.load_data()
	_last_player_name = save_data.last_player_name
	_personal_best_depth = save_data.personal_best_depth
	_pending_submissions.clear()
	for pending_submission in save_data.pending_submissions:
		_pending_submissions.append(pending_submission.duplicate(true))


func _persist_local_state() -> void:
	var save_data = SaveDataScript.new()
	save_data.last_player_name = _last_player_name
	save_data.personal_best_depth = _personal_best_depth
	for pending_submission in _pending_submissions:
		save_data.pending_submissions.append(pending_submission.duplicate(true))
	_save_repository.save_data(save_data)


func _update_depth_markers() -> void:
	depth_markers.set_personal_depth(_personal_best_depth)
	depth_markers.set_global_depth(_global_best_depth, _global_best_player)


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
	_attach_world(preview_result)
	_set_player_active(false)


func _configure_leaderboard_service() -> void:
	if _leaderboard_service != null:
		if _leaderboard_service.get_parent() == null:
			add_child(_leaderboard_service)
		_connect_leaderboard_service()
		return
	_leaderboard_service = SimpleBoardsLeaderboardServiceScript.new()
	add_child(_leaderboard_service)
	_leaderboard_service.configure(leaderboard_config)
	_connect_leaderboard_service()


func _connect_leaderboard_service() -> void:
	if not _leaderboard_service.top_loaded.is_connected(_on_leaderboard_top_loaded):
		_leaderboard_service.top_loaded.connect(_on_leaderboard_top_loaded)
	if not _leaderboard_service.submission_finished.is_connected(_on_leaderboard_submission_finished):
		_leaderboard_service.submission_finished.connect(_on_leaderboard_submission_finished)
	if not _leaderboard_service.pending_retry_finished.is_connected(_on_pending_retry_finished):
		_leaderboard_service.pending_retry_finished.connect(_on_pending_retry_finished)


func _refresh_leaderboard() -> void:
	leaderboard_status.text = "Loading leaderboard..."
	leaderboard_rows.text = ""
	if _leaderboard_service == null:
		leaderboard_status.text = "Leaderboard unavailable."
		leaderboard_rows.text = "[center]No entries loaded yet.[/center]"
		return
	_leaderboard_service.fetch_top(10)


func _retry_pending_submissions() -> void:
	if _leaderboard_service == null or _pending_submissions.is_empty() or _retrying_pending:
		return
	_retrying_pending = true
	_leaderboard_service.retry_pending(_pending_submissions)


func _on_leaderboard_top_loaded(entries: Array, failed: bool, message: String) -> void:
	if failed:
		leaderboard_status.text = message if not message.is_empty() else "Leaderboard unavailable."
		leaderboard_rows.text = "[center]Retry later. Local best still saves.[/center]"
		return
	if entries.is_empty():
		leaderboard_status.text = "Nobody has claimed Earth yet."
		leaderboard_rows.text = "[center]No entries yet.[/center]"
		owner_label.text = "Earth owned by: Nobody yet"
		_global_best_depth = -1
		_global_best_player = ""
		_update_depth_markers()
		return
	leaderboard_status.text = "Top depths"
	var lines := PackedStringArray()
	for entry in entries:
		lines.append("%d. %s - %d" % [entry.rank, entry.player_name, entry.score_depth])
	var top_entry = entries[0]
	owner_label.text = "Earth owned by: %s" % top_entry.player_name
	_global_best_depth = top_entry.score_depth
	_global_best_player = top_entry.player_name
	leaderboard_rows.text = "[code]%s[/code]" % "\n".join(lines)
	_update_depth_markers()


func _on_leaderboard_submission_finished(submission, entry, failed: bool, message: String) -> void:
	if failed:
		_pending_submissions.append(submission.to_pending_dictionary())
		_persist_local_state()
		result_status.text = "%s claimed depth %d. Personal best: %d.\nOnline submit failed: %s" % [
			submission.player_name,
			submission.score_depth,
			_personal_best_depth,
			message,
		]
		transition_to(RunPhase.RESULT)
		return
	result_status.text = "%s claimed depth %d. Personal best: %d.\nScore submitted." % [
		submission.player_name,
		submission.score_depth,
		_personal_best_depth,
	]
	if entry != null and (_global_best_depth < 0 or entry.score_depth >= _global_best_depth):
		_global_best_depth = entry.score_depth
		_global_best_player = entry.player_name
	_update_depth_markers()
	_refresh_leaderboard()
	transition_to(RunPhase.RESULT)


func _on_pending_retry_finished(remaining_pending: Array, successful_count: int, message: String) -> void:
	_retrying_pending = false
	_pending_submissions.clear()
	for pending_submission in remaining_pending:
		_pending_submissions.append(pending_submission.duplicate(true))
	_persist_local_state()
	if successful_count > 0:
		_refresh_leaderboard()
	if _run_coordinator.current_state == RunPhase.LEADERBOARD and not message.is_empty() and successful_count == 0:
		leaderboard_status.text = message
