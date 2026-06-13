class_name DepthMarkerPresenter
extends Node2D


@export var personal_color := Color(0.96, 0.82, 0.28, 0.85)
@export var global_color := Color(0.4, 0.88, 0.94, 0.85)
@export var line_width := 3.0
@export var dash_length := 18.0
@export var dash_gap := 10.0

var _hex_radius := 16.0
var _left_x := -100.0
var _right_x := 100.0
var _personal_depth := -1
var _global_depth := -1
var _global_owner := ""


func configure_bounds(left_x: float, right_x: float, hex_radius: float) -> void:
	_left_x = left_x
	_right_x = right_x
	_hex_radius = hex_radius
	queue_redraw()


func set_personal_depth(depth: int) -> void:
	_personal_depth = depth
	queue_redraw()


func set_global_depth(depth: int, owner: String) -> void:
	_global_depth = depth
	_global_owner = owner
	queue_redraw()


func _draw() -> void:
	if _personal_depth >= 0:
		_draw_marker(_personal_depth, personal_color, "Personal best")
	if _global_depth >= 0:
		var label := "Earth owned by %s" % _global_owner if not _global_owner.is_empty() else "Global best"
		_draw_marker(_global_depth, global_color, label, 20.0)


func _draw_marker(depth: int, color: Color, label: String, label_offset := 0.0) -> void:
	var y := HexMetrics.center_for_offset(0, depth, _hex_radius).y
	var x := _left_x
	while x < _right_x:
		var next_x := minf(x + dash_length, _right_x)
		draw_line(Vector2(x, y), Vector2(next_x, y), color, line_width)
		x += dash_length + dash_gap
	draw_string(
		ThemeDB.fallback_font,
		Vector2(_left_x + 10.0, y - 8.0 - label_offset),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		color
	)
