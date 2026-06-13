class_name AppRoot
extends Control


signal generation_started
signal gameplay_started

const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")

@export var generation_profile: GenerationProfile = preload("res://config/generation/default_profile.tres")
@export var player_scene: PackedScene

@onready var title_label: Label = %Title
@onready var status_label: Label = %Status
@onready var menu_background: ColorRect = $Background
@onready var menu_root: CenterContainer = $Center
@onready var menu_panel: VBoxContainer = %MenuPanel
@onready var menu_start_button: Button = %StartButton
@onready var menu_leaderboard_button: Button = %LeaderboardButton
@onready var playing_panel: VBoxContainer = %PlayingPanel
@onready var play_status_label: Label = %PlayStatus
@onready var back_to_menu_button: Button = %BackToMenuButton
@onready var world_presenter: WorldPresenter = %WorldPresenter

var _run_coordinator := RunCoordinator.new()
var _terrain_registry := TerrainRegistry.new()
var _generation_task := WorldGenerationTask.new()
var _last_generation_result: WorldGenerationResult
var _current_seed := 0
var _chunk_activity_index: ChunkActivityIndex
var _player: PlayerController
var _grapple_anchor_query = WorldGrappleAnchorQueryScript.new()


func _ready() -> void:
	_current_seed = SeedUtils.seed_from_text("claim-earth-default-seed")
	var terrain_catalog := load("res://config/terrain/catalog.tres") as TerrainCatalog
	if not _terrain_registry.try_configure(terrain_catalog):
		push_error("\n".join(_terrain_registry.validation_errors))
	_run_coordinator.state_changed.connect(_on_state_changed)
	_generation_task.progress_changed.connect(_on_generation_progress_changed)
	menu_start_button.pressed.connect(_on_start_pressed)
	menu_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_apply_state(_run_coordinator.current_state)
	print("Claim Earth app shell started")


func get_run_state() -> StringName:
	return _run_coordinator.current_state


func transition_to(next_state: StringName) -> void:
	_run_coordinator.transition_to(next_state)


func _on_start_pressed() -> void:
	transition_to(RunPhase.GENERATING)


func _on_leaderboard_pressed() -> void:
	status_label.text = "Leaderboard placeholder - online flow arrives in Step 11."


func _on_back_to_menu_pressed() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _on_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	_apply_state(next_state)


func _apply_state(next_state: StringName) -> void:
	match next_state:
		RunPhase.MAIN_MENU:
			menu_background.visible = true
			menu_root.visible = true
			title_label.visible = true
			status_label.visible = true
			title_label.text = "CLAIM EARTH"
			status_label.text = "Ready to descend | Seed %d" % _current_seed
			menu_panel.visible = true
			playing_panel.visible = false
		RunPhase.GENERATING:
			menu_background.visible = true
			menu_root.visible = true
			title_label.visible = true
			status_label.visible = true
			title_label.text = "CLAIM EARTH"
			status_label.text = "Generating run..."
			menu_panel.visible = true
			playing_panel.visible = false
			generation_started.emit()
			_begin_generation()
		RunPhase.PLAYING:
			menu_background.visible = false
			menu_root.visible = false
			title_label.visible = false
			status_label.visible = false
			menu_panel.visible = false
			playing_panel.visible = false
			if _last_generation_result == null:
				play_status_label.text = "Gameplay placeholder - no generated run is attached yet."
			else:
				if _chunk_activity_index == null:
					_chunk_activity_index = ChunkActivityIndex.new(_last_generation_result.world.dimensions)
				world_presenter.configure(_last_generation_result.world, _terrain_registry, _chunk_activity_index)
				_ensure_player()
				play_status_label.text = "Gameplay placeholder | Seed %d | Hash %d" % [
					_last_generation_result.final_seed,
					_last_generation_result.world_hash,
				]
			gameplay_started.emit()
		_:
			push_error("Unknown run state: %s" % [next_state])


func _begin_generation() -> void:
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


func _process(_delta: float) -> void:
	if _player == null or _last_generation_result == null or _run_coordinator.current_state != RunPhase.PLAYING:
		return

	var player_row := HexMetrics.offset_for_world(_player.global_position, world_presenter.hex_radius).y
	world_presenter.refresh_visible_chunks(maxi(0, player_row - int(world_presenter.visible_row_count / 3)))


func _ensure_player() -> void:
	if player_scene == null or _last_generation_result == null:
		return
	if _player == null:
		_player = player_scene.instantiate() as PlayerController
		add_child(_player)
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
	var left_edge := HexMetrics.center_for_offset(0, 0, world_presenter.hex_radius).x - world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(generation_profile.width - 1, 0, world_presenter.hex_radius).x + world_presenter.hex_radius
	var map_width := right_edge - left_edge
	var viewport_size := get_viewport_rect().size
	var horizontal_zoom := maxf(1.0, map_width / maxf(1.0, viewport_size.x * 0.92))
	_player.camera.configure_bounds(0.0, _player.world_bottom_y)
	_player.camera.configure_horizontal_lock((left_edge + right_edge) * 0.5, Vector2(horizontal_zoom, horizontal_zoom))
