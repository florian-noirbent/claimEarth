class_name CooperativeChunkBackend
extends TerrainSimulationBackend


var commit_interval_seconds := 0.5

var _world: WorldGrid
var _registry: TerrainRegistry
var _tick := 0
var _pending_commit := false
var _dirty_region := DirtyRegion.new()
var _queued_changes: Array[CellChange] = []
var _air_id := 0
var _stone_id := 1
var _advances_performed := 0
var _commits_performed := 0
var _scheduled_chunk_count := 0
var _scheduled_chunks: Array[Vector2i] = []
var _last_commit_rect := Rect2i()
var _last_commit_cell_count := 0


func initialize(world: WorldGrid, registry: TerrainRegistry, _seed: int) -> void:
	_world = world
	_registry = registry
	_air_id = _terrain_id("Air")
	_stone_id = _terrain_id("Stone")
	_pending_commit = false
	_dirty_region.clear()
	_tick = 0
	_advances_performed = 0
	_commits_performed = 0
	_scheduled_chunk_count = 0
	_scheduled_chunks.clear()
	_last_commit_rect = Rect2i()
	_last_commit_cell_count = 0


func queue_change(change: CellChange) -> void:
	_queued_changes.append(change)


func schedule(active_chunks: Array[Vector2i]) -> void:
	_scheduled_chunk_count = active_chunks.size()
	_scheduled_chunks = active_chunks.duplicate()


func advance(_time_budget_usec: int) -> SimulationProgress:
	var progress := SimulationProgress.new()
	if _world == null or _registry == null:
		return progress

	_world.reset_working_from_committed()
	_apply_queued_changes()
	_dirty_region.clear()
	_simulate_one_tick()
	_pending_commit = not _dirty_region.is_empty() and _world.working_cells != _world.committed_cells
	progress.step_completed = true
	progress.simulated_usec = 1
	_tick += 1
	_advances_performed += 1
	return progress


func commit_if_ready() -> SimulationCommit:
	var commit := SimulationCommit.new()
	if not _pending_commit:
		return commit
	_world.commit_working_to_committed()
	commit.did_commit = true
	commit.dirty_rect = _dirty_region.as_rect()
	_pending_commit = false
	_commits_performed += 1
	_last_commit_rect = commit.dirty_rect
	_last_commit_cell_count = commit.dirty_rect.size.x * commit.dirty_rect.size.y
	return commit


func read_region(region: Rect2i) -> PackedByteArray:
	if _world == null:
		return PackedByteArray()
	return _world.copy_committed_region(region)


func shutdown() -> void:
	_queued_changes.clear()
	_pending_commit = false


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


func _simulate_one_tick() -> void:
	var diagonal_downward_order := [4, 0] if (_tick % 2 == 0) else [0, 4]
	for region in _scheduled_regions():
		for row in range(region.end.y - 1, region.position.y - 1, -1):
			for col in range(region.position.x, region.end.x):
				var definition := _registry.get_definition(_world.get_committed_by_offset(col, row))
				if definition == null:
					continue
				match definition.motion_behavior.behavior_name:
					"falling":
						_step_sand(col, row)
					"liquid":
						_step_liquid(col, row, diagonal_downward_order)


func _scheduled_regions() -> Array[Rect2i]:
	if _scheduled_chunks.is_empty():
		return [Rect2i(1, 0, max(_world.dimensions.width - 2, 0), max(_world.dimensions.depth - 1, 0))]

	var chunk_rows := {}
	for chunk_coord in _scheduled_chunks:
		chunk_rows[int(chunk_coord.y)] = true

	var sorted_rows: Array[int] = []
	for row_variant in chunk_rows.keys():
		sorted_rows.append(int(row_variant))
	sorted_rows.sort()
	sorted_rows.reverse()

	var regions: Array[Rect2i] = []
	for chunk_row in sorted_rows:
		var top_row := chunk_row * 32
		var region_start_row := maxi(0, top_row - 1)
		var region_end_row := mini(_world.dimensions.depth - 1, top_row + 32)
		regions.append(Rect2i(
			1,
			region_start_row,
			max(_world.dimensions.width - 2, 0),
			max(region_end_row - region_start_row, 0)
		))
	return regions


