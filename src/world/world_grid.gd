## Owns packed CPU terrain state and its GPU texture mirror.
class_name WorldGrid
extends RefCounted


const BYTES_PER_CELL := 4
const CELL_TERRAIN := 0
const CELL_FILL := 1
const CELL_LIGHT := 2
const CELL_FLAGS := 3
const DEFAULT_LIGHTING := 255
const DEFAULT_FLAGS := 255

var dimensions: WorldDimensions
var cell_bytes: PackedByteArray
var cell_image: Image
var cell_texture: ImageTexture
var texture_revision := 0


func _init(dimensions_value: WorldDimensions, default_cell_id: int = 0) -> void:
	dimensions = dimensions_value
	cell_bytes = PackedByteArray()
	cell_bytes.resize(dimensions.cell_count() * BYTES_PER_CELL)
	for index in range(dimensions.cell_count()):
		_write_cell_bytes(index, default_cell_id, _default_fill_for_cell(default_cell_id))
	_rebuild_texture()


func get_committed_by_index(index: int) -> int:
	return cell_bytes[_byte_offset(index) + CELL_TERRAIN]


func get_committed_fill_by_index(index: int) -> int:
	return cell_bytes[_byte_offset(index) + CELL_FILL]


func get_committed_by_offset(col: int, row: int) -> int:
	return get_committed_by_index(dimensions.offset_to_index(col, row))


func get_committed_fill_by_offset(col: int, row: int) -> int:
	return get_committed_fill_by_index(dimensions.offset_to_index(col, row))


func get_committed_light_by_index(index: int) -> int:
	return cell_bytes[_byte_offset(index) + CELL_LIGHT]


func get_committed_light_by_offset(col: int, row: int) -> int:
	return get_committed_light_by_index(dimensions.offset_to_index(col, row))


func set_committed_by_index(index: int, cell_id: int, fill: int = -1) -> CellChange:
	var previous_id := get_committed_by_index(index)
	var previous_fill := get_committed_fill_by_index(index)
	var next_fill := _resolved_fill(cell_id, fill)
	var offset := _byte_offset(index)
	var previous_light := cell_bytes[offset + CELL_LIGHT]
	var previous_flags := cell_bytes[offset + CELL_FLAGS]
	_write_cell_bytes(index, cell_id, next_fill)
	cell_bytes[offset + CELL_LIGHT] = previous_light
	cell_bytes[offset + CELL_FLAGS] = previous_flags
	return CellChange.new(index, previous_id, cell_id, previous_fill, next_fill)


func set_committed_by_offset(col: int, row: int, cell_id: int, fill: int = -1) -> CellChange:
	return set_committed_by_index(dimensions.offset_to_index(col, row), cell_id, fill)


func set_committed_light_by_index(index: int, light: int) -> void:
	cell_bytes[_byte_offset(index) + CELL_LIGHT] = clampi(light, 0, 255)


func set_committed_light_by_offset(col: int, row: int, light: int) -> void:
	set_committed_light_by_index(dimensions.offset_to_index(col, row), light)


func fill_committed(cell_id: int, fill: int = -1) -> void:
	var resolved_fill := _resolved_fill(cell_id, fill)
	for index in range(dimensions.cell_count()):
		_write_cell_bytes(index, cell_id, resolved_fill)
	_rebuild_texture()


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
	for index in range(dimensions.cell_count()):
		if get_committed_by_index(index) == cell_id:
			total += 1
	return total


func committed_hash() -> int:
	return SeedUtils.seed_from_text(cell_bytes.hex_encode())


func texture() -> ImageTexture:
	return cell_texture


func upload_cpu_snapshot_to_texture() -> void:
	_rebuild_texture()


func replace_from_rgba_bytes(next_bytes: PackedByteArray) -> TerrainChangeSet:
	var change_set := TerrainChangeSet.new(dimensions)
	if next_bytes.size() != cell_bytes.size():
		return change_set
	var previous := cell_bytes
	cell_bytes = next_bytes.duplicate()
	for index in range(dimensions.cell_count()):
		var offset := _byte_offset(index)
		change_set.add_change(
			index,
			previous[offset + CELL_TERRAIN],
			cell_bytes[offset + CELL_TERRAIN],
			null,
			previous[offset + CELL_FILL],
			cell_bytes[offset + CELL_FILL]
		)
	_rebuild_texture()
	return change_set


func copy_rgba_bytes() -> PackedByteArray:
	return cell_bytes.duplicate()


func copy_rgba_region(region: Rect2i) -> PackedByteArray:
	var result := PackedByteArray()
	for row in range(region.position.y, region.end.y):
		for col in range(region.position.x, region.end.x):
			var offset := _byte_offset(dimensions.offset_to_index(col, row))
			result.append(cell_bytes[offset + CELL_TERRAIN])
			result.append(cell_bytes[offset + CELL_FILL])
			result.append(cell_bytes[offset + CELL_LIGHT])
			result.append(cell_bytes[offset + CELL_FLAGS])
	return result


func _resolved_fill(cell_id: int, fill: int) -> int:
	if fill >= 0:
		return clampi(fill, 0, 255)
	return _default_fill_for_cell(cell_id)


func _default_fill_for_cell(cell_id: int) -> int:
	return 0 if cell_id == 0 else 255


func _byte_offset(index: int) -> int:
	return index * BYTES_PER_CELL


func _write_cell_bytes(index: int, cell_id: int, fill: int) -> void:
	var offset := _byte_offset(index)
	cell_bytes[offset + CELL_TERRAIN] = clampi(cell_id, 0, 255)
	cell_bytes[offset + CELL_FILL] = clampi(fill, 0, 255)
	cell_bytes[offset + CELL_LIGHT] = DEFAULT_LIGHTING
	cell_bytes[offset + CELL_FLAGS] = DEFAULT_FLAGS


func _rebuild_texture() -> void:
	cell_image = Image.create_from_data(dimensions.width, dimensions.depth, false, Image.FORMAT_RGBA8, cell_bytes)
	if cell_texture == null or cell_texture.get_width() != dimensions.width or cell_texture.get_height() != dimensions.depth:
		cell_texture = ImageTexture.create_from_image(cell_image)
	else:
		cell_texture.update(cell_image)
	texture_revision += 1
