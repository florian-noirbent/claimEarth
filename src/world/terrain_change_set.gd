## Collects committed terrain changes and their exact changed region.
class_name TerrainChangeSet
extends RefCounted


var revision := 0
var changed_indices := PackedInt32Array()
var dirty_rect := Rect2i()
var _dimensions: WorldDimensions


func _init(dimensions: WorldDimensions = null) -> void:
	_dimensions = dimensions


func add_change(
	index: int,
	previous_id: int,
	next_id: int,
	_metadata: CompiledTerrainData,
	previous_quantity: int = 127,
	next_quantity: int = 127,
	previous_secondary_id: int = 0,
	next_secondary_id: int = 0,
	previous_secondary_quantity: int = 0,
	next_secondary_quantity: int = 0
) -> void:
	if _dimensions == null:
		return
	var id_changed := previous_id != next_id
	var quantity_changed := previous_quantity != next_quantity
	var secondary_changed := (
		previous_secondary_id != next_secondary_id
		or previous_secondary_quantity != next_secondary_quantity
	)
	if not id_changed and not quantity_changed and not secondary_changed:
		return
	changed_indices.append(index)
	var offset := _dimensions.index_to_offset(index)
	_expand_dirty_rect(offset)


func add_cell_change(change: CellChange, metadata: CompiledTerrainData = null) -> void:
	if change == null:
		return
	add_change(
		change.index,
		change.previous_id,
		change.next_id,
		metadata,
		change.previous_quantity,
		change.next_quantity,
		change.previous_secondary_id,
		change.next_secondary_id,
		change.previous_secondary_quantity,
		change.next_secondary_quantity
	)


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
