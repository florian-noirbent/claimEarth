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


func initialize(world: WorldGrid, registry: TerrainRegistry, _seed: int) -> void:
	_world = world
	_registry = registry
	_air_id = _terrain_id("Air")
	_stone_id = _terrain_id("Stone")
	_pending_commit = false
	_dirty_region.clear()
	_tick = 0


func queue_change(change: CellChange) -> void:
	_queued_changes.append(change)


func advance(_time_budget_usec: int) -> SimulationProgress:
	var progress := SimulationProgress.new()
	if _world == null or _registry == null:
		return progress

	_world.reset_working_from_committed()
	_apply_queued_changes()
	_dirty_region.clear()
	_simulate_one_tick()
	_pending_commit = not _dirty_region.is_empty()
	progress.step_completed = true
	progress.simulated_usec = 1
	_tick += 1
	return progress


func commit_if_ready() -> SimulationCommit:
	var commit := SimulationCommit.new()
	if not _pending_commit:
		return commit
	_world.commit_working_to_committed()
	commit.did_commit = true
	commit.dirty_rect = _dirty_region.as_rect()
	_pending_commit = false
	return commit


func read_region(region: Rect2i) -> PackedByteArray:
	if _world == null:
		return PackedByteArray()
	return _world.copy_committed_region(region)


func shutdown() -> void:
	_queued_changes.clear()
	_pending_commit = false


func _simulate_one_tick() -> void:
	var lateral_order := [-1, 1] if (_tick % 2 == 0) else [1, -1]
	for row in range(_world.dimensions.depth - 2, -1, -1):
		for col in range(1, _world.dimensions.width - 1):
			var definition := _registry.get_definition(_world.get_committed_by_offset(col, row))
			if definition == null:
				continue
			match definition.motion_behavior.behavior_name:
				"falling":
					_step_sand(col, row)
				"liquid":
					_step_liquid(col, row, lateral_order)


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


func _step_liquid(col: int, row: int, lateral_order: Array) -> void:
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
			if below_definition.is_passable:
				_swap_cells(col, row, col, below_row, source_id, below_id)
				return

	for direction in lateral_order:
		var side_col: int = col + int(direction)
		if side_col <= 0 or side_col >= _world.dimensions.width - 1:
			continue
		var side_id := _world.get_working_by_offset(side_col, row)
		var side_definition := _registry.get_definition(side_id)
		if side_definition == null:
			continue
		if _is_opposite_liquid(source_id, side_id):
			_world.set_working_by_offset(col, row, _air_id)
			_world.set_working_by_offset(side_col, row, _stone_id)
			_mark_dirty_pair(col, row, side_col, row)
			return
		if side_definition.is_passable:
			_swap_cells(col, row, side_col, row, source_id, side_id)
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


func _terrain_id(display_name: String) -> int:
	for definition in _registry.all_definitions():
		if definition.display_name == display_name:
			return definition.stable_id
	return -1
