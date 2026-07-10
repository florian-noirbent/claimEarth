@tool
## Draws the shared run and preview backdrop behind terrain.
class_name WorldBackground
extends Node2D


@export var presentation_config: WorldPresentationConfig:
	set(value):
		if presentation_config == value:
			return
		_disconnect_presentation_config(presentation_config)
		presentation_config = value
		_connect_presentation_config()
		_refresh_presentation_config()

var _left_edge := -512.0
var _right_edge := 512.0
var _level_zero_y := 0.0
var _bottom_edge := 4096.0
var _shader_material := ShaderMaterial.new()


func _ready() -> void:
	z_index = -100
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_connect_presentation_config()
	_refresh_presentation_config()
	set_process(Engine.is_editor_hint())


func _exit_tree() -> void:
	_disconnect_presentation_config(presentation_config)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_sync_shader_parameters()
	queue_redraw()


func configure_bounds(left_edge: float, right_edge: float, level_zero_y: float, bottom_edge: float) -> void:
	_left_edge = left_edge
	_right_edge = right_edge
	_level_zero_y = level_zero_y
	_bottom_edge = bottom_edge
	_sync_shader_parameters()
	queue_redraw()


func cave_rect() -> Rect2:
	return Rect2(_left_edge, _level_zero_y, _right_edge - _left_edge, maxf(0.0, _bottom_edge - _level_zero_y))


func sky_rect() -> Rect2:
	return Rect2(_left_edge, _level_zero_y - _sky_height(), _right_edge - _left_edge, _sky_height())


func grass_band_rect() -> Rect2:
	var grass_texture := _grass_band_texture()
	if grass_texture == null:
		return Rect2(_left_edge, _level_zero_y, _right_edge - _left_edge, 0.0)
	var effective_scale := maxf(0.01, presentation_config.grass_band_scale)
	var height := _grass_band_source_rect().size.y * effective_scale
	return Rect2(_left_edge, _level_zero_y - height + presentation_config.grass_band_y_offset, _right_edge - _left_edge, height)


func shader_parameters() -> Dictionary:
	var band_rect := grass_band_rect()
	return {
		"level_zero_y": _level_zero_y,
		"left_edge": _left_edge,
		"right_edge": _right_edge,
		"grass_band_top": band_rect.position.y,
		"grass_band_bottom": band_rect.end.y,
		"cave_saturation": presentation_config.cave_saturation,
		"cave_brightness": presentation_config.cave_brightness,
		"cave_contrast": presentation_config.cave_contrast,
		"cave_tint": presentation_config.cave_tint,
		"cave_tint_strength": presentation_config.cave_tint_strength,
		"depth_darkening": presentation_config.depth_darkening,
		"depth_darkening_distance": presentation_config.depth_darkening_distance,
		"side_vignette_strength": presentation_config.side_vignette_strength,
		"side_vignette_inner": presentation_config.side_vignette_inner,
	}


func _draw() -> void:
	if presentation_config == null:
		return
	_draw_sky()
	_draw_cave_texture()
	_draw_grass_band()


func _draw_sky() -> void:
	var rect := sky_rect()
	var step_count := maxi(1, presentation_config.sky_gradient_steps)
	var step_height := rect.size.y / float(step_count)
	for step in range(step_count):
		var weight := float(step) / float(maxi(1, step_count - 1))
		var color := presentation_config.sky_top_color.lerp(presentation_config.sky_horizon_color, weight)
		draw_rect(Rect2(rect.position + Vector2(0.0, step_height * float(step)), Vector2(rect.size.x, step_height + 1.0)), color)


func _draw_cave_texture() -> void:
	var cave_texture := _cave_texture()
	if cave_texture == null:
		return
	var rect := cave_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var effective_scale := maxf(0.01, presentation_config.cave_texture_scale)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(effective_scale, effective_scale))
	draw_texture_rect(cave_texture, Rect2(rect.position / effective_scale, rect.size / effective_scale), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_grass_band() -> void:
	var grass_texture := _grass_band_texture()
	if grass_texture == null:
		return
	var rect := grass_band_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var effective_scale := maxf(0.01, presentation_config.grass_band_scale)
	var source_rect := _grass_band_source_rect()
	var tile_width := source_rect.size.x * effective_scale
	var tile_height := source_rect.size.y * effective_scale
	var draw_x := rect.position.x
	while draw_x < rect.end.x:
		var remaining_width := rect.end.x - draw_x
		var destination_width := minf(tile_width, remaining_width)
		var visible_source_width := source_rect.size.x * destination_width / tile_width
		var destination_rect := Rect2(draw_x, rect.position.y, destination_width, tile_height)
		var tile_source_rect := Rect2(source_rect.position, Vector2(visible_source_width, source_rect.size.y))
		draw_texture_rect_region(grass_texture, destination_rect, tile_source_rect)
		draw_x += tile_width


func _grass_band_source_rect() -> Rect2:
	var grass_texture := _grass_band_texture()
	if grass_texture == null:
		return Rect2()
	var texture_size := grass_texture.get_size()
	var top_crop := clampf(presentation_config.grass_band_top_crop_px, 0.0, maxf(0.0, texture_size.y - 1.0))
	var bottom_crop := clampf(presentation_config.grass_band_bottom_crop_px, 0.0, maxf(0.0, texture_size.y - top_crop - 1.0))
	return Rect2(0.0, top_crop, texture_size.x, texture_size.y - top_crop - bottom_crop)


func _cave_texture() -> Texture2D:
	return presentation_config.cave_texture if presentation_config != null else null


func _grass_band_texture() -> Texture2D:
	return presentation_config.grass_band_texture if presentation_config != null else null


func _sky_height() -> float:
	return presentation_config.sky_height if presentation_config != null else 0.0


func _connect_presentation_config() -> void:
	if presentation_config != null and not presentation_config.changed.is_connected(_on_presentation_config_changed):
		presentation_config.changed.connect(_on_presentation_config_changed)


func _disconnect_presentation_config(config: WorldPresentationConfig) -> void:
	if config != null and config.changed.is_connected(_on_presentation_config_changed):
		config.changed.disconnect(_on_presentation_config_changed)


func _on_presentation_config_changed() -> void:
	_refresh_presentation_config()


func _refresh_presentation_config() -> void:
	if presentation_config == null:
		return
	_shader_material.shader = presentation_config.background_shader
	material = _shader_material
	_sync_shader_parameters()
	queue_redraw()


func _sync_shader_parameters() -> void:
	if _shader_material == null or presentation_config == null:
		return
	var parameters := shader_parameters()
	for parameter_name in parameters.keys():
		_shader_material.set_shader_parameter(parameter_name, parameters[parameter_name])
