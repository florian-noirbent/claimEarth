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
						draw_line(start_corner, end_corner, Color(0.08, 0.05, 0.03, 1.0), 2.0)
