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
const RENDER_BANK_COUNT := 2
const RENDER_TARGETS_PER_BANK := PASS_COUNT
const RENDER_TARGET_COUNT := RENDER_BANK_COUNT * RENDER_TARGETS_PER_BANK
const MAX_RENDER_REQUEST_WAIT_ADVANCES := 8

var _world: WorldGrid
var _metadata: CompiledTerrainData
var _pass_index := 0
var _tick_in_progress := false
var _pending_commit := false
var _revision := 0
var _advances_performed := 0
var _commits_performed := 0
var _passes_performed := 0
var _ticks_completed := 0
var _render_request_in_flight := false
var _render_request_serial := 0
var _render_request_wait_advances := 0
var _completed_step_pending := false
var _render_root: Node
var _viewports: Array[SubViewport] = []
var _materials: Array[ShaderMaterial] = []
var _rule_texture: ImageTexture
var _active_texture: Texture2D
var _presentation_texture: Texture2D
var _even_phase_texture: Texture2D
var _simulation_shader: Shader
var _high_frequency_light_source_id := StringName()
var _high_frequency_light_offset := Vector2i(-1, -1)
var _high_frequency_light_level := 0
var _high_frequency_light_update_radius := 0
var _standard_light_sources: Dictionary = {}
var _standard_light_image: Image
var _standard_light_texture: ImageTexture


func initialize(world: WorldGrid, registry: TerrainRegistry, _seed: int) -> void:
	_invalidate_render_request()
	_world = world
	_metadata = CompiledTerrainData.compile(registry)
	_pass_index = 0
	_tick_in_progress = false
	_pending_commit = false
	_revision = 0
	_advances_performed = 0
	_commits_performed = 0
	_passes_performed = 0
	_ticks_completed = 0
	_completed_step_pending = false
	_high_frequency_light_source_id = StringName()
	_high_frequency_light_offset = Vector2i(-1, -1)
	_high_frequency_light_level = 0
	_high_frequency_light_update_radius = 0
	if _world == null:
		return
	_initialize_surface_lighting()
	_world.upload_cpu_snapshot_to_texture()
	_rule_texture = _create_rule_texture(_metadata)
	_initialize_standard_light_texture()
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


func set_high_frequency_light_source(
	source_id: StringName,
	offset: Vector2i,
	light_level: int,
	update_radius: int
) -> bool:
	if _world == null or source_id == StringName() or light_level <= 0 or light_level > 255 or update_radius <= 0:
		return false
	if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return false
	if _high_frequency_light_source_id != StringName() and _high_frequency_light_source_id != source_id:
		return false
	_high_frequency_light_source_id = source_id
	_high_frequency_light_offset = offset
	_high_frequency_light_level = light_level
	_high_frequency_light_update_radius = update_radius
	return true


func remove_high_frequency_light_source(source_id: StringName) -> bool:
	if source_id == StringName() or source_id != _high_frequency_light_source_id:
		return false
	_high_frequency_light_source_id = StringName()
	_high_frequency_light_offset = Vector2i(-1, -1)
	_high_frequency_light_level = 0
	_high_frequency_light_update_radius = 0
	return true


func set_standard_light_source(source_id: StringName, offset: Vector2i, light_level: int) -> bool:
	if _world == null or source_id == StringName() or light_level <= 0 or light_level > 255:
		return false
	if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return false
	var previous_offset := offset
	if _standard_light_sources.has(source_id):
		previous_offset = _standard_light_sources[source_id].offset
	_standard_light_sources[source_id] = {
		"offset": offset,
		"light_level": light_level,
	}
	_write_standard_light_cell(previous_offset)
	if offset != previous_offset:
		_write_standard_light_cell(offset)
	_upload_standard_light_texture()
	return true


func remove_standard_light_source(source_id: StringName) -> bool:
	if not _standard_light_sources.has(source_id):
		return false
	var offset: Vector2i = _standard_light_sources[source_id].offset
	_standard_light_sources.erase(source_id)
	_write_standard_light_cell(offset)
	_upload_standard_light_texture()
	return true


