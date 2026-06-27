## Owns per-cell motion priority: fall, side-down, then side-up.
class_name TerrainMotionStepper
extends RefCounted


const TerrainTransferSolverScript = preload("res://src/simulation/terrain_transfer_solver.gd")

var transfer_solver = TerrainTransferSolverScript.new()


func step(index: int, context) -> void:
	var source_id: int = context.cell_id(index)
	var source_fill: int = context.fill(index)
	if source_fill <= 0 or not context.metadata.is_moving(source_id):
		return
	var original_source_id := source_id
	var width: int = context.dimensions.width
	var row := int(index / width)
	var col: int = index % width

	if context.metadata.can_fall(source_id):
		var below: int = index + width
		if below < context.cell_count():
			transfer_solver.try_transfer(index, below, TerrainTransferSolverScript.DIRECTION_FALL, context)
			source_id = int(context.cell_id(index))
			source_fill = int(context.fill(index))
			if source_fill <= 0 or source_id != original_source_id or not context.metadata.is_moving(source_id):
				return

	if context.metadata.can_side_down(source_id):
		transfer_solver.try_side_transfers(index, side_targets(col, row, TerrainTransferSolverScript.DIRECTION_SIDE_DOWN, context), TerrainTransferSolverScript.DIRECTION_SIDE_DOWN, context)

	source_id = int(context.cell_id(index))
	source_fill = int(context.fill(index))
	if source_fill <= 0 or not context.metadata.can_side_up(source_id):
		return
	transfer_solver.try_side_transfers(index, side_targets(col, row, TerrainTransferSolverScript.DIRECTION_SIDE_UP, context), TerrainTransferSolverScript.DIRECTION_SIDE_UP, context)


func side_targets(col: int, row: int, direction_kind: int, context) -> Array[int]:
	var result: Array[int] = []
	var row_delta := (col & 1) if direction_kind == TerrainTransferSolverScript.DIRECTION_SIDE_DOWN else (col & 1) - 1
	var first_delta: int = -1 if (context.tick % 2 == 0) else 1
	var column_deltas: Array[int] = [first_delta, -first_delta]
	for col_delta: int in column_deltas:
		var target_col: int = col + col_delta
		var target_row: int = row + row_delta
		if not context.dimensions.is_in_bounds_offset(target_col, target_row):
			continue
		result.append(target_row * context.dimensions.width + target_col)
	return result
