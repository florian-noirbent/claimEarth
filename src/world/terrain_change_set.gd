class_name TerrainChangeSet
extends RefCounted


var revision := 0
var changed_indices := PackedInt32Array()
var collision_changed_indices := PackedInt32Array()
var chunk_masks: Dictionary = {}
var dirty_rect := Rect2i()
var _dimensions: WorldDimensions
var _chunk_width := 20
var _chunk_height := 32


func _init(dimensions: WorldDimensions = null, chunk_width: int = 20, chunk_height: int = 32) -> void:
	_dimensions = dimensions
	_chunk_width = chunk_width
	_chunk_height = chunk_height


func add_change(index: int, previous_id: int, next_id: int, metadata: CompiledTerrainData) -> void:
	if previous_id == next_id or _dimensions == null:
		return
	changed_indices.append(index)
	var offset := _dimensions.index_to_offset(index)
	_expand_dirty_rect(offset)
	var owner_chunk := _chunk_for_offset(offset)
	_mark_chunk(owner_chunk, metadata.visual_layer(previous_id) | metadata.visual_layer(next_id))
	if metadata.is_solid(previous_id) == metadata.is_solid(next_id):
		return
	collision_changed_indices.append(index)
	_mark_chunk(owner_chunk, TerrainLayerMask.COLLISION)
	for neighbor in _neighbor_offsets(offset):
		if not _dimensions.is_in_bounds_offset(neighbor.x, neighbor.y):
			continue
		var neighbor_chunk := _chunk_for_offset(neighbor)
		_mark_chunk(neighbor_chunk, TerrainLayerMask.COLLISION)


func merge(other: TerrainChangeSet) -> void:
	if other == null:
		return
	changed_indices.append_array(other.changed_indices)
	collision_changed_indices.append_array(other.collision_changed_indices)
	for coord_variant in other.chunk_masks.keys():
		_mark_chunk(coord_variant as Vector2i, int(other.chunk_masks[coord_variant]))
	if dirty_rect.size == Vector2i.ZERO:
		dirty_rect = other.dirty_rect
	elif other.dirty_rect.size != Vector2i.ZERO:
		dirty_rect = dirty_rect.merge(other.dirty_rect)
	revision = maxi(revision, other.revision)


func changed_cell_count() -> int:
	return changed_indices.size()


func is_empty() -> bool:
	return changed_indices.is_empty()


func mask_for_chunk(chunk_coord: Vector2i) -> int:
	return int(chunk_masks.get(chunk_coord, TerrainLayerMask.NONE))


func _mark_chunk(chunk_coord: Vector2i, mask: int) -> void:
	if mask == TerrainLayerMask.NONE:
		return
	chunk_masks[chunk_coord] = int(chunk_masks.get(chunk_coord, TerrainLayerMask.NONE)) | mask


func _chunk_for_offset(offset: Vector2i) -> Vector2i:
	return Vector2i(int(offset.x / _chunk_width), int(offset.y / _chunk_height))


func _expand_dirty_rect(offset: Vector2i) -> void:
	var cell_rect := Rect2i(offset, Vector2i.ONE)
	dirty_rect = cell_rect if dirty_rect.size == Vector2i.ZERO else dirty_rect.merge(cell_rect)


func _neighbor_offsets(offset: Vector2i) -> Array[Vector2i]:
	var parity := offset.x & 1
	return [
		Vector2i(offset.x + 1, offset.y + parity),
		Vector2i(offset.x + 1, offset.y + parity - 1),
		Vector2i(offset.x, offset.y - 1),
		Vector2i(offset.x - 1, offset.y + parity - 1),
		Vector2i(offset.x - 1, offset.y + parity),
		Vector2i(offset.x, offset.y + 1),
	]
