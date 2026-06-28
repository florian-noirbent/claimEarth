@tool
## Editor-facing terrain edge style for static material boundaries.
class_name TerrainEdgeDefinition
extends Resource


@export var edge_color := Color(0.08, 0.05, 0.03, 1.0)
@export_range(0.0, 12.0, 0.25) var edge_width := 2.0
@export_range(0.0, 1.0, 0.01) var edge_alpha := 1.0
