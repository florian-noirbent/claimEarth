## Owns generation, player lifetime, terrain simulation, camera bounds, and world presentation.
class_name RunWorldController
extends Node


signal generation_progressed(progress: float, label: String)
signal run_ready(next_seed: int)
signal player_died(cause: StringName)
signal player_hazard_status_changed(statuses: Array)

const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")
const RenderTextureSimulationBackendScript = preload("res://src/simulation/render_texture_simulation_backend.gd")
const FixedSimulationPassClockScript = preload("res://src/simulation/fixed_simulation_pass_clock.gd")
const MAX_SIMULATION_PASSES_PER_RENDER := 6

@export var terrain_catalog: TerrainCatalog
@export var item_catalog: ItemCatalog
@export var simulation_shader: Shader

var _profile: GenerationProfile
var _player_scene: PackedScene
var _world_background: WorldBackground
var _world_presenter: WorldPresenter
var _depth_markers: Node2D
var _terrain_registry: TerrainRegistry = TerrainRegistry.new()
var _item_registry: ItemRegistry = ItemRegistry.new()
var _generation_task: WorldGenerationTask = WorldGenerationTask.new()
var _generation_result: WorldGenerationResult
var _player: PlayerController
var _grapple_anchor_query: WorldGrappleAnchorQuery = WorldGrappleAnchorQueryScript.new()
var _simulation_backend: TerrainSimulationBackend = RenderTextureSimulationBackendScript.new()
var _simulation_clock: FixedSimulationPassClock = FixedSimulationPassClockScript.new()
var _generation_serial := 0
var _loading_generation_units := 1
var _loading_settle_ticks := 0


func configure(profile: GenerationProfile, player_scene: PackedScene, world_background: WorldBackground, world_presenter: WorldPresenter, depth_markers: Node2D) -> void:
	_profile = profile
	_player_scene = player_scene
	_world_background = world_background
	_world_presenter = world_presenter
	_depth_markers = depth_markers
	_generation_task.progress_changed.connect(_on_generation_progressed)
	_configure_registries()


func start_run(run_seed: int) -> void:
	_generation_serial += 1
	var serial := _generation_serial
	_clear_player()
	_generation_result = null
	_world_presenter.reset()
	_loading_generation_units = maxi(1, _profile.active_passes().size() + 1)
	_loading_settle_ticks = maxi(0, _profile.initial_settle_ticks)
	var generated_result: WorldGenerationResult = await _generation_task.generate_async(self, _profile, _terrain_registry, run_seed)
	if serial != _generation_serial or generated_result == null:
		return
	_generation_result = generated_result
	_prepare_run_world()
	if not await _settle_initial_world(serial):
		return
	if serial != _generation_serial:
		return
	_finish_run_world_attachment()
	run_ready.emit(SeedUtils.derive_seed(run_seed, "next_run"))


func cancel_generation() -> void:
	_generation_serial += 1


func set_active(is_active: bool) -> void:
	if _player != null:
		_player.set_physics_process(is_active)
	if not is_active:
		reset_simulation_clock()


func advance(delta: float) -> void:
	if _player == null or _generation_result == null:
		return
	if _player.world_light_source != null:
		_player.world_light_source.sync_now()
	var commit: SimulationCommit = _simulation_backend.commit_if_ready()
	if commit.did_commit:
		_world_presenter.use_simulation_textures(
			_simulation_backend.presentation_texture(),
			_simulation_backend.presentation_even_texture()
		)
	_simulation_clock.add_time(delta)
	var due_passes := _simulation_clock.available_passes(MAX_SIMULATION_PASSES_PER_RENDER)
	if due_passes <= 0:
		return
	var progress := _simulation_backend.advance(due_passes)
	_simulation_clock.consume(progress.passes_scheduled)


func reset_simulation_clock() -> void:
	_simulation_clock.reset()


func player() -> PlayerController:
	return _player

func debug_teleport_to_fraction(fraction: float) -> void:
	if _player == null or _generation_result == null: return
	var row := clampi(roundi(float(_profile.depth - 3) * clampf(fraction, 0.0, 1.0)), 0, _profile.depth - 3)
	_player.global_position = HexMetrics.center_for_offset(_profile.width / 2, row, _world_presenter.hex_radius)


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


func refresh_terrain_presentation(_change_set: TerrainChangeSet = null) -> void:
	_world_presenter.upload_world()


func spawn_rect() -> Rect2i:
	return _generation_result.spawn_rect if _generation_result != null else Rect2i()


func _prepare_run_world() -> void:
	_world_presenter.set_force_full_brightness(false)
	_world_presenter.configure(_generation_result.world, _terrain_registry)
	if _simulation_backend.has_method("set_simulation_shader"):
		_simulation_backend.set_simulation_shader(simulation_shader)
	_simulation_backend.initialize(_generation_result.world, _terrain_registry, _generation_result.final_seed)
	_simulation_backend.attach_to(self)