func clear_standard_light_sources() -> void:
	if _standard_light_sources.is_empty():
		return
	_standard_light_sources.clear()
	if _standard_light_image != null:
		_standard_light_image.fill(Color.BLACK)
	_upload_standard_light_texture()


func standard_light_source_count() -> int:
	return _standard_light_sources.size()


func standard_light_level_at(offset: Vector2i) -> int:
	if _standard_light_image == null or _world == null or not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
		return 0
	return roundi(_standard_light_image.get_pixel(offset.x, offset.y).r * 255.0)


func advance(max_passes: int) -> SimulationProgress:
	var progress := SimulationProgress.new()
	progress.step_completed = _completed_step_pending
	_completed_step_pending = false
	# Headless Godot has no raster backend. The GPU pipeline is intentionally not emulated.
	if max_passes <= 0 or _world == null or _metadata == null or _pending_commit or DisplayServer.get_name() == "headless":
		return progress
	if _render_request_in_flight:
		_render_request_wait_advances += 1
		if _render_request_wait_advances < MAX_RENDER_REQUEST_WAIT_ADVANCES:
			return progress
		_cancel_in_progress_tick()
		_reset_gpu_source_from_world()
	var started := Time.get_ticks_usec()
	if not _tick_in_progress:
		_tick_in_progress = true
		_pass_index = 0
		_active_texture = _presentation_texture if _presentation_texture != null else _world.texture()
	var batch_size := mini(max_passes, PASS_COUNT - _pass_index)
	if _schedule_render_pass_batch(_pass_index, batch_size):
		_advances_performed += 1
		progress.passes_scheduled = batch_size
	progress.simulated_usec = Time.get_ticks_usec() - started
	return progress


func commit_if_ready() -> SimulationCommit:
	var commit := SimulationCommit.new()
	if not _pending_commit:
		return commit
	commit.did_commit = true
	commit.revision = _revision
	_pending_commit = false
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
	_standard_light_sources.clear()
	_standard_light_image = null
	_standard_light_texture = null
	_high_frequency_light_source_id = StringName()
	_high_frequency_light_offset = Vector2i(-1, -1)
	_high_frequency_light_level = 0
	_high_frequency_light_update_radius = 0


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


func is_render_pass_in_flight() -> bool:
	return _render_request_in_flight


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
			var bank_index := int(index / RENDER_TARGETS_PER_BANK)
			var bank_pass_index := index % RENDER_TARGETS_PER_BANK
			viewport.name = "TerrainSimulationBank%dPass%d" % [bank_index, bank_pass_index]
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
		material.set_shader_parameter("standard_light_sources", _standard_light_texture)
		material.set_shader_parameter("world_size", Vector2(_world.dimensions.width, _world.dimensions.depth))


func _initialize_standard_light_texture() -> void:
	_standard_light_sources.clear()
	if _world == null:
		_standard_light_image = null
		_standard_light_texture = null
		return
	_standard_light_image = Image.create(
		_world.dimensions.width,
		_world.dimensions.depth,
		false,
		Image.FORMAT_R8
	)
	_standard_light_image.fill(Color.BLACK)
	_standard_light_texture = ImageTexture.create_from_image(_standard_light_image)


func _write_standard_light_cell(offset: Vector2i) -> void:
	if _standard_light_image == null:
		return
	var resolved_level := 0
	for source_data: Dictionary in _standard_light_sources.values():
		if source_data.offset == offset:
			resolved_level = maxi(resolved_level, int(source_data.light_level))
	_standard_light_image.set_pixel(offset.x, offset.y, Color8(resolved_level, 0, 0, 255))


func _upload_standard_light_texture() -> void:
	if _standard_light_texture != null and _standard_light_image != null:
		_standard_light_texture.update(_standard_light_image)


func _reset_gpu_source_from_world() -> void:
	_active_texture = _world.texture() if _world != null else null
	_presentation_texture = _active_texture
	_even_phase_texture = _active_texture


func _initialize_surface_lighting() -> void:
	for col in range(_world.dimensions.width):
		_world.set_committed_light_by_offset(col, 0, 255)


