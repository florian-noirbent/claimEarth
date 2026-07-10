## Advances packed terrain state as six pairwise cellular-automata passes.
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
const SIMULATION_SHADER_PATH := "res://src/simulation/render_texture_simulation.gdshader"
const FULL_FILL := 255
const HALF_FILL := 128

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
var _headless_active_bytes := PackedByteArray()


func initialize(world: WorldGrid, registry: TerrainRegistry, _seed: int) -> void:
	_world = world
	_metadata = CompiledTerrainData.compile(registry)
	_pass_index = 0
	_tick_in_progress = false
	_pending_commit = false
	_pending_change_set = null
	_tick_start_bytes = PackedByteArray()
	_headless_active_bytes = PackedByteArray()
	_revision = 0
	_advances_performed = 0
	_commits_performed = 0
	_passes_performed = 0
	_ticks_completed = 0
	if _world != null:
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
	_cancel_in_progress_tick()
	if _world != null:
		_world.upload_cpu_snapshot_to_texture()
		_reset_gpu_source_from_world()


func advance(_time_budget_usec: int) -> SimulationProgress:
	var progress := SimulationProgress.new()
	if _world == null or _metadata == null or _pending_commit:
		return progress
	var started := Time.get_ticks_usec()
	if not _tick_in_progress:
		_tick_in_progress = true
		_pass_index = 0
		_tick_start_bytes = _world.copy_rgba_bytes()
		_headless_active_bytes = _tick_start_bytes.duplicate()
		_active_texture = _presentation_texture if _presentation_texture != null else _world.texture()
	if _uses_gpu_render_targets():
		_render_pass(_pass_index)
	else:
		_run_headless_pass(_pass_index)
	_pass_index += 1
	_passes_performed += 1
	_advances_performed += 1
	if _pass_index >= PASS_COUNT:
		_finish_tick_from_gpu()
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
		_simulation_shader = ResourceLoader.load(SIMULATION_SHADER_PATH) as Shader
	if _simulation_shader == null:
		push_error("RenderTextureSimulationBackend requires a simulation shader.")
		return
	_render_root.name = "TerrainSimulationRenderTargets"
	if _viewports.size() == RENDER_TARGET_COUNT:
		for viewport in _viewports:
			if viewport.size == Vector2i(_world.dimensions.width, _world.dimensions.depth):
				continue
			_clear_render_targets()
			break
	if _viewports.size() == RENDER_TARGET_COUNT:
		_configure_materials()
		return
	_clear_render_targets()
	for index in range(RENDER_TARGET_COUNT):
		var viewport := SubViewport.new()
		viewport.name = "TerrainSimulationPass%d" % index
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.size = Vector2i(_world.dimensions.width, _world.dimensions.depth)
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var rect := ColorRect.new()
		rect.name = "PassQuad"
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
	_headless_active_bytes = _world.copy_rgba_bytes() if _world != null else PackedByteArray()


func _render_pass(pass_kind: int) -> void:
	_ensure_render_targets()
	if _viewports.size() < RENDER_TARGET_COUNT or _active_texture == null:
		return
	var target_index := _render_target_for_pass(pass_kind)
	var viewport := _viewports[target_index]
	var material := _materials[target_index]
	material.set_shader_parameter("source_world", _active_texture)
	material.set_shader_parameter("rule_texture", _rule_texture)
	material.set_shader_parameter("world_size", Vector2(_world.dimensions.width, _world.dimensions.depth))
	material.set_shader_parameter("pass_kind", pass_kind)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false)
	_active_texture = viewport.get_texture()
	if pass_kind == PASS_LEFT_DOWN_EVEN:
		_even_phase_texture = _active_texture
		_even_phase_target_index = target_index


func _run_headless_pass(pass_kind: int) -> void:
	var next_bytes := _headless_active_bytes.duplicate()
	_run_pass(_headless_active_bytes, next_bytes, pass_kind)
	_headless_active_bytes = next_bytes
	_active_texture = _world.texture()
	if pass_kind == PASS_LEFT_DOWN_EVEN:
		_even_phase_texture = _texture_from_bytes(_headless_active_bytes)


