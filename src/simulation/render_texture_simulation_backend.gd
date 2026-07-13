## Advances terrain exclusively through six GPU render-texture passes.
class_name RenderTextureSimulationBackend
extends TerrainSimulationBackend


const PASS_VERTICAL_EVEN := 0
const PASS_RIGHT_DOWN_EVEN := 1
const PASS_LEFT_DOWN_EVEN := 2
const PASS_VERTICAL_ODD := 3
const PASS_RIGHT_DOWN_ODD := 4
const PASS_LEFT_DOWN_ODD := 5
const PASS_COUNT := 6
const EVEN_PHASE_PASS_COUNT := 3
const RENDER_TARGET_COUNT := 5

var _world: WorldGrid
var _metadata: CompiledTerrainData
var _pass_index := 0
var _tick_in_progress := false
var _pending_commit := false
var _pending_change_set: TerrainChangeSet
var _tick_start_bytes := PackedByteArray()
var _revision := 0
var _advances_performed := 0
var _commits_performed := 0
var _passes_performed := 0
var _ticks_completed := 0
var _render_root: Node
var _viewports: Array[SubViewport] = []
var _materials: Array[ShaderMaterial] = []
var _rule_texture: ImageTexture
var _active_texture: Texture2D
var _presentation_texture: Texture2D
var _even_phase_texture: Texture2D
var _even_phase_target_index := -1
var _simulation_shader: Shader
var _player_light_offset := Vector2i(-1, -1)
var _player_light_level := 190
var _player_light_update_radius := 18


func initialize(world: WorldGrid, registry: TerrainRegistry, _seed: int) -> void:
	_world = world
	_metadata = CompiledTerrainData.compile(registry)
	_pass_index = 0
	_tick_in_progress = false
	_pending_commit = false
	_pending_change_set = null
	_tick_start_bytes = PackedByteArray()
	_revision = 0
	_advances_performed = 0
	_commits_performed = 0
	_passes_performed = 0
	_ticks_completed = 0
	if _world == null:
		return
	_clear_initial_lighting()
	_world.upload_cpu_snapshot_to_texture()
	_rule_texture = _create_rule_texture(_metadata)
	_ensure_render_targets()
	_reset_gpu_source_from_world()


func queue_change(_change: CellChange) -> void:
	_cancel_in_progress_tick()
	if _world != null:
		_world.upload_cpu_snapshot_to_texture()
		_reset_gpu_source_from_world()


func notify_external_changes(change_set: TerrainChangeSet) -> void:
	if change_set == null or change_set.is_empty():
		return
	queue_change(null)


func set_player_light_source(offset: Vector2i, light_level: int, update_radius: int) -> void:
	_player_light_offset = offset
	_player_light_level = clampi(light_level, 0, 255)
	_player_light_update_radius = maxi(0, update_radius)


func advance(_time_budget_usec: int) -> SimulationProgress:
	var progress := SimulationProgress.new()
	# Headless Godot has no raster backend. The GPU pipeline is intentionally not emulated.
	if _world == null or _metadata == null or _pending_commit or DisplayServer.get_name() == "headless":
		return progress
	var started := Time.get_ticks_usec()
	if not _tick_in_progress:
		_tick_in_progress = true
		_pass_index = 0
		_tick_start_bytes = _world.copy_rgba_bytes()
		_active_texture = _presentation_texture if _presentation_texture != null else _world.texture()
	_render_pass(_pass_index)
	_pass_index += 1
	_passes_performed += 1
	_advances_performed += 1
	if _pass_index >= PASS_COUNT:
		_finish_tick_from_render_texture()
		progress.step_completed = true
	progress.simulated_usec = Time.get_ticks_usec() - started
	return progress


func commit_if_ready() -> SimulationCommit:
	var commit := SimulationCommit.new()
	if not _pending_commit or _pending_change_set == null:
		return commit
	commit.did_commit = true
	commit.change_set = _pending_change_set
	commit.dirty_rect = _pending_change_set.dirty_rect
	commit.revision = _pending_change_set.revision
	_pending_commit = false
	_pending_change_set = null
	_commits_performed += 1
	return commit


