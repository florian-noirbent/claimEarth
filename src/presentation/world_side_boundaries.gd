class_name WorldSideBoundaries
extends StaticBody2D


@export var wall_thickness := 64.0

var _left_shape := CollisionShape2D.new()
var _right_shape := CollisionShape2D.new()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	if _left_shape.get_parent() == null:
		add_child(_left_shape)
	if _right_shape.get_parent() == null:
		add_child(_right_shape)


func configure(left_edge: float, right_edge: float, top_edge: float, bottom_edge: float) -> void:
	var wall_height := maxf(1.0, bottom_edge - top_edge)
	var wall_center_y := (top_edge + bottom_edge) * 0.5
	_left_shape.shape = _rectangle_shape(Vector2(wall_thickness, wall_height))
	_right_shape.shape = _rectangle_shape(Vector2(wall_thickness, wall_height))
	_left_shape.position = Vector2(left_edge - wall_thickness * 0.5, wall_center_y)
	_right_shape.position = Vector2(right_edge + wall_thickness * 0.5, wall_center_y)


func left_wall_inner_edge() -> float:
	return _left_shape.position.x + wall_thickness * 0.5


func right_wall_inner_edge() -> float:
	return _right_shape.position.x - wall_thickness * 0.5


func _rectangle_shape(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape
