class_name CooperativeChunkBackend
extends TerrainSimulationBackend


var commit_interval_seconds := 0.1

var _world: WorldGrid
var _metadata: CompiledTerrainData
var _tick := 0
var _revision := 0
var _pending_commit := false
var _pending_change_set: TerrainChangeSet
var _queued_changes: Array[CellChange] = []
var _advances_performed := 0
var _commits_performed := 0
var _scheduled_chunk_count := 0
var _scheduled_chunks: Array[Vector2i] = []
var _scheduled_lookup: Dictionary = {}
var _scanned_chunks: Dictionary = {}
var _pending_scan_chunks: Array[Vector2i] = []
var _active_indices: Dictionary = {}
var _next_active_indices: Dictionary = {}
var _tick_indices: Array[int] = []
var _tick_cursor := 0
var _tick_in_progress := false
var _touched_indices: Dictionary = {}
var _last_commit_rect := Rect2i()
var _last_commit_cell_count := 0
var _last_advance_usec := 0
var _last_processed_cell_count := 0


func initialize(world: WorldGrid, registry: TerrainRegistry, _seed: int) -> void:
	_world = world
	_metadata = CompiledTerrainData.compile(registry)
	_tick = 0
	_revision = 0
	_pending_commit = false
	_pending_change_set = null
	_queued_changes.clear()
	_advances_performed = 0
	_commits_performed = 0
	_scheduled_chunk_count = 0
	_scheduled_chunks.clear()
	_scheduled_lookup.clear()
	_scanned_chunks.clear()
	_pending_scan_chunks.clear()
	_active_indices.clear()
	_next_active_indices.clear()
	_tick_indices.clear()
	_tick_cursor = 0
	_tick_in_progress = false
	_touched_indices.clear()
	_last_commit_rect = Rect2i()
	_last_commit_cell_count = 0
	_last_advance_usec = 0
	_last_processed_cell_count = 0


func queue_change(change: CellChange) -> void:
	_queued_changes.append(change)


func notify_external_changes(change_set: TerrainChangeSet) -> void:
	if change_set == null or change_set.is_empty():
		return
	_cancel_in_progress_tick()
	for index in change_set.changed_indices:
		_wake_index_and_neighbors(index, _active_indices)


func schedule(active_chunks: Array[Vector2i]) -> void:
	_scheduled_chunk_count = active_chunks.size()
	if active_chunks == _scheduled_chunks:
		return
	_scheduled_chunks = active_chunks.duplicate()
	_scheduled_lookup.clear()
	for chunk_coord in _scheduled_chunks:
		_scheduled_lookup[chunk_coord] = true
		if not _scanned_chunks.has(chunk_coord):
			_scanned_chunks[chunk_coord] = true
			_pending_scan_chunks.append(chunk_coord)


func advance(time_budget_usec: int) -> SimulationProgress:
	var progress := SimulationProgress.new()
	if _world == null or _metadata == null or _pending_commit:
		return progress
	var started := Time.get_ticks_usec()
	if not _tick_in_progress:
		_start_tick()
	var deadline := started + maxi(time_budget_usec, 1)
	var processed := 0
	while _tick_cursor < _tick_indices.size():
		var index := _tick_indices[_tick_cursor]
		_tick_cursor += 1
		if _is_index_scheduled(index):
			_step_index(index)
		processed += 1
		if Time.get_ticks_usec() >= deadline:
			break
	_last_processed_cell_count = processed
	if _tick_cursor >= _tick_indices.size():
		_finish_tick()
		progress.step_completed = true
	_last_advance_usec = Time.get_ticks_usec() - started
	progress.simulated_usec = _last_advance_usec
	_advances_performed += 1
	return progress


func commit_if_ready() -> SimulationCommit:
	var commit := SimulationCommit.new()
	if not _pending_commit or _pending_change_set == null:
		return commit
	_world.commit_working_to_committed()
	commit.did_commit = true
	commit.change_set = _pending_change_set
	commit.dirty_rect = _pending_change_set.dirty_rect
	commit.revision = _pending_change_set.revision
	_pending_commit = false
	_pending_change_set = null
	_commits_performed += 1
	_last_commit_rect = commit.dirty_rect
	_last_commit_cell_count = commit.changed_cell_count()
	return commit