func _schedule_render_pass_batch(first_pass: int, pass_count: int) -> bool:
	_ensure_render_targets()
	if pass_count <= 0 or first_pass < 0 or first_pass + pass_count > PASS_COUNT or _viewports.size() < RENDER_TARGET_COUNT or _active_texture == null:
		return false
	var bank_index := _revision % RENDER_BANK_COUNT
	var source_texture := _active_texture
	for pass_kind in range(first_pass, first_pass + pass_count):
		var target_index := _target_index(bank_index, pass_kind)
		var material := _materials[target_index]
		material.set_shader_parameter("source_world", source_texture)
		material.set_shader_parameter("pass_kind", pass_kind)
		material.set_shader_parameter("high_frequency_light_offset", _high_frequency_light_offset)
		material.set_shader_parameter("high_frequency_light_level", _high_frequency_light_level)
		material.set_shader_parameter("high_frequency_light_update_radius", _high_frequency_light_update_radius)
		var viewport := _viewports[target_index]
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		source_texture = viewport.get_texture()
	_render_request_serial += 1
	var request_serial := _render_request_serial
	_render_request_in_flight = true
	_render_request_wait_advances = 0
	RenderingServer.request_frame_drawn_callback(
		_on_render_batch_drawn.bind(request_serial, first_pass, pass_count, bank_index)
	)
	return true


func _on_render_batch_drawn(request_serial: int, first_pass: int, pass_count: int, bank_index: int) -> void:
	if request_serial != _render_request_serial or not _render_request_in_flight:
		return
	_render_request_in_flight = false
	_render_request_wait_advances = 0
	if first_pass != _pass_index or pass_count <= 0 or first_pass + pass_count > PASS_COUNT or bank_index < 0 or bank_index >= RENDER_BANK_COUNT:
		_cancel_in_progress_tick()
		_reset_gpu_source_from_world()
		return
	for pass_kind in range(first_pass, first_pass + pass_count):
		var viewport := _viewports[_target_index(bank_index, pass_kind)]
		if not is_instance_valid(viewport):
			_cancel_in_progress_tick()
			_reset_gpu_source_from_world()
			return
	_active_texture = _viewports[_target_index(bank_index, first_pass + pass_count - 1)].get_texture()
	if first_pass <= PASS_LEFT_DOWN_EVEN and first_pass + pass_count > PASS_LEFT_DOWN_EVEN:
		_even_phase_texture = _viewports[_target_index(bank_index, PASS_LEFT_DOWN_EVEN)].get_texture()
	_pass_index += pass_count
	_passes_performed += pass_count
	if _pass_index >= PASS_COUNT:
		_completed_step_pending = _finish_tick_from_render_texture()


func _finish_tick_from_render_texture() -> bool:
	if _active_texture == null:
		_cancel_in_progress_tick()
		return false
	var image := _active_texture.get_image()
	if image == null or image.is_empty():
		_cancel_in_progress_tick()
		_reset_gpu_source_from_world()
		return false
	_presentation_texture = _active_texture
	image.convert(Image.FORMAT_RGBA8)
	_world.cell_bytes = image.get_data()
	_world.cell_image = Image.create_from_data(_world.dimensions.width, _world.dimensions.depth, false, Image.FORMAT_RGBA8, _world.cell_bytes)
	_world.cell_texture = ImageTexture.create_from_image(_world.cell_image)
	_world.texture_revision += 1
	_finish_tick()
	return true


func _target_index(bank_index: int, pass_kind: int) -> int:
	return bank_index * RENDER_TARGETS_PER_BANK + pass_kind


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
	_revision += 1
	_pending_commit = true
	_tick_in_progress = false
	_pass_index = 0
	_ticks_completed += 1


func _cancel_in_progress_tick() -> void:
	_invalidate_render_request()
	_tick_in_progress = false
	_pending_commit = false
	_completed_step_pending = false
	_pass_index = 0


func _invalidate_render_request() -> void:
	_render_request_serial += 1
	_render_request_in_flight = false
	_render_request_wait_advances = 0
	for viewport in _viewports:
		if is_instance_valid(viewport):
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