func _finish_tick_from_gpu() -> void:
	if not _uses_gpu_render_targets():
		_world.cell_bytes = _headless_active_bytes.duplicate()
		_world.cell_image = Image.create_from_data(_world.dimensions.width, _world.dimensions.depth, false, Image.FORMAT_RGBA8, _world.cell_bytes)
		_world.cell_texture = ImageTexture.create_from_image(_world.cell_image)
		_world.texture_revision += 1
		_active_texture = _world.texture()
		_presentation_texture = _active_texture
	elif _active_texture != null:
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


func _texture_from_bytes(bytes: PackedByteArray) -> ImageTexture:
	var image := Image.create_from_data(_world.dimensions.width, _world.dimensions.depth, false, Image.FORMAT_RGBA8, bytes)
	return ImageTexture.create_from_image(image)


func _uses_gpu_render_targets() -> bool:
	return DisplayServer.get_name() != "headless"


func _create_rule_texture(metadata: CompiledTerrainData) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(256 * 4 * 4)
	for id in range(256):
		_write_rule_row(data, id, 0, [
			metadata.motion(id),
			1 if metadata.can_fall(id) else 0,
			1 if metadata.can_side_down(id) else 0,
			1 if metadata.can_side_up(id) else 0,
		])
		_write_rule_row(data, id, 1, [
			metadata.density(id),
			metadata.transfer_rate(id, 0),
			metadata.transfer_rate(id, 1),
			metadata.transfer_rate(id, 2),
		])
		_write_rule_row(data, id, 2, [
			metadata.min_fill_difference(id),
			metadata.side_flow_offset(id),
			0,
			1 if metadata.is_passable(id) else 0,
		])
		_write_rule_row(data, id, 3, [
			metadata.air_id,
			metadata.stone_id,
			0,
			0,
		])
	var image := Image.create_from_data(256, 4, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)


func _write_rule_row(data: PackedByteArray, id: int, row: int, values: Array) -> void:
	var offset := (row * 256 + id) * 4
	for channel in range(4):
		data[offset + channel] = clampi(int(values[channel]), 0, 255)


func _run_pass(source: PackedByteArray, target: PackedByteArray, pass_kind: int) -> void:
	var width := _world.dimensions.width
	var depth := _world.dimensions.depth
	for row in range(depth):
		for col in range(width):
			if not _is_pair_owner(col, row, pass_kind):
				continue
			var neighbor := _pair_neighbor(col, row, pass_kind)
			if not _world.dimensions.is_in_bounds_offset(neighbor.x, neighbor.y):
				continue
			var a_index := row * width + col
			var b_index := neighbor.y * width + neighbor.x
			var result := _resolve_pair(source, a_index, b_index, pass_kind)
			_write_raw_cell(target, a_index, result[0])
			_write_raw_cell(target, b_index, result[1])


func _is_pair_owner(col: int, row: int, pass_kind: int) -> bool:
	match pass_kind:
		PASS_VERTICAL_EVEN:
			return row % 2 == 0
		PASS_VERTICAL_ODD:
			return row % 2 == 1
		PASS_RIGHT_DOWN_EVEN, PASS_LEFT_DOWN_EVEN:
			return col % 2 == 0
		PASS_RIGHT_DOWN_ODD, PASS_LEFT_DOWN_ODD:
			return col % 2 == 1
	return false


func _pair_neighbor(col: int, row: int, pass_kind: int) -> Vector2i:
	var parity := col & 1
	match pass_kind:
		PASS_VERTICAL_EVEN, PASS_VERTICAL_ODD:
			return Vector2i(col, row + 1)
		PASS_RIGHT_DOWN_EVEN, PASS_RIGHT_DOWN_ODD:
			return Vector2i(col + 1, row + parity)
		PASS_LEFT_DOWN_EVEN, PASS_LEFT_DOWN_ODD:
			return Vector2i(col - 1, row + parity)
	return Vector2i(col, row)


