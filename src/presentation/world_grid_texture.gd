## Mirrors committed world grid data into a byte-packed GPU texture.
class_name WorldGridTexture
extends RefCounted


const LIGHTING_DEFAULT := 255

var image: Image
var texture: ImageTexture
var upload_count := 0


func upload_full(world: WorldGrid, lighting: int = LIGHTING_DEFAULT) -> void:
	if world == null:
		image = null
		texture = null
		return
	var width := world.dimensions.width
	var depth := world.dimensions.depth
	var data := PackedByteArray()
	data.resize(width * depth * 4)
	var light := clampi(lighting, 0, 255)
	for index in range(width * depth):
		var data_index := index * 4
		data[data_index] = int(world.committed_cells[index])
		data[data_index + 1] = int(world.committed_fill[index])
		data[data_index + 2] = light
		data[data_index + 3] = 255
	image = Image.create_from_data(width, depth, false, Image.FORMAT_RGBA8, data)
	if texture == null or texture.get_width() != width or texture.get_height() != depth:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	upload_count += 1


func texel_bytes(col: int, row: int) -> PackedByteArray:
	if image == null:
		return PackedByteArray()
	var color := image.get_pixel(col, row)
	return PackedByteArray([
		roundi(color.r * 255.0),
		roundi(color.g * 255.0),
		roundi(color.b * 255.0),
		roundi(color.a * 255.0),
	])
