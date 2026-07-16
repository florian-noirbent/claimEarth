@tool
## Renders committed terrain grid data with one shader-driven world quad.
class_name WorldPresenter
extends Node2D


@export var hex_radius := 16.0
@export var visible_row_count := 96
@export var material_atlas_tile_size := 1024
@export var presentation_config: WorldPresentationConfig:
	set(value):
		if presentation_config == value:
			return
		_disconnect_presentation_config(presentation_config)
		presentation_config = value
		_connect_presentation_config()
		_refresh_presentation_config()

const MATERIAL_ATLAS_GUTTER_SIZE := 1
const EDGE_WIDTH_NORMALIZATION := 16.0

var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _metadata: CompiledTerrainData
var _style_texture: ImageTexture
var _property_texture: ImageTexture
var _edge_style_texture: ImageTexture
var _material_atlas_texture: ImageTexture
var _material_atlas_columns := 1
var _material_atlas_size := Vector2.ONE
var _force_full_brightness := false
var _lighting_threshold_offset := 0.0
var _polygon := Polygon2D.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	_ensure_nodes()
	_connect_presentation_config()


func _exit_tree() -> void:
	_disconnect_presentation_config(presentation_config)


func reset() -> void:
	_world = null
	_terrain_registry = null
	_metadata = null
	_style_texture = null
	_property_texture = null
	_edge_style_texture = null
	_material_atlas_texture = null
	_material_atlas_columns = 1
	_material_atlas_size = Vector2.ONE
	_force_full_brightness = false
	_lighting_threshold_offset = 0.0
	if is_instance_valid(_polygon):
		_polygon.polygon = PackedVector2Array()
		_polygon.material = null


func configure(world: WorldGrid, terrain_registry: TerrainRegistry) -> void:
	_world = world
	_terrain_registry = terrain_registry
	_metadata = CompiledTerrainData.compile(terrain_registry)
	_ensure_nodes()
	_style_texture = _create_style_texture(_metadata)
	_property_texture = _create_property_texture(_metadata)
	_edge_style_texture = _create_edge_style_texture(_metadata)
	_material_atlas_texture = _create_material_atlas_texture(_metadata)
	_configure_shader()
	_configure_world_polygon()
	upload_world()


func upload_world() -> void:
	if _world == null:
		return
	_world.upload_cpu_snapshot_to_texture()
	_material.set_shader_parameter("world_data", _world.texture())
	_material.set_shader_parameter("even_world", _world.texture())


func use_simulation_textures(final_texture: Texture2D, even_texture: Texture2D) -> void:
	if final_texture == null or even_texture == null:
		return
	_material.set_shader_parameter("world_data", final_texture)
	_material.set_shader_parameter("even_world", even_texture)


func set_force_full_brightness(enabled: bool) -> void:
	_force_full_brightness = enabled
	_material.set_shader_parameter("force_full_brightness", enabled)


func set_lighting_threshold_offset(offset: float) -> void:
	_lighting_threshold_offset = offset
	_sync_presentation_parameters()


func total_renderer_nodes() -> int:
	return 1 if _world != null else 0


func grid_texture():
	return _world.texture() if _world != null else null


func material_atlas_texture() -> ImageTexture:
	return _material_atlas_texture


func property_texture() -> ImageTexture:
	return _property_texture


func edge_style_texture() -> ImageTexture:
	return _edge_style_texture


func material_atlas_columns() -> int:
	return _material_atlas_columns


func _ensure_nodes() -> void:
	if _polygon.get_parent() == null:
		_polygon.name = "ShaderTerrain"
		add_child(_polygon)


func _configure_shader() -> void:
	if presentation_config == null or presentation_config.terrain_shader == null:
		push_error("WorldPresenter requires a presentation_config with a terrain_shader before configure().")
		_material.shader = null
		_polygon.material = null
		return
	_material.shader = presentation_config.terrain_shader
	_material.set_shader_parameter("world_data", _world.texture())
	_material.set_shader_parameter("even_world", _world.texture())
	_material.set_shader_parameter("style_data", _style_texture)
	_material.set_shader_parameter("terrain_properties", _property_texture)
	_material.set_shader_parameter("edge_style_data", _edge_style_texture)
	_material.set_shader_parameter("edge_width_normalization", EDGE_WIDTH_NORMALIZATION)
	_material.set_shader_parameter("material_atlas", _material_atlas_texture)
	_material.set_shader_parameter("material_atlas_columns", _material_atlas_columns)
	_material.set_shader_parameter("material_atlas_tile_size", float(maxi(1, material_atlas_tile_size)))
	_material.set_shader_parameter("material_atlas_gutter_size", float(MATERIAL_ATLAS_GUTTER_SIZE))
	_material.set_shader_parameter("material_atlas_size", _material_atlas_size)
	_material.set_shader_parameter("force_full_brightness", _force_full_brightness)
	_sync_presentation_parameters()
	_material.set_shader_parameter("hex_radius", hex_radius)
	_material.set_shader_parameter("world_size", Vector2(_world.dimensions.width, _world.dimensions.depth))
	_polygon.material = _material