func read_region(region: Rect2i) -> PackedByteArray:
	return _world.copy_committed_region(region) if _world != null else PackedByteArray()


func shutdown() -> void:
	_cancel_in_progress_tick()
	if _render_root != null and _render_root.get_parent() != null:
		_render_root.get_parent().remove_child(_render_root)
	if _render_root != null:
		_render_root.queue_free()
	_render_root = null
	_world = null
	_metadata = null


func set_simulation_shader(shader: Shader) -> void:
	_simulation_shader = shader
	for material in _materials:
		material.shader = _simulation_shader


func attach_to(parent: Node) -> void:
	if parent == null:
		return
	_ensure_render_root()
	if _render_root.get_parent() == parent:
		return
	if _render_root.get_parent() != null:
		_render_root.get_parent().remove_child(_render_root)
	parent.add_child(_render_root)


func render_root() -> Node:
	_ensure_render_root()
	return _render_root


func active_texture() -> Texture2D:
	return _active_texture if _active_texture != null else (_world.texture() if _world != null else null)


func presentation_texture() -> Texture2D:
	return _presentation_texture if _presentation_texture != null else active_texture()


func presentation_even_texture() -> Texture2D:
	return _even_phase_texture if _even_phase_texture != null else presentation_texture()


func is_tick_in_progress() -> bool:
	return _tick_in_progress


func has_commit_ready() -> bool:
	return _pending_commit


func advances_performed() -> int:
	return _advances_performed


func commits_performed() -> int:
	return _commits_performed


func passes_performed() -> int:
	return _passes_performed


func ticks_completed() -> int:
	return _ticks_completed


func _ensure_render_targets() -> void:
	if _world == null:
		return
	_ensure_render_root()
	if _simulation_shader == null:
		push_error("RenderTextureSimulationBackend requires a simulation shader.")
		return
	_render_root.name = "TerrainSimulationRenderTargets"
	if _viewports.size() == RENDER_TARGET_COUNT:
		for viewport in _viewports:
			if viewport.size != Vector2i(_world.dimensions.width, _world.dimensions.depth):
				_clear_render_targets()
				break
	if _viewports.size() != RENDER_TARGET_COUNT:
		for index in range(RENDER_TARGET_COUNT):
			var viewport := SubViewport.new()
			viewport.name = "TerrainSimulationPass%d" % index
			viewport.disable_3d = true
			viewport.transparent_bg = true
			viewport.size = Vector2i(_world.dimensions.width, _world.dimensions.depth)
			viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			var rect := ColorRect.new()
			rect.size = Vector2(_world.dimensions.width, _world.dimensions.depth)
			rect.color = Color.WHITE
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var material := ShaderMaterial.new()
			material.shader = _simulation_shader
			rect.material = material
			viewport.add_child(rect)
			_render_root.add_child(viewport)
			_viewports.append(viewport)
			_materials.append(material)
	_configure_materials()


func _ensure_render_root() -> void:
	if _render_root == null:
		_render_root = Node.new()


func _clear_render_targets() -> void:
	for viewport in _viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()
	_viewports.clear()
	_materials.clear()


func _configure_materials() -> void:
	if _world == null:
		return
	for material in _materials:
		material.set_shader_parameter("rule_texture", _rule_texture)
		material.set_shader_parameter("world_size", Vector2(_world.dimensions.width, _world.dimensions.depth))


func _reset_gpu_source_from_world() -> void:
	_active_texture = _world.texture() if _world != null else null
	_presentation_texture = _active_texture
	_even_phase_texture = _active_texture
	_even_phase_target_index = -1


func _clear_initial_lighting() -> void:
	for index in range(_world.dimensions.cell_count()):
		var offset := _world.dimensions.index_to_offset(index)
		_world.set_committed_light_by_index(index, 255 if offset.y == 0 else 0)