func _settle_initial_world(serial: int) -> bool:
	if _loading_settle_ticks <= 0 or not _simulation_backend.is_available():
		generation_progressed.emit(1.0, "Run ready")
		return true

	var completed_ticks := 0
	generation_progressed.emit(_loading_progress(completed_ticks), "Settling terrain")
	while completed_ticks < _loading_settle_ticks:
		if serial != _generation_serial or not is_instance_valid(self) or is_queued_for_deletion():
			return false
		var commit := _simulation_backend.commit_if_ready()
		if commit.did_commit:
			completed_ticks += 1
			generation_progressed.emit(_loading_progress(completed_ticks), "Settling terrain")
			if completed_ticks >= _loading_settle_ticks:
				break
		_simulation_backend.advance(MAX_SIMULATION_PASSES_PER_RENDER)
		await Engine.get_main_loop().process_frame

	_world_presenter.use_simulation_textures(
		_simulation_backend.presentation_texture(),
		_simulation_backend.presentation_even_texture()
	)
	return true


func _finish_run_world_attachment() -> void:
	_ensure_player()


func _ensure_player() -> void:
	if _player_scene == null or _generation_result == null:
		return
	_clear_player()
	_player = _player_scene.instantiate() as PlayerController
	add_child(_player)
	_player.death_requested.connect(player_died.emit)
	_player.hazard_status_changed.connect(player_hazard_status_changed.emit)
	var spawn_col := _generation_result.spawn_rect.position.x + int(_generation_result.spawn_rect.size.x / 2)
	var spawn_row := _generation_result.spawn_rect.position.y
	_player.set_spawn_position(HexMetrics.center_for_offset(spawn_col, spawn_row, _world_presenter.hex_radius))
	_grapple_anchor_query.configure(
		_generation_result.world,
		_terrain_registry,
		_world_presenter.hex_radius,
		_player.grapple_config.probe_step
	)
	_player.configure_grapple_anchor_query(_grapple_anchor_query)
	_player.configure_environment(_generation_result.world, _terrain_registry, _world_presenter.hex_radius)
	_player.world_light_source.configure(
		_simulation_backend,
		_world_presenter.hex_radius,
		&"player"
	)
	reset_simulation_clock()
	_configure_world_bounds()
	set_active(false)


func _configure_registries() -> void:
	if not _terrain_registry.try_configure(terrain_catalog):
		push_error("\n".join(_terrain_registry.validation_errors))
	if not _item_registry.try_configure(item_catalog):
		push_error("\n".join(_item_registry.validation_errors))


func _configure_world_bounds() -> void:
	var left_edge := HexMetrics.center_for_offset(0, 0, _world_presenter.hex_radius).x - _world_presenter.hex_radius
	var right_edge := HexMetrics.center_for_offset(_profile.width - 1, 0, _world_presenter.hex_radius).x + _world_presenter.hex_radius
	var map_width := right_edge - left_edge
	var horizontal_zoom := maxf(0.1, get_viewport().get_visible_rect().size.x) / maxf(1.0, map_width - 16.0)
	var bottom_edge := HexMetrics.center_for_offset(0, _profile.depth - 1, _world_presenter.hex_radius).y \
		+ _world_presenter.hex_radius * sqrt(3.0) * 0.5
	_world_background.configure_bounds(left_edge, right_edge, 0.0, bottom_edge)
	_player.camera.configure_bounds(0.0, INF)
	_player.camera.configure_world_bottom_edge(bottom_edge)
	_player.camera.configure_horizontal_lock((left_edge + right_edge) * 0.5, Vector2(horizontal_zoom, horizontal_zoom))
	_player.camera.configure_upward_recovery_margin(_world_presenter.hex_radius)
	_depth_markers.configure_bounds(left_edge, right_edge, _world_presenter.hex_radius)


func _clear_player() -> void:
	if _player == null:
		return
	_player.free()
	_player = null


func _on_generation_progressed(progress: float, label: String) -> void:
	var total_units := _loading_generation_units + _loading_settle_ticks
	var overall_progress := progress
	if total_units > 0:
		overall_progress = clampf(progress, 0.0, 1.0) * float(_loading_generation_units) / float(total_units)
	generation_progressed.emit(overall_progress, label)


func _loading_progress(completed_settle_ticks: int) -> float:
	var total_units := _loading_generation_units + _loading_settle_ticks
	if total_units <= 0:
		return 1.0
	return clampf(
		float(_loading_generation_units + completed_settle_ticks) / float(total_units),
		0.0,
		1.0
	)