func _resolve_pair(source: PackedByteArray, a_index: int, b_index: int, pass_kind: int) -> Array:
	var a := _read_raw_cell(source, a_index)
	var b := _read_raw_cell(source, b_index)
	var liquid_contact := _liquid_contact(a, b)
	if not liquid_contact.is_empty():
		return liquid_contact
	if int(a[WorldGrid.CELL_FILL]) <= 0 and int(b[WorldGrid.CELL_FILL]) <= 0:
		return [a, b]
	if _is_vertical_pass(pass_kind):
		return _resolve_fall_pair(a, b)
	return _resolve_diagonal_pair(source, a_index, b_index, pass_kind, a, b)


func _is_vertical_pass(pass_kind: int) -> bool:
	return pass_kind == PASS_VERTICAL_EVEN or pass_kind == PASS_VERTICAL_ODD


func _resolve_fall_pair(upper: PackedByteArray, lower: PackedByteArray) -> Array:
	var upper_id := int(upper[WorldGrid.CELL_TERRAIN])
	var lower_id := int(lower[WorldGrid.CELL_TERRAIN])
	var upper_fill := int(upper[WorldGrid.CELL_FILL])
	var lower_fill := int(lower[WorldGrid.CELL_FILL])
	if upper_fill <= 0 or not _metadata.can_fall(upper_id):
		return [upper, lower]
	if lower_id != upper_id and lower_fill > 0:
		if not _metadata.is_moving(lower_id) or not _metadata.is_passable(lower_id):
			return [upper, lower]
		if _metadata.density(upper_id) <= _metadata.density(lower_id):
			return [upper, lower]
		return [lower, upper]
	if lower_id != upper_id and lower_id != _metadata.air_id:
		return [upper, lower]
	var rate := _metadata.transfer_rate(upper_id, 0)
	var capacity := 255 - lower_fill
	var amount := mini(upper_fill, mini(rate, capacity))
	if amount <= 0:
		return [upper, lower]
	var next_upper_fill := upper_fill - amount
	var next_lower_fill := lower_fill + amount
	return [
		_make_cell(upper_id if next_upper_fill > 0 else _metadata.air_id, next_upper_fill),
		_make_cell(upper_id, next_lower_fill),
	]


func _resolve_diagonal_pair(source: PackedByteArray, a_index: int, b_index: int, pass_kind: int, a: PackedByteArray, b: PackedByteArray) -> Array:
	var side_down_amount := 0
	if _direct_bottom_blocked(source, a_index, a):
		side_down_amount = _side_down_transfer_amount(a, b)
	if side_down_amount > 0:
		return _resolve_side_transfer(a, b, true, side_down_amount)
	var side_up_amount := 0
	if _direct_bottom_blocked(source, b_index, b) and _bottom_side_blocked(source, b_index, pass_kind, b):
		side_up_amount = _side_up_transfer_amount(b, a)
	if side_up_amount > 0:
		return _resolve_side_up_transfer(b, a, false, side_up_amount)
	return [a, b]


func _direct_bottom_blocked(source: PackedByteArray, source_index: int, source_cell: PackedByteArray) -> bool:
	return _vertical_fall_amount_from(source, source_index, source_cell) <= 0


func _bottom_side_blocked(source: PackedByteArray, source_index: int, pass_kind: int, source_cell: PackedByteArray) -> bool:
	var width := _world.dimensions.width
	var col := source_index % width
	var row := int(source_index / width)
	var bottom_side := _pair_neighbor(col, row, pass_kind)
	if not _world.dimensions.is_in_bounds_offset(bottom_side.x, bottom_side.y):
		return true
	var bottom_side_index := bottom_side.y * width + bottom_side.x
	return _side_down_transfer_amount(source_cell, _read_raw_cell(source, bottom_side_index)) <= 0


func _vertical_fall_amount_from(source: PackedByteArray, source_index: int, source_cell: PackedByteArray) -> int:
	var below_index := source_index + _world.dimensions.width
	if below_index >= _world.dimensions.cell_count():
		return 0
	var lower := _read_raw_cell(source, below_index)
	return _fall_amount(source_cell, lower)


