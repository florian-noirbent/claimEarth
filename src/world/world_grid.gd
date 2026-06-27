class_name WorldGrid
extends RefCounted


var dimensions: WorldDimensions
var committed_cells: PackedByteArray
var working_cells: PackedByteArray
var committed_fill: PackedByteArray
var working_fill: PackedByteArray


func _init(dimensions_value: WorldDimensions, default_cell_id: int = 0) -> void:
	dimensions = dimensions_value
	committed_cells = PackedByteArray()
	committed_cells.resize(dimensions.cell_count())
	committed_cells.fill(default_cell_id)
	working_cells = committed_cells.duplicate()
	committed_fill = PackedByteArray()
	committed_fill.resize(dimensions.cell_count())
	committed_fill.fill(_default_fill_for_cell(default_cell_id))
	working_fill = committed_fill.duplicate()


func get_committed_by_index(index: int) -> int:
	return committed_cells[index]


func get_working_by_index(index: int) -> int:
	return working_cells[index]


func get_committed_fill_by_index(index: int) -> int:
	return committed_fill[index]


func get_working_fill_by_index(index: int) -> int:
	return working_fill[index]


func get_committed_by_offset(col: int, row: int) -> int:
	return get_committed_by_index(dimensions.offset_to_index(col, row))


func get_working_by_offset(col: int, row: int) -> int:
	return get_working_by_index(dimensions.offset_to_index(col, row))


func get_committed_fill_by_offset(col: int, row: int) -> int:
	return get_committed_fill_by_index(dimensions.offset_to_index(col, row))


func get_working_fill_by_offset(col: int, row: int) -> int:
	return get_working_fill_by_index(dimensions.offset_to_index(col, row))


func set_committed_by_index(index: int, cell_id: int, fill: int = -1) -> CellChange:
	var previous_id := committed_cells[index]
	var previous_fill := committed_fill[index]
	committed_cells[index] = cell_id
	committed_fill[index] = _resolved_fill(cell_id, fill)
	return CellChange.new(index, previous_id, cell_id, previous_fill, committed_fill[index])


func set_working_by_index(index: int, cell_id: int, fill: int = -1) -> CellChange:
	var previous_id := working_cells[index]
	var previous_fill := working_fill[index]
	working_cells[index] = cell_id
	working_fill[index] = _resolved_fill(cell_id, fill)
	return CellChange.new(index, previous_id, cell_id, previous_fill, working_fill[index])


func set_committed_by_offset(col: int, row: int, cell_id: int, fill: int = -1) -> CellChange:
	return set_committed_by_index(dimensions.offset_to_index(col, row), cell_id, fill)


func set_working_by_offset(col: int, row: int, cell_id: int, fill: int = -1) -> CellChange:
	return set_working_by_index(dimensions.offset_to_index(col, row), cell_id, fill)


func reset_working_from_committed() -> void:
	working_cells = committed_cells.duplicate()
	working_fill = committed_fill.duplicate()


func commit_working_to_committed() -> void:
	committed_cells = working_cells.duplicate()
	committed_fill = working_fill.duplicate()


func fill_committed(cell_id: int, fill: int = -1) -> void:
	committed_cells.fill(cell_id)
	committed_fill.fill(_resolved_fill(cell_id, fill))


func fill_working(cell_id: int, fill: int = -1) -> void:
	working_cells.fill(cell_id)
	working_fill.fill(_resolved_fill(cell_id, fill))


func copy_committed_region(region: Rect2i) -> PackedByteArray:
	var result := PackedByteArray()
	for row in range(region.position.y, region.end.y):
		for col in range(region.position.x, region.end.x):
			result.append(get_committed_by_offset(col, row))
	return result


func copy_committed_fill_region(region: Rect2i) -> PackedByteArray:
	var result := PackedByteArray()
	for row in range(region.position.y, region.end.y):
		for col in range(region.position.x, region.end.x):
			result.append(get_committed_fill_by_offset(col, row))
	return result


func count_committed(cell_id: int) -> int:
	var total := 0
	for current_id in committed_cells:
		if current_id == cell_id:
			total += 1
	return total


func committed_hash() -> int:
	return SeedUtils.seed_from_text("%s:%s" % [committed_cells.hex_encode(), committed_fill.hex_encode()])


func _resolved_fill(cell_id: int, fill: int) -> int:
	if fill >= 0:
		return clampi(fill, 0, 255)
	return _default_fill_for_cell(cell_id)


func _default_fill_for_cell(cell_id: int) -> int:
	return 0 if cell_id == 0 else 255
