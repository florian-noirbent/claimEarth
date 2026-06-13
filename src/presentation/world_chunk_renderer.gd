class_name WorldChunkRenderer
extends Node2D


class ChunkCanvas:
	extends Node2D

	var chunk_rect := Rect2i()
	var world: WorldGrid
	var terrain_registry: TerrainRegistry
	var hex_radius := 16.0
	var world_origin := Vector2.ZERO
	var _corners := PackedVector2Array()

	func _ready() -> void:
		_corners = HexMetrics.corners(hex_radius)

	func configure(
		world_value: WorldGrid,
		terrain_registry_value: TerrainRegistry,
		chunk_rect_value: Rect2i,
		hex_radius_value: float,
		world_origin_value: Vector2
	) -> void:
		world = world_value
		terrain_registry = terrain_registry_value
		chunk_rect = chunk_rect_value
		hex_radius = hex_radius_value
		world_origin = world_origin_value
		_corners = HexMetrics.corners(hex_radius)
		queue_redraw()

	func _draw() -> void:
		if world == null or terrain_registry == null:
			return

		for row in range(chunk_rect.position.y, chunk_rect.end.y):
			for col in range(chunk_rect.position.x, chunk_rect.end.x):
				var definition := terrain_registry.get_definition(world.get_committed_by_offset(col, row))
				if definition == null or definition.debug_color.a <= 0.0:
					continue

				var center := HexMetrics.center_for_offset(col, row, hex_radius) - world_origin
				var polygon := PackedVector2Array()
				for corner in _corners:
					polygon.append(center + corner)
				var style = definition.visual_style
				if style != null:
					draw_colored_polygon(polygon, style.fill_color)
					_draw_pattern(center, style, col, row)
				else:
					draw_colored_polygon(polygon, definition.debug_color)

				if definition.is_solid:
					for direction in range(6):
						var neighbor := HexCoord.from_offset_odd_q(col, row).neighbor(direction).to_offset_odd_q()
						var should_outline := true
						if world.dimensions.is_in_bounds_offset(neighbor.x, neighbor.y):
							var neighbor_definition := terrain_registry.get_definition(
								world.get_committed_by_offset(neighbor.x, neighbor.y)
							)
							should_outline = neighbor_definition == null or neighbor_definition.is_passable
						if should_outline:
							var edge_corners := HexMetrics.edge_corner_indices_for_direction(direction)
							var start_corner := center + _corners[edge_corners.x]
							var end_corner := center + _corners[edge_corners.y]
							var outline_color: Color = style.outline_color if style != null else Color(0.08, 0.05, 0.03, 1.0)
							var outline_width: float = style.outline_width if style != null else 2.0
							draw_line(start_corner, end_corner, outline_color, outline_width)

	func _draw_pattern(center: Vector2, style, col: int, row: int) -> void:
		var phase := float((col * 17 + row * 31) % 7)
		match String(style.pattern_mode):
			"grain":
				for index in range(3):
					var offset := Vector2(-5 + index * 4, -4 + fmod(phase + index * 3.0, 8.0))
					draw_line(
						center + offset,
						center + offset + Vector2(3, 2),
						Color(style.accent_color.r, style.accent_color.g, style.accent_color.b, style.pattern_strength),
						1.5
					)
			"flow":
				for index in range(2):
					var y := -4.0 + index * 8.0
					var points := PackedVector2Array([
						center + Vector2(-8, y),
						center + Vector2(-2, y + sin(phase + float(index)) * 2.0),
						center + Vector2(6, y),
					])
					draw_polyline(points, Color(style.accent_color.r, style.accent_color.g, style.accent_color.b, style.pattern_strength), 2.0)
			"cross":
				draw_line(
					center + Vector2(-6, -6),
					center + Vector2(6, 6),
					Color(style.accent_color.r, style.accent_color.g, style.accent_color.b, style.pattern_strength),
					2.0
				)
				draw_line(
					center + Vector2(-6, 6),
					center + Vector2(6, -6),
					Color(style.accent_color.r, style.accent_color.g, style.accent_color.b, style.pattern_strength),
					2.0
				)


var chunk_coord := Vector2i.ZERO
var chunk_rect := Rect2i()
var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _hex_radius := 16.0
var _sprite: Sprite2D
var _viewport: SubViewport
var _canvas: ChunkCanvas
var _chunk_bounds := Rect2()


func _ready() -> void:
	_ensure_render_nodes()
	if _world != null and _terrain_registry != null:
		_rebuild_texture()


func configure(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	chunk_coord_value: Vector2i,
	chunk_rect_value: Rect2i
) -> void:
	_world = world
	_terrain_registry = terrain_registry
	chunk_coord = chunk_coord_value
	chunk_rect = chunk_rect_value
	_rebuild_texture()


func texture_size() -> Vector2i:
	if _viewport == null:
		return Vector2i.ZERO
	return _viewport.size


func _ensure_render_nodes() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = false
		add_child(_sprite)
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.disable_3d = true
		_viewport.transparent_bg = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_viewport.canvas_cull_mask = 1
		add_child(_viewport)
	if _canvas == null:
		_canvas = ChunkCanvas.new()
		_viewport.add_child(_canvas)


func _rebuild_texture() -> void:
	if _world == null or _terrain_registry == null:
		return
	_ensure_render_nodes()

	_chunk_bounds = _compute_chunk_bounds()
	position = _chunk_bounds.position
	_sprite.position = Vector2.ZERO

	var texture_size := Vector2i(
		maxi(1, ceili(_chunk_bounds.size.x)),
		maxi(1, ceili(_chunk_bounds.size.y))
	)
	_viewport.size = texture_size
	_canvas.position = -_chunk_bounds.position
	_canvas.configure(_world, _terrain_registry, chunk_rect, _hex_radius, _chunk_bounds.position)
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sprite.texture = _viewport.get_texture()


func _compute_chunk_bounds() -> Rect2:
	var corners := HexMetrics.corners(_hex_radius)
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for row in range(chunk_rect.position.y, chunk_rect.end.y):
		for col in range(chunk_rect.position.x, chunk_rect.end.x):
			var center := HexMetrics.center_for_offset(col, row, _hex_radius)
			for corner in corners:
				var point := center + corner
				min_point.x = minf(min_point.x, point.x)
				min_point.y = minf(min_point.y, point.y)
				max_point.x = maxf(max_point.x, point.x)
				max_point.y = maxf(max_point.y, point.y)
	var padding := 4.0
	min_point -= Vector2.ONE * padding
	max_point += Vector2.ONE * padding
	return Rect2(min_point, max_point - min_point)
