## Owns packed CPU terrain state and its GPU texture mirror.
class_name WorldGrid
extends RefCounted


const BYTES_PER_CELL := 4
const CELL_HEX_IDS := 0
const CELL_QUANTITY := 1
const CELL_LIGHT := 2
const CELL_SECONDARY_QUANTITY := 3
const DEFAULT_LIGHTING := 0
const DEFAULT_SECONDARY_QUANTITY := 0
const PRIMARY_HEX_ID_MASK := 0x0f
const SECONDARY_HEX_ID_MASK := 0xf0
const AIR_QUANTITY := 64
const DEFAULT_QUANTITY := 127

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
		_write_cell_bytes(index, default_cell_id, _default_quantity_for_cell(default_cell_id))
	_rebuild_texture()


func get_committed_by_index(index: int) -> int:
	return cell_bytes[_byte_offset(index) + CELL_HEX_IDS] & PRIMARY_HEX_ID_MASK


func get_committed_secondary_by_index(index: int) -> int:
	return (cell_bytes[_byte_offset(index) + CELL_HEX_IDS] & SECONDARY_HEX_ID_MASK) >> 4


func get_committed_quantity_by_index(index: int) -> int:
	return cell_bytes[_byte_offset(index) + CELL_QUANTITY]


func get_committed_secondary_quantity_by_index(index: int) -> int:
	return cell_bytes[_byte_offset(index) + CELL_SECONDARY_QUANTITY]


func get_committed_by_offset(col: int, row: int) -> int:
	return get_committed_by_index(dimensions.offset_to_index(col, row))


func get_committed_secondary_by_offset(col: int, row: int) -> int:
	return get_committed_secondary_by_index(dimensions.offset_to_index(col, row))


func get_committed_quantity_by_offset(col: int, row: int) -> int:
	return get_committed_quantity_by_index(dimensions.offset_to_index(col, row))


func get_committed_secondary_quantity_by_offset(col: int, row: int) -> int:
	return get_committed_secondary_quantity_by_index(dimensions.offset_to_index(col, row))


func get_committed_light_by_index(index: int) -> int:
	return cell_bytes[_byte_offset(index) + CELL_LIGHT]


func get_committed_light_by_offset(col: int, row: int) -> int:
	return get_committed_light_by_index(dimensions.offset_to_index(col, row))


func set_committed_by_index(index: int, cell_id: int, quantity: int = -1) -> CellChange:
	var previous_id := get_committed_by_index(index)
	var previous_quantity := get_committed_quantity_by_index(index)
	var previous_secondary_id := get_committed_secondary_by_index(index)
	var previous_secondary_quantity := get_committed_secondary_quantity_by_index(index)
	var next_quantity := _resolved_quantity(cell_id, quantity)
	var offset := _byte_offset(index)
	var previous_light := cell_bytes[offset + CELL_LIGHT]
	_write_cell_bytes(index, cell_id, next_quantity)
	cell_bytes[offset + CELL_LIGHT] = previous_light
	return CellChange.new(
		index,
		previous_id,
		cell_id,
		previous_quantity,
		next_quantity,
		previous_secondary_id,
		0,
		previous_secondary_quantity,
		0
	)


func set_committed_by_offset(col: int, row: int, cell_id: int, quantity: int = -1) -> CellChange:
	return set_committed_by_index(dimensions.offset_to_index(col, row), cell_id, quantity)


func set_committed_components_by_index(
	index: int,
	primary_id: int,
	primary_quantity: int,
	secondary_id: int = 0,
	secondary_quantity: int = 0
) -> CellChange:
	var previous_id := get_committed_by_index(index)
	var previous_quantity := get_committed_quantity_by_index(index)
	var previous_secondary_id := get_committed_secondary_by_index(index)
	var previous_secondary_quantity := get_committed_secondary_quantity_by_index(index)
	var offset := _byte_offset(index)
	var previous_light := cell_bytes[offset + CELL_LIGHT]
	_write_cell_bytes(index, primary_id, primary_quantity, secondary_id, secondary_quantity)
	cell_bytes[offset + CELL_LIGHT] = previous_light
	var next_primary_id := get_committed_by_index(index)
	var next_primary_quantity := get_committed_quantity_by_index(index)
	var next_secondary_id := get_committed_secondary_by_index(index)
	var next_secondary_quantity := get_committed_secondary_quantity_by_index(index)
	return CellChange.new(
		index,
		previous_id,
		next_primary_id,
		previous_quantity,
		next_primary_quantity,
		previous_secondary_id,
		next_secondary_id,
		previous_secondary_quantity,
		next_secondary_quantity
	)