func _sync_presentation_parameters() -> void:
	if presentation_config == null:
		return
	_material.set_shader_parameter("light_black_threshold", presentation_config.light_black_threshold + _lighting_threshold_offset)
	_material.set_shader_parameter("light_full_brightness_threshold", presentation_config.light_full_brightness_threshold + _lighting_threshold_offset)
	_material.set_shader_parameter("fluid_alpha", presentation_config.fluid_alpha)
	_material.set_shader_parameter("fluid_caustic_strength", presentation_config.fluid_caustic_strength)
	_material.set_shader_parameter("fluid_caustic_scale", presentation_config.fluid_caustic_scale)
	_material.set_shader_parameter("fluid_caustic_speed", presentation_config.fluid_caustic_speed)
	_material.set_shader_parameter("fluid_shimmer_strength", presentation_config.fluid_shimmer_strength)
	_material.set_shader_parameter("fluid_surface_glow_width", presentation_config.fluid_surface_glow_width)
	_material.set_shader_parameter("fluid_surface_glow_strength", presentation_config.fluid_surface_glow_strength)
	_material.set_shader_parameter("fluid_hot_glow_strength", presentation_config.fluid_hot_glow_strength)
	_material.set_shader_parameter("exposed_edge_corner_radius", presentation_config.exposed_edge_corner_radius)
	_material.set_shader_parameter("exposed_edge_jitter_strength", presentation_config.exposed_edge_jitter_strength)
	_material.set_shader_parameter("exposed_edge_jitter_scale", presentation_config.exposed_edge_jitter_scale)


func _connect_presentation_config() -> void:
	if presentation_config != null and not presentation_config.changed.is_connected(_on_presentation_config_changed):
		presentation_config.changed.connect(_on_presentation_config_changed)


func _disconnect_presentation_config(config: WorldPresentationConfig) -> void:
	if config != null and config.changed.is_connected(_on_presentation_config_changed):
		config.changed.disconnect(_on_presentation_config_changed)


func _on_presentation_config_changed() -> void:
	_refresh_presentation_config()


func _refresh_presentation_config() -> void:
	if _world == null or presentation_config == null or presentation_config.terrain_shader == null:
		return
	_configure_shader()
	queue_redraw()


func _configure_world_polygon() -> void:
	var half_height := hex_radius * sqrt(3.0) * 0.5
	var left_edge := HexMetrics.center_for_offset(0, 0, hex_radius).x - hex_radius
	var right_edge := HexMetrics.center_for_offset(_world.dimensions.width - 1, 0, hex_radius).x + hex_radius
	var top_edge := HexMetrics.center_for_offset(0, 0, hex_radius).y - half_height
	var bottom_edge := HexMetrics.center_for_offset(0, _world.dimensions.depth - 1, hex_radius).y + half_height
	_polygon.polygon = PackedVector2Array([
		Vector2(left_edge, top_edge),
		Vector2(right_edge, top_edge),
		Vector2(right_edge, bottom_edge),
		Vector2(left_edge, bottom_edge),
	])


