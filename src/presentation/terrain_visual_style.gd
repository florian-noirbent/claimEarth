@tool
class_name TerrainVisualStyle
extends Resource


@export var fill_color := Color.WHITE
@export var accent_color := Color(1, 1, 1, 0.2)
@export var outline_color := Color(0.08, 0.05, 0.03, 1.0)
@export_enum("solid", "grain", "flow", "cross") var pattern_mode := "solid"
@export_range(0.0, 1.0, 0.01) var pattern_strength := 0.3
@export_range(2.0, 32.0, 0.5) var pattern_spacing := 10.0
@export_range(1.0, 8.0, 0.5) var outline_width := 2.0
