## Collects committed terrain changes and their exact changed region.
class_name TerrainChangeSet
extends RefCounted


var revision := 0
var changed_indices := PackedInt32Array()
var dirty_rect := Rect2i()
var _dimensions: WorldDimensions


func _init(dimensions: WorldDimensions = null, _chunk_width: int = 20, _chunk_height: int = 32) -> void:
	_dimensions = dimensions


func add_change(index: int, previous_id: int, next_id: int, _metadata: CompiledTerrainData, previous_fill: int = 255, next_fill: int = 255) -> void:
	if _dimensions == null:
		return
	var id_changed := previous_id != next_id
	var fill_changed := previous_fill != next_fill
	if not id_changed and not fill_changed:
		return
	changed_indices.append(index)
	var offset := _dimensions.index_to_offset(index)
	_expand_dirty_rect(offset)


func merge(other: TerrainChangeSet) -> void:
	if other == null:
		return
	changed_indices.append_array(other.changed_indices)
	if dirty_rect.size == Vector2i.ZERO:
		dirty_rect = other.dirty_rect
	elif other.dirty_rect.size != Vector2i.ZERO:
		dirty_rect = dirty_rect.merge(other.dirty_rect)
	revision = maxi(revision, other.revision)


func changed_cell_count() -> int:
	return changed_indices.size()


func is_empty() -> bool:
	return changed_indices.is_empty()


func _expand_dirty_rect(offset: Vector2i) -> void:
	var cell_rect := Rect2i(offset, Vector2i.ONE)
	dirty_rect = cell_rect if dirty_rect.size == Vector2i.ZERO else dirty_rect.merge(cell_rect)
