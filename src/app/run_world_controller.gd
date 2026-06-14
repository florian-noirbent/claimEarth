class_name RunWorldController
extends Node


signal generation_progressed(progress: float, label: String)
signal run_ready(next_seed: int)
signal player_died(cause: StringName)

const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")
const CooperativeChunkBackendScript = preload("res://src/simulation/cooperative_chunk_backend.gd")

var _profile: GenerationProfile
var _player_scene: PackedScene
var _world_presenter: WorldPresenter
var _depth_markers: Node2D
var _side_boundaries: WorldSideBoundaries
var _terrain_registry: TerrainRegistry = TerrainRegistry.new()
var _item_registry: ItemRegistry = ItemRegistry.new()
var _generation_task: WorldGenerationTask = WorldGenerationTask.new()
var _generation_result: WorldGenerationResult
var _chunk_activity_index: ChunkActivityIndex
var _player: PlayerController
var _grapple_anchor_query: WorldGrappleAnchorQuery = WorldGrappleAnchorQueryScript.new()
var _simulation_backend: TerrainSimulationBackend = CooperativeChunkBackendScript.new()
var _simulation_accumulator := 0.0
var _simulation_tick_requested := false
var _generation_serial := 0


func configure(profile: GenerationProfile, player_scene: PackedScene, world_presenter: WorldPresenter, depth_markers: Node2D, side_boundaries: WorldSideBoundaries) -> void:
	_profile = profile
	_player_scene = player_scene
	_world_presenter = world_presenter
	_depth_markers = depth_markers
	_side_boundaries = side_boundaries
	_generation_task.progress_changed.connect(generation_progressed.emit)
	_configure_registries()


func start_run(run_seed: int) -> void:
	_generation_serial += 1
	var serial := _generation_serial
	_clear_player()
	_generation_result = null
	_chunk_activity_index = null
	_simulation_accumulator = 0.0
	_simulation_tick_requested = false
	_world_presenter.reset()
	var generated_result: WorldGenerationResult = await _generation_task.generate_async(self, _profile, _terrain_registry, run_seed)
	if serial != _generation_serial or generated_result == null:
		return
	_generation_result = generated_result
	_attach_run_world()
	run_ready.emit(SeedUtils.derive_seed(run_seed, "next_run"))


func start_preview(run_seed: int) -> void:
	_generation_serial += 1
	var serial := _generation_serial
	var preview_task: WorldGenerationTask = WorldGenerationTask.new()
	var generated_result: WorldGenerationResult = await preview_task.generate_async(self, _profile, _terrain_registry, SeedUtils.derive_seed(run_seed, "menu_preview"))
	if serial != _generation_serial or generated_result == null:
		return
	_generation_result = generated_result
	_clear_player()
	_chunk_activity_index = ChunkActivityIndex.new(generated_result.world.dimensions)
	_world_presenter.configure(generated_result.world, _terrain_registry, _chunk_activity_index)
	_configure_marker_bounds()


func cancel_generation() -> void:
	_generation_serial += 1


func set_active(is_active: bool) -> void:
	if _player != null:
		_player.set_physics_process(is_active)


func advance(delta: float) -> void:
	if _player == null or _generation_result == null:
		return
	var player_offset := HexMetrics.offset_for_world(_player.global_position, _world_presenter.hex_radius)
	var visible_start_row := maxi(0, player_offset.y - int(_world_presenter.visible_row_count / 3))
	if _chunk_activity_index != null:
		_simulation_backend.schedule(_chunk_activity_index.visible_chunks_for_depth_window(visible_start_row, _world_presenter.visible_row_count))
	_simulation_accumulator += delta
	if _simulation_accumulator >= _simulation_backend.commit_interval_seconds:
		_simulation_accumulator = fmod(_simulation_accumulator, _simulation_backend.commit_interval_seconds)
		_simulation_tick_requested = true
	if _simulation_tick_requested or _simulation_backend.is_tick_in_progress():
		var progress := _simulation_backend.advance(1500)
		if progress.step_completed:
			_simulation_tick_requested = false
		var commit: SimulationCommit = _simulation_backend.commit_if_ready()
		if commit.did_commit and _chunk_activity_index != null:
			_chunk_activity_index.mark_change_set(commit.change_set)
	_world_presenter.refresh_visible_chunks(visible_start_row)