func read_region(region: Rect2i) -> PackedByteArray:
	return _world.copy_committed_region(region) if _world != null else PackedByteArray()


func shutdown() -> void:
	_queued_changes.clear()
	_pending_commit = false
	_pending_change_set = null
	_cancel_in_progress_tick()


func is_tick_in_progress() -> bool:
	return _tick_in_progress


func has_commit_ready() -> bool:
	return _pending_commit


func active_cell_count() -> int:
	return _active_indices.size() + maxi(0, _tick_indices.size() - _tick_cursor)


func last_advance_usec() -> int:
	return _last_advance_usec


func last_processed_cell_count() -> int:
	return _last_processed_cell_count


func advances_performed() -> int:
	return _advances_performed


func commits_performed() -> int:
	return _commits_performed


func scheduled_chunk_count() -> int:
	return _scheduled_chunk_count


func last_commit_rect() -> Rect2i:
	return _last_commit_rect


func last_commit_cell_count() -> int:
	return _last_commit_cell_count


func _start_tick() -> void:
	_world.reset_working_from_committed()
	_touched_indices.clear()
	_next_active_indices.clear()
	_apply_queued_changes()
	for chunk_coord in _pending_scan_chunks:
		_scan_chunk_for_motion(chunk_coord)
	_pending_scan_chunks.clear()
	if _active_indices.is_empty() and _scheduled_chunks.is_empty():
		_scan_region_for_motion(Rect2i(0, 0, _world.dimensions.width, _world.dimensions.depth))
	_tick_indices.clear()
	for index_variant in _active_indices.keys():
		_tick_indices.append(int(index_variant))
	_tick_indices.sort_custom(func(a: int, b: int) -> bool:
		var row_a := int(a / _world.dimensions.width)
		var row_b := int(b / _world.dimensions.width)
		return a < b if row_a == row_b else row_a > row_b
	)
	_active_indices.clear()
	_tick_cursor = 0
	_tick_in_progress = true


func _finish_tick() -> void:
	var change_set := TerrainChangeSet.new(_world.dimensions)
	_revision += 1
	change_set.revision = _revision
	for index_variant in _touched_indices.keys():
		var index := int(index_variant)
		change_set.add_change(index, _world.committed_cells[index], _world.working_cells[index], _metadata)
	_pending_change_set = change_set
	_pending_commit = not change_set.is_empty()
	_active_indices = _next_active_indices.duplicate()
	_tick_indices.clear()
	_tick_cursor = 0
	_tick_in_progress = false
	_tick += 1


func _step_index(index: int) -> void:
	var source_id := int(_world.committed_cells[index])
	match _metadata.motion(source_id):
		CompiledTerrainData.MOTION_FALLING:
			_step_sand(index, source_id)
		CompiledTerrainData.MOTION_LIQUID:
			_step_liquid(index, source_id)


func _step_sand(index: int, source_id: int) -> void:
	var target := index + _world.dimensions.width
	if target >= _world.committed_cells.size():
		return
	var target_id := int(_world.committed_cells[target])
	if _metadata.is_passable(target_id):
		_swap_indices(index, target, source_id, target_id)


func _step_liquid(index: int, source_id: int) -> void:
	var width := _world.dimensions.width
	var row := int(index / width)
	var col := index % width
	var below := index + width
	if below < _world.committed_cells.size():
		var below_id := int(_world.committed_cells[below])
		if _is_opposite_liquid(source_id, below_id):
			_write_working(index, _metadata.air_id)
			_write_working(below, _metadata.stone_id)
			_wake_movement(index, below)
			return
		if _can_liquid_move_into(source_id, below_id):
			_swap_indices(index, below, source_id, below_id)
			return

	var row_delta := col & 1
	var first_delta: int = -1 if (_tick % 2 == 0) else 1
	var column_deltas: Array[int] = [first_delta, -first_delta]
	for col_delta: int in column_deltas:
		var target_col: int = col + col_delta
		var target_row: int = row + row_delta
		if not _world.dimensions.is_in_bounds_offset(target_col, target_row):
			continue
		var target: int = target_row * width + target_col
		var target_id := int(_world.working_cells[target])
		if _is_opposite_liquid(source_id, target_id):
			_write_working(index, _metadata.air_id)
			_write_working(target, _metadata.stone_id)
			_wake_movement(index, target)
			return
		if _can_liquid_move_into(source_id, target_id):
			_swap_indices(index, target, source_id, target_id)
			return


