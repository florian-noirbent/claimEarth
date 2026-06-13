class_name WorldChunkRenderer
extends Node2D


var chunk_coord := Vector2i.ZERO
var chunk_rect := Rect2i()
var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _hex_radius := 16.0
var _corners := PackedVector2Array()


func _ready() -> void:
	_corners = HexMetrics.corners(_hex_radius)


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
	queue_redraw()


func _draw() -> void:
	if _world == null or _terrain_registry == null:
		return

	for row in range(chunk_rect.position.y, chunk_rect.end.y):
		for col in range(chunk_rect.position.x, chunk_rect.end.x):
			var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(col, row))
			if definition == null or definition.debug_color.a <= 0.0:
				continue

			var center := HexMetrics.center_for_offset(col, row, _hex_radius)
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
					if _world.dimensions.is_in_bounds_offset(neighbor.x, neighbor.y):
						var neighbor_definition := _terrain_registry.get_definition(
							_world.get_committed_by_offset(neighbor.x, neighbor.y)
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