func _resolve_side_transfer(source: PackedByteArray, target: PackedByteArray, source_is_a: bool, amount: int) -> Array:
	var source_id := int(source[WorldGrid.CELL_TERRAIN])
	var source_fill := int(source[WorldGrid.CELL_FILL])
	var target_fill := int(target[WorldGrid.CELL_FILL])
	if amount <= 0:
		return [source, target] if source_is_a else [target, source]
	var next_source_fill := source_fill - amount
	var next_target_fill := target_fill + amount
	var next_source := _make_cell(source_id if next_source_fill > 0 else _metadata.air_id, next_source_fill)
	var next_target := _make_cell(source_id, next_target_fill)
	return [next_source, next_target] if source_is_a else [next_target, next_source]


func _resolve_side_up_transfer(source: PackedByteArray, target: PackedByteArray, source_is_a: bool, amount: int) -> Array:
	var source_id := int(source[WorldGrid.CELL_TERRAIN])
	var source_fill := int(source[WorldGrid.CELL_FILL])
	var target_fill := int(target[WorldGrid.CELL_FILL])
	if amount <= 0:
		return [source, target] if source_is_a else [target, source]
	var next_source_fill := source_fill - amount
	var next_target_fill := target_fill + amount
	var next_source := _make_cell(source_id if next_source_fill > 0 else _metadata.air_id, next_source_fill)
	var next_target := _make_cell(source_id, next_target_fill)
	return [next_source, next_target] if source_is_a else [next_target, next_source]


func _fall_amount(upper: PackedByteArray, lower: PackedByteArray) -> int:
	var upper_id := int(upper[WorldGrid.CELL_TERRAIN])
	var lower_id := int(lower[WorldGrid.CELL_TERRAIN])
	var upper_fill := int(upper[WorldGrid.CELL_FILL])
	var lower_fill := int(lower[WorldGrid.CELL_FILL])
	if upper_fill <= 0 or not _metadata.can_fall(upper_id):
		return 0
	if lower_id != upper_id and lower_fill > 0:
		if not _metadata.is_moving(lower_id) or not _metadata.is_passable(lower_id):
			return 0
		return upper_fill if _metadata.density(upper_id) > _metadata.density(lower_id) else 0
	if lower_id != upper_id and lower_id != _metadata.air_id:
		return 0
	var rate := _metadata.transfer_rate(upper_id, 0)
	var capacity := 255 - lower_fill
	return mini(upper_fill, mini(rate, capacity))


func _side_down_transfer_amount(source: PackedByteArray, target: PackedByteArray) -> int:
	var source_id := int(source[WorldGrid.CELL_TERRAIN])
	var source_fill := int(source[WorldGrid.CELL_FILL])
	if source_fill <= 0 or not _metadata.can_side_down(source_id):
		return 0
	if not _can_receive_side_cell(source_id, target, FULL_FILL):
		return 0
	var target_fill := int(target[WorldGrid.CELL_FILL])
	return mini(_metadata.transfer_rate(source_id, 1), _side_transfer_capacity(source_id, source_fill, target_fill))


func _side_up_transfer_amount(source: PackedByteArray, target: PackedByteArray) -> int:
	var source_id := int(source[WorldGrid.CELL_TERRAIN])
	var source_fill := int(source[WorldGrid.CELL_FILL])
	if source_fill <= 0 or not _metadata.can_side_up(source_id):
		return 0
	if not _can_receive_side_cell(source_id, target, HALF_FILL):
		return 0
	var target_fill := int(target[WorldGrid.CELL_FILL])
	return mini(_metadata.transfer_rate(source_id, 2), _side_up_transfer_capacity(source_id, source_fill, target_fill))


