class_name WorldGrid
extends RefCounted


var dimensions: WorldDimensions
var committed_cells: PackedByteArray
var working_cells: PackedByteArray


func _init(dimensions_value: WorldDimensions, default_cell_id: int = 0) -> void:
	dimensions = dimensions_value
	committed_cells = PackedByteArray()
	committed_cells.resize(dimensions.cell_count())
	committed_cells.fill(default_cell_id)
	working_cells = committed_cells.duplicate()


func get_committed_by_index(index: int) -> int:
	return committed_cells[index]


func get_working_by_index(index: int) -> int:
	return working_cells[index]


func get_committed_by_offset(col: int, row: int) -> int:
	return get_committed_by_index(dimensions.offset_to_index(col, row))


func get_working_by_offset(col: int, row: int) -> int:
	return get_working_by_index(dimensions.offset_to_index(col, row))


func set_committed_by_index(index: int, cell_id: int) -> CellChange:
	var previous_id := committed_cells[index]
	committed_cells[index] = cell_id
	return CellChange.new(index, previous_id, cell_id)


func set_working_by_index(index: int, cell_id: int) -> CellChange:
	var previous_id := working_cells[index]
	working_cells[index] = cell_id
	return CellChange.new(index, previous_id, cell_id)


func set_committed_by_offset(col: int, row: int, cell_id: int) -> CellChange:
	return set_committed_by_index(dimensions.offset_to_index(col, row), cell_id)


func set_working_by_offset(col: int, row: int, cell_id: int) -> CellChange:
	return set_working_by_index(dimensions.offset_to_index(col, row), cell_id)


func reset_working_from_committed() -> void:
	working_cells = committed_cells.duplicate()


func commit_working_to_committed() -> void:
	committed_cells = working_cells.duplicate()


func fill_committed(cell_id: int) -> void:
	committed_cells.fill(cell_id)


func fill_working(cell_id: int) -> void:
	working_cells.fill(cell_id)


func copy_committed_region(region: Rect2i) -> PackedByteArray:
	var result := PackedByteArray()
	for row in range(region.position.y, region.end.y):
		for col in range(region.position.x, region.end.x):
			result.append(get_committed_by_offset(col, row))
	return result