func _create_style_texture(metadata: CompiledTerrainData) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(256 * 4)
	for id in range(256):
		var color := metadata.fill_color_by_id[id] if id < metadata.fill_color_by_id.size() else Color.TRANSPARENT
		var offset := id * 4
		data[offset] = roundi(clampf(color.r, 0.0, 1.0) * 255.0)
		data[offset + 1] = roundi(clampf(color.g, 0.0, 1.0) * 255.0)
		data[offset + 2] = roundi(clampf(color.b, 0.0, 1.0) * 255.0)
		data[offset + 3] = roundi(clampf(color.a, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(256, 1, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)


func _create_edge_style_texture(metadata: CompiledTerrainData) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(256 * 4)
	for id in range(256):
		var color := metadata.edge_color_by_id[id] if id < metadata.edge_color_by_id.size() else Color.TRANSPARENT
		var width := metadata.edge_width_by_id[id] if id < metadata.edge_width_by_id.size() else 0.0
		var offset := id * 4
		data[offset] = roundi(clampf(color.r, 0.0, 1.0) * 255.0)
		data[offset + 1] = roundi(clampf(color.g, 0.0, 1.0) * 255.0)
		data[offset + 2] = roundi(clampf(color.b, 0.0, 1.0) * 255.0)
		data[offset + 3] = roundi(clampf(width / EDGE_WIDTH_NORMALIZATION, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(256, 1, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)


func _create_property_texture(metadata: CompiledTerrainData) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(256 * 4)
	for id in range(256):
		var material_index := int(metadata.material_index_by_id[id]) if id < metadata.material_index_by_id.size() else 0
		var scale := metadata.fill_texture_world_scale_by_id[id] if id < metadata.fill_texture_world_scale_by_id.size() else 64.0
		var offset := id * 4
		# RGBA: motion, block density, material atlas slot, texture scale / 1024.
		data[offset] = int(metadata.motion_by_id[id]) if id < metadata.motion_by_id.size() else 0
		data[offset + 1] = int(metadata.density_by_id[id]) if id < metadata.density_by_id.size() else 0
		data[offset + 2] = clampi(material_index, 0, 255)
		data[offset + 3] = roundi(clampf(scale / 1024.0, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(256, 1, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)


func _create_material_atlas_texture(metadata: CompiledTerrainData) -> ImageTexture:
	var tile_size := maxi(1, material_atlas_tile_size)
	var material_count := maxi(0, metadata.materials.size() - 1)
	_material_atlas_columns = maxi(1, mini(4, material_count))
	var rows := maxi(1, ceili(float(material_count) / float(_material_atlas_columns)))
	var stride := tile_size + MATERIAL_ATLAS_GUTTER_SIZE * 2
	var atlas := Image.create(stride * _material_atlas_columns, stride * rows, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.WHITE)
	for material_index in range(1, metadata.materials.size()):
		var slot := material_index - 1
		var destination := Vector2i(
			(slot % _material_atlas_columns) * stride + MATERIAL_ATLAS_GUTTER_SIZE,
			int(slot / _material_atlas_columns) * stride + MATERIAL_ATLAS_GUTTER_SIZE
		)
		var material := metadata.materials[material_index] as TerrainMaterial
		if material == null or material.fill_texture == null:
			continue
		var source := _material_tile_image(material, tile_size)
		if source == null:
			continue
		atlas.blit_rect(source, Rect2i(0, 0, tile_size, tile_size), destination)
		_blit_material_atlas_gutter(atlas, source, destination, tile_size)
	_material_atlas_size = Vector2(atlas.get_width(), atlas.get_height())
	return ImageTexture.create_from_image(atlas)


func _material_tile_image(material: TerrainMaterial, tile_size: int) -> Image:
	var source := material.fill_texture.get_image()
	if source == null or source.is_empty():
		return null
	source.convert(Image.FORMAT_RGBA8)
	if source.get_width() != tile_size or source.get_height() != tile_size:
		source.resize(tile_size, tile_size, Image.INTERPOLATE_BILINEAR)
	return source


func _blit_material_atlas_gutter(atlas: Image, source: Image, destination: Vector2i, tile_size: int) -> void:
	var last_pixel := tile_size - 1
	for edge_index in range(tile_size):
		atlas.set_pixelv(destination + Vector2i(edge_index, -1), source.get_pixel(edge_index, 0))
		atlas.set_pixelv(destination + Vector2i(edge_index, tile_size), source.get_pixel(edge_index, last_pixel))
		atlas.set_pixelv(destination + Vector2i(-1, edge_index), source.get_pixel(0, edge_index))
		atlas.set_pixelv(destination + Vector2i(tile_size, edge_index), source.get_pixel(last_pixel, edge_index))
	atlas.set_pixelv(destination + Vector2i(-1, -1), source.get_pixel(0, 0))
	atlas.set_pixelv(destination + Vector2i(tile_size, -1), source.get_pixel(last_pixel, 0))
	atlas.set_pixelv(destination + Vector2i(-1, tile_size), source.get_pixel(0, last_pixel))
	atlas.set_pixelv(destination + Vector2i(tile_size, tile_size), source.get_pixel(last_pixel, last_pixel))