func _step_sand(col: int, row: int) -> void:
	var source_id := _world.get_committed_by_offset(col, row)
	var below_row := row + 1
	if below_row >= _world.dimensions.depth:
		return
	var committed_target_id := _world.get_committed_by_offset(col, below_row)
	var target_definition := _registry.get_definition(committed_target_id)
	if target_definition == null:
		return
	if target_definition.is_passable:
		_swap_cells(col, row, col, below_row, source_id, committed_target_id)


func _step_liquid(col: int, row: int, diagonal_downward_order: Array) -> void:
	var source_id := _world.get_committed_by_offset(col, row)
	var below_row := row + 1
	if below_row < _world.dimensions.depth:
		var below_id := _world.get_committed_by_offset(col, below_row)
		var below_definition := _registry.get_definition(below_id)
		if below_definition != null:
			if _is_opposite_liquid(source_id, below_id):
				_world.set_working_by_offset(col, row, _air_id)
				_world.set_working_by_offset(col, below_row, _stone_id)
				_mark_dirty_pair(col, row, col, below_row)
				return
			if _can_liquid_move_into(source_id, below_id, below_definition):
				_swap_cells(col, row, col, below_row, source_id, below_id)
				return

	var source_coord := HexCoord.from_offset_odd_q(col, row)
	for direction in diagonal_downward_order:
		var target_offset := source_coord.neighbor(direction).to_offset_odd_q()
		if not _world.dimensions.is_in_bounds_offset(target_offset.x, target_offset.y):
			continue
		var target_id := _world.get_working_by_offset(target_offset.x, target_offset.y)
		var target_definition := _registry.get_definition(target_id)
		if target_definition == null:
			continue
		if _is_opposite_liquid(source_id, target_id):
			_world.set_working_by_offset(col, row, _air_id)
			_world.set_working_by_offset(target_offset.x, target_offset.y, _stone_id)
			_mark_dirty_pair(col, row, target_offset.x, target_offset.y)
			return
		if _can_liquid_move_into(source_id, target_id, target_definition):
			_swap_cells(col, row, target_offset.x, target_offset.y, source_id, target_id)
			return


func _swap_cells(source_col: int, source_row: int, target_col: int, target_row: int, source_id: int, target_id: int) -> void:
	_world.set_working_by_offset(source_col, source_row, target_id)
	_world.set_working_by_offset(target_col, target_row, source_id)
	_mark_dirty_pair(source_col, source_row, target_col, target_row)


func _mark_dirty_pair(source_col: int, source_row: int, target_col: int, target_row: int) -> void:
	_dirty_region.mark_offset(source_col, source_row)
	_dirty_region.mark_offset(target_col, target_row)


func _apply_queued_changes() -> void:
	for change in _queued_changes:
		if change.index < 0:
			continue
		_world.working_cells[change.index] = change.next_id
	_queued_changes.clear()


func _is_opposite_liquid(source_id: int, target_id: int) -> bool:
	if source_id == target_id:
		return false
	var source_definition := _registry.get_definition(source_id)
	var target_definition := _registry.get_definition(target_id)
	if source_definition == null or target_definition == null:
		return false
	return source_definition.motion_behavior.behavior_name == "liquid" and target_definition.motion_behavior.behavior_name == "liquid"


func _can_liquid_move_into(source_id: int, target_id: int, target_definition: TerrainDefinition) -> bool:
	if target_definition == null or not target_definition.is_passable:
		return false
	if source_id == target_id:
		return false
	var source_definition := _registry.get_definition(source_id)
	if source_definition == null:
		return false
	if source_definition.motion_behavior.behavior_name == "liquid" and target_definition.motion_behavior.behavior_name == "liquid":
		return false
	return true


func _terrain_id(display_name: String) -> int:
	for definition in _registry.all_definitions():
		if definition.display_name == display_name:
			return definition.stable_id
	return -1