func _render_pass(pass_kind: int) -> void:
	_ensure_render_targets()
	if _viewports.size() < RENDER_TARGET_COUNT or _active_texture == null:
		return
	var target_index := _render_target_for_pass(pass_kind)
	var material := _materials[target_index]
	material.set_shader_parameter("source_world", _active_texture)
	material.set_shader_parameter("pass_kind", pass_kind)
	material.set_shader_parameter("player_light_offset", _player_light_offset)
	material.set_shader_parameter("player_light_level", _player_light_level)
	material.set_shader_parameter("player_light_update_radius", _player_light_update_radius)
	var viewport := _viewports[target_index]
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false)
	_active_texture = viewport.get_texture()
	if pass_kind == PASS_LEFT_DOWN_EVEN:
		_even_phase_texture = _active_texture
		_even_phase_target_index = target_index


func _finish_tick_from_render_texture() -> void:
	if _active_texture != null:
		_presentation_texture = _active_texture
		var image := _active_texture.get_image()
		if image != null and not image.is_empty():
			image.convert(Image.FORMAT_RGBA8)
			_world.cell_bytes = image.get_data()
			_world.cell_image = Image.create_from_data(_world.dimensions.width, _world.dimensions.depth, false, Image.FORMAT_RGBA8, _world.cell_bytes)
			_world.cell_texture = ImageTexture.create_from_image(_world.cell_image)
			_world.texture_revision += 1
	_finish_tick()


func _render_target_for_pass(pass_kind: int) -> int:
	match pass_kind:
		PASS_VERTICAL_EVEN, PASS_VERTICAL_ODD:
			return 0
		PASS_RIGHT_DOWN_EVEN, PASS_RIGHT_DOWN_ODD:
			return 1
		PASS_LEFT_DOWN_EVEN:
			return 3 if _even_phase_target_index == 2 else 2
		PASS_LEFT_DOWN_ODD:
			return 4
	return 0


func _create_rule_texture(metadata: CompiledTerrainData) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(256 * 4 * 4)
	for id in range(256):
		_write_rule_row(data, id, 0, [metadata.motion(id), 1 if metadata.can_fall(id) else 0, 1 if metadata.can_side_down(id) else 0, 1 if metadata.can_side_up(id) else 0])
		_write_rule_row(data, id, 1, [metadata.density(id), metadata.transfer_rate(id, 0), metadata.transfer_rate(id, 1), metadata.transfer_rate(id, 2)])
		_write_rule_row(data, id, 2, [metadata.min_fill_difference(id), metadata.side_flow_offset(id), 0, 1 if metadata.is_passable(id) else 0])
		_write_rule_row(data, id, 3, [metadata.air_id, metadata.stone_id, metadata.light_diffusion(id), metadata.emitted_light(id)])
	return ImageTexture.create_from_image(Image.create_from_data(256, 4, false, Image.FORMAT_RGBA8, data))


func _write_rule_row(data: PackedByteArray, id: int, row: int, values: Array) -> void:
	var offset := (row * 256 + id) * 4
	for channel in range(4):
		data[offset + channel] = clampi(int(values[channel]), 0, 255)


func _finish_tick() -> void:
	var change_set := TerrainChangeSet.new(_world.dimensions)
	_revision += 1
	change_set.revision = _revision
	for index in range(_world.dimensions.cell_count()):
		var offset := index * WorldGrid.BYTES_PER_CELL
		change_set.add_change(index, _tick_start_bytes[offset + WorldGrid.CELL_TERRAIN], _world.cell_bytes[offset + WorldGrid.CELL_TERRAIN], _metadata, _tick_start_bytes[offset + WorldGrid.CELL_FILL], _world.cell_bytes[offset + WorldGrid.CELL_FILL])
	_pending_change_set = change_set
	_pending_commit = not change_set.is_empty()
	_tick_in_progress = false
	_pass_index = 0
	_tick_start_bytes = PackedByteArray()
	_ticks_completed += 1


func _cancel_in_progress_tick() -> void:
	_tick_in_progress = false
	_pending_commit = false
	_pending_change_set = null
	_pass_index = 0
	_tick_start_bytes = PackedByteArray()