func _can_receive_side_cell(source_id: int, target: PackedByteArray, capacity_limit: int) -> bool:
	var target_id := int(target[WorldGrid.CELL_TERRAIN])
	var target_fill := int(target[WorldGrid.CELL_FILL])
	if target_fill >= capacity_limit:
		return false
	if target_id == source_id:
		return true
	if target_id == _metadata.air_id and target_fill <= 0:
		return true
	return _metadata.density(target_id) < _metadata.density(source_id)


func _side_transfer_capacity(source_id: int, source_fill: int, target_fill: int) -> int:
	var raw_capacity := 255 - target_fill
	if raw_capacity <= 0:
		return 0
	var min_difference := _metadata.min_fill_difference(source_id)
	if min_difference > 0 and source_fill - target_fill < min_difference:
		return 0
	var equilibrium_distance := source_fill - target_fill + _metadata.side_flow_offset(source_id)
	if equilibrium_distance <= 0:
		return 0
	return mini(source_fill, mini(raw_capacity, int(equilibrium_distance / 2)))


func _side_up_transfer_capacity(source_id: int, source_fill: int, target_fill: int) -> int:
	var target_capacity := HALF_FILL - target_fill
	if target_capacity <= 0:
		return 0
	var excess := source_fill - _metadata.side_flow_offset(source_id) - target_fill
	if excess <= 0:
		return 0
	return mini(source_fill, mini(target_capacity, int(excess / 2)))


func _liquid_contact(a: PackedByteArray, b: PackedByteArray) -> Array:
	var a_id := int(a[WorldGrid.CELL_TERRAIN])
	var b_id := int(b[WorldGrid.CELL_TERRAIN])
	if a_id == b_id:
		return []
	if int(a[WorldGrid.CELL_FILL]) <= 0 or int(b[WorldGrid.CELL_FILL]) <= 0:
		return []
	if _metadata.motion(a_id) != CompiledTerrainData.MOTION_LIQUID or _metadata.motion(b_id) != CompiledTerrainData.MOTION_LIQUID:
		return []
	return [_make_cell(_metadata.air_id, 0), _make_cell(_metadata.stone_id, 255)]


func _finish_tick() -> void:
	var change_set := TerrainChangeSet.new(_world.dimensions)
	_revision += 1
	change_set.revision = _revision
	var current := _world.cell_bytes
	var previous := _tick_start_bytes
	for index in range(_world.dimensions.cell_count()):
		var offset := index * WorldGrid.BYTES_PER_CELL
		change_set.add_change(
			index,
			previous[offset + WorldGrid.CELL_TERRAIN],
			current[offset + WorldGrid.CELL_TERRAIN],
			_metadata,
			previous[offset + WorldGrid.CELL_FILL],
			current[offset + WorldGrid.CELL_FILL]
		)
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


func _read_raw_cell(source: PackedByteArray, index: int) -> PackedByteArray:
	var offset := index * WorldGrid.BYTES_PER_CELL
	return PackedByteArray([
		source[offset + WorldGrid.CELL_TERRAIN],
		source[offset + WorldGrid.CELL_FILL],
		source[offset + WorldGrid.CELL_LIGHT],
		source[offset + WorldGrid.CELL_FLAGS],
	])


func _write_raw_cell(target: PackedByteArray, index: int, cell: PackedByteArray) -> void:
	var offset := index * WorldGrid.BYTES_PER_CELL
	target[offset + WorldGrid.CELL_TERRAIN] = cell[WorldGrid.CELL_TERRAIN]
	target[offset + WorldGrid.CELL_FILL] = cell[WorldGrid.CELL_FILL]
	target[offset + WorldGrid.CELL_LIGHT] = cell[WorldGrid.CELL_LIGHT]
	target[offset + WorldGrid.CELL_FLAGS] = cell[WorldGrid.CELL_FLAGS]


func _make_cell(cell_id: int, fill: int) -> PackedByteArray:
	return PackedByteArray([
		clampi(cell_id, 0, 255),
		0 if cell_id == _metadata.air_id else clampi(fill, 0, 255),
		WorldGrid.DEFAULT_LIGHTING,
		WorldGrid.DEFAULT_FLAGS,
	])