func player() -> PlayerController:
	return _player


func current_world() -> WorldGrid:
	return _generation_result.world if _generation_result != null else null


func generation_result() -> WorldGenerationResult:
	return _generation_result


func simulation_backend() -> TerrainSimulationBackend:
	return _simulation_backend


func terrain_registry() -> TerrainRegistry:
	return _terrain_registry


func item_registry() -> ItemRegistry:
	return _item_registry


func chunk_activity_index() -> ChunkActivityIndex:
	return _chunk_activity_index


func spawn_rect() -> Rect2i:
	return _generation_result.spawn_rect if _generation_result != null else Rect2i()


func _attach_run_world() -> void:
	_chunk_activity_index = ChunkActivityIndex.new(_generation_result.world.dimensions)
	_world_presenter.configure(_generation_result.world, _terrain_registry, _chunk_activity_index)
	_ensure_player()


func _ensure_player() -> void:
	if _player_scene == null or _generation_result == null:
		return
	_clear_player()
	_player = _player_scene.instantiate() as PlayerController
	add_child(_player)
	_player.death_requested.connect(player_died.emit)
	var spawn_col := _generation_result.spawn_rect.position.x + int(_generation_result.spawn_rect.size.x / 2)
	var spawn_row := _generation_result.spawn_rect.position.y + 1
	_player.world_bottom_y = HexMetrics.center_for_offset(0, _profile.depth + 6, _world_presenter.hex_radius).y
	_player.set_spawn_position(HexMetrics.center_for_offset(spawn_col, spawn_row, _world_presenter.hex_radius))
	_grapple_anchor_query.configure(_generation_result.world, _terrain_registry, _world_presenter.hex_radius, _player.grapple_config.attach_radius, _player.grapple_config.probe_step)
	_player.configure_grapple_anchor_query(_grapple_anchor_query)
	_player.configure_environment(_generation_result.world, _terrain_registry, _world_presenter.hex_radius)
	_simulation_backend.initialize(_generation_result.world, _terrain_registry, _generation_result.final_seed)
	_simulation_backend.schedule([])
	_configure_world_bounds()
	set_active(false)


func _configure_registries() -> void:
	var terrain_catalog := load("res://config/terrain/catalog.tres") as TerrainCatalog
	if not _terrain_registry.try_configure(terrain_catalog):
		push_error("\n".join(_terrain_registry.validation_errors))
	var item_catalog := load("res://config/items/catalog.tres") as ItemCatalog
	if not _item_registry.try_configure(item_catalog):
		push_error("\n".join(_item_registry.validation_errors))


func _configure_world_bounds() -> void:
	var left_edge := HexMetrics.center_for_offset(0, 0, _world_presenter.hex_radius).x - _world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(_profile.width - 1, 0, _world_presenter.hex_radius).x + _world_presenter.hex_radius
	var map_width := right_edge - left_edge
	var horizontal_zoom := maxf(0.1, get_viewport().get_visible_rect().size.x) / maxf(1.0, map_width - 16.0)
	var top_edge := HexMetrics.center_for_offset(0, 0, _world_presenter.hex_radius).y - _world_presenter.hex_radius
	var bottom_edge := HexMetrics.center_for_offset(0, _profile.depth - 1, _world_presenter.hex_radius).y + _world_presenter.hex_radius
	_player.camera.configure_bounds(0.0, _player.world_bottom_y)
	_player.camera.configure_horizontal_lock((left_edge + right_edge) * 0.5, Vector2(horizontal_zoom, horizontal_zoom))
	_player.configure_horizontal_bounds(left_edge, right_edge)
	_side_boundaries.configure(left_edge, right_edge, top_edge, bottom_edge)
	_depth_markers.configure_bounds(left_edge, right_edge, _world_presenter.hex_radius)


func _configure_marker_bounds() -> void:
	var left_edge := HexMetrics.center_for_offset(0, 0, _world_presenter.hex_radius).x - _world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(_profile.width - 1, 0, _world_presenter.hex_radius).x + _world_presenter.hex_radius
	_depth_markers.configure_bounds(left_edge, right_edge, _world_presenter.hex_radius)


func _clear_player() -> void:
	if _player == null:
		return
	_player.free()
	_player = null
