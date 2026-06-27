class_name TerrainSimulationContext
extends RefCounted


var dimensions: WorldDimensions
var metadata: CompiledTerrainData
var working_cells := PackedByteArray()
var working_fill := PackedByteArray()
var tick := 0
var _touched_indices: Dictionary = {}
var _next_active_indices: Dictionary = {}


func configure(
	dimensions_value: WorldDimensions,
	metadata_value: CompiledTerrainData,
	working_cells_value: PackedByteArray,
	working_fill_value: PackedByteArray,
	tick_value: int
) -> void:
	dimensions = dimensions_value
	metadata = metadata_value
	working_cells = working_cells_value
	working_fill = working_fill_value
	tick = tick_value
	_touched_indices.clear()
	_next_active_indices.clear()


func cell_count() -> int:
	return working_cells.size()


func cell_id(index: int) -> int:
	return int(working_cells[index])


func fill(index: int) -> int:
	return int(working_fill[index])


func write_working(index: int, cell_id_value: int, fill_value: int = -1) -> void:
	working_cells[index] = cell_id_value
	working_fill[index] = 0 if cell_id_value == metadata.air_id else clampi(fill_value, 0, 255)
	_touched_indices[index] = true


func wake_movement(source: int, target: int) -> void:
	wake_index_and_neighbors(source)
	wake_index_and_neighbors(target)


func wake_index_and_neighbors(index: int) -> void:
	wake_index_and_neighbors_into(dimensions, cell_count(), index, _next_active_indices)


func touched_indices() -> Dictionary:
	return _touched_indices


func next_active_indices() -> Dictionary:
	return _next_active_indices


static func wake_index_and_neighbors_into(dimensions_value: WorldDimensions, cell_count_value: int, index: int, target_lookup: Dictionary) -> void:
	if index < 0 or index >= cell_count_value:
		return
	target_lookup[index] = true
	var width := dimensions_value.width
	var col := index % width
	var row := int(index / width)
	var parity := col & 1
	_wake_offset(dimensions_value, col + 1, row + parity, target_lookup)
	_wake_offset(dimensions_value, col + 1, row + parity - 1, target_lookup)
	_wake_offset(dimensions_value, col, row - 1, target_lookup)
	_wake_offset(dimensions_value, col - 1, row + parity - 1, target_lookup)
	_wake_offset(dimensions_value, col - 1, row + parity, target_lookup)
	_wake_offset(dimensions_value, col, row + 1, target_lookup)


static func _wake_offset(dimensions_value: WorldDimensions, col: int, row: int, target_lookup: Dictionary) -> void:
	if dimensions_value.is_in_bounds_offset(col, row):
		target_lookup[row * dimensions_value.width + col] = true
