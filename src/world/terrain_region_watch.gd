## Remembers the collision state of a cell range and reports when committed terrain changes it.
class_name TerrainRegionWatch
extends RefCounted


var _query: TerrainCollisionQuery
var _cells := Rect2i()
var _include_air := false
var _cell_bytes := PackedByteArray()
var _cell_states := PackedByteArray()


## Captures every cell whose hexagon can touch the world rectangle.
func capture(query: TerrainCollisionQuery, bounds: Rect2, include_air: bool = false) -> void:
	_query = query
	_cells = query.cells_touching_rect(bounds)
	_include_air = include_air
	_cell_bytes = _copy_cell_bytes()
	_cell_states = query.cell_states(_cells, include_air)


func cells() -> Rect2i:
	return _cells


## Returns true while a captured cell differs in solidity, or in Air occupancy when Air was captured.
func has_changed() -> bool:
	if _query == null or not _query.is_configured():
		return false
	var cell_bytes := _copy_cell_bytes()
	if cell_bytes == _cell_bytes:
		return false
	if _query.cell_states(_cells, _include_air) != _cell_states:
		return true
	# Light and fluid quantities change the packed bytes without changing what a body collides with.
	_cell_bytes = cell_bytes
	return false


func _copy_cell_bytes() -> PackedByteArray:
	var dimensions := _query.world.dimensions
	return _query.world.copy_rgba_region(_cells.intersection(Rect2i(0, 0, dimensions.width, dimensions.depth)))