func _swap_indices(source: int, target: int, source_id: int, target_id: int) -> void:
	_write_working(source, target_id)
	_write_working(target, source_id)
	_wake_movement(source, target)


func _write_working(index: int, cell_id: int) -> void:
	_world.working_cells[index] = cell_id
	_touched_indices[index] = true


func _wake_movement(source: int, target: int) -> void:
	_wake_index_and_neighbors(source, _next_active_indices)
	_wake_index_and_neighbors(target, _next_active_indices)


func _wake_index_and_neighbors(index: int, target_lookup: Dictionary) -> void:
	if index < 0 or index >= _world.committed_cells.size():
		return
	target_lookup[index] = true
	var width := _world.dimensions.width
	var col := index % width
	var row := int(index / width)
	var parity := col & 1
	_wake_offset(col + 1, row + parity, target_lookup)
	_wake_offset(col + 1, row + parity - 1, target_lookup)
	_wake_offset(col, row - 1, target_lookup)
	_wake_offset(col - 1, row + parity - 1, target_lookup)
	_wake_offset(col - 1, row + parity, target_lookup)
	_wake_offset(col, row + 1, target_lookup)


func _wake_offset(col: int, row: int, target_lookup: Dictionary) -> void:
	if _world.dimensions.is_in_bounds_offset(col, row):
		target_lookup[row * _world.dimensions.width + col] = true


func _apply_queued_changes() -> void:
	for change in _queued_changes:
		if change.index < 0 or change.index >= _world.working_cells.size():
			continue
		_write_working(change.index, change.next_id)
		_wake_index_and_neighbors(change.index, _next_active_indices)
	_queued_changes.clear()


func _scan_chunk_for_motion(chunk_coord: Vector2i) -> void:
	var start := Vector2i(chunk_coord.x * 20, chunk_coord.y * 32)
	if start.x >= _world.dimensions.width or start.y >= _world.dimensions.depth:
		return
	var size := Vector2i(mini(20, _world.dimensions.width - start.x), mini(32, _world.dimensions.depth - start.y))
	_scan_region_for_motion(Rect2i(start, size))


func _scan_region_for_motion(region: Rect2i) -> void:
	var width := _world.dimensions.width
	for row in range(region.position.y, region.end.y):
		for col in range(region.position.x, region.end.x):
			var index := row * width + col
			if _metadata.motion(int(_world.committed_cells[index])) != CompiledTerrainData.MOTION_STABLE:
				_active_indices[index] = true


func _is_index_scheduled(index: int) -> bool:
	if _scheduled_lookup.is_empty():
		return true
	var width := _world.dimensions.width
	var col := index % width
	var row := int(index / width)
	return _scheduled_lookup.has(Vector2i(int(col / 20), int(row / 32)))


func _is_opposite_liquid(source_id: int, target_id: int) -> bool:
	return source_id != target_id and _metadata.motion(source_id) == CompiledTerrainData.MOTION_LIQUID and _metadata.motion(target_id) == CompiledTerrainData.MOTION_LIQUID


func _can_liquid_move_into(source_id: int, target_id: int) -> bool:
	return source_id != target_id and _metadata.is_passable(target_id) and _metadata.motion(target_id) != CompiledTerrainData.MOTION_LIQUID


func _cancel_in_progress_tick() -> void:
	_tick_in_progress = false
	_tick_indices.clear()
	_tick_cursor = 0
	_touched_indices.clear()
	_next_active_indices.clear()
	_pending_commit = false
	_pending_change_set = null