func set_committed_components_by_offset(
	col: int,
	row: int,
	primary_id: int,
	primary_quantity: int,
	secondary_id: int = 0,
	secondary_quantity: int = 0
) -> CellChange:
	return set_committed_components_by_index(
		dimensions.offset_to_index(col, row),
		primary_id,
		primary_quantity,
		secondary_id,
		secondary_quantity
	)


func set_committed_light_by_index(index: int, light: int) -> void:
	cell_bytes[_byte_offset(index) + CELL_LIGHT] = clampi(light, 0, 255)


func set_committed_light_by_offset(col: int, row: int, light: int) -> void:
	set_committed_light_by_index(dimensions.offset_to_index(col, row), light)


func fill_committed(cell_id: int, quantity: int = -1) -> void:
	var resolved_quantity := _resolved_quantity(cell_id, quantity)
	for index in range(dimensions.cell_count()):
		_write_cell_bytes(index, cell_id, resolved_quantity)
	_rebuild_texture()


func copy_committed_region(region: Rect2i) -> PackedByteArray:
	var result := PackedByteArray()
	for row in range(region.position.y, region.end.y):
		for col in range(region.position.x, region.end.x):
			result.append(get_committed_by_offset(col, row))
	return result


func copy_committed_quantity_region(region: Rect2i) -> PackedByteArray:
	var result := PackedByteArray()
	for row in range(region.position.y, region.end.y):
		for col in range(region.position.x, region.end.x):
			result.append(get_committed_quantity_by_offset(col, row))
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
			previous[offset + CELL_HEX_IDS] & PRIMARY_HEX_ID_MASK,
			cell_bytes[offset + CELL_HEX_IDS] & PRIMARY_HEX_ID_MASK,
			null,
			previous[offset + CELL_QUANTITY],
			cell_bytes[offset + CELL_QUANTITY],
			(previous[offset + CELL_HEX_IDS] & SECONDARY_HEX_ID_MASK) >> 4,
			(cell_bytes[offset + CELL_HEX_IDS] & SECONDARY_HEX_ID_MASK) >> 4,
			previous[offset + CELL_SECONDARY_QUANTITY],
			cell_bytes[offset + CELL_SECONDARY_QUANTITY]
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
			result.append(cell_bytes[offset + CELL_HEX_IDS])
			result.append(cell_bytes[offset + CELL_QUANTITY])
			result.append(cell_bytes[offset + CELL_LIGHT])
			result.append(cell_bytes[offset + CELL_SECONDARY_QUANTITY])
	return result


func _resolved_quantity(cell_id: int, quantity: int) -> int:
	if quantity >= 0:
		return clampi(quantity, 0, 255)
	return _default_quantity_for_cell(cell_id)


func _default_quantity_for_cell(cell_id: int) -> int:
	return AIR_QUANTITY if cell_id == 0 else DEFAULT_QUANTITY


func _byte_offset(index: int) -> int:
	return index * BYTES_PER_CELL


func _write_cell_bytes(
	index: int,
	cell_id: int,
	quantity: int,
	secondary_id: int = 0,
	secondary_quantity: int = DEFAULT_SECONDARY_QUANTITY
) -> void:
	var offset := _byte_offset(index)
	var resolved_secondary_quantity := clampi(secondary_quantity, 0, 255)
	var resolved_secondary_id := (
		clampi(secondary_id, 0, PRIMARY_HEX_ID_MASK)
		if resolved_secondary_quantity > 0
		else 0
	)
	cell_bytes[offset + CELL_HEX_IDS] = (
		clampi(cell_id, 0, PRIMARY_HEX_ID_MASK)
		| (resolved_secondary_id << 4)
	)
	cell_bytes[offset + CELL_QUANTITY] = clampi(quantity, 0, 255)
	cell_bytes[offset + CELL_LIGHT] = DEFAULT_LIGHTING
	cell_bytes[offset + CELL_SECONDARY_QUANTITY] = resolved_secondary_quantity


func _rebuild_texture() -> void:
	cell_image = Image.create_from_data(dimensions.width, dimensions.depth, false, Image.FORMAT_RGBA8, cell_bytes)
	if cell_texture == null or cell_texture.get_width() != dimensions.width or cell_texture.get_height() != dimensions.depth:
		cell_texture = ImageTexture.create_from_image(cell_image)
	else:
		cell_texture.update(cell_image)
	texture_revision += 1
