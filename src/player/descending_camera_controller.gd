class_name DescendingCameraController
extends Camera2D


@export var target: Node2D
@export var top_anchor_ratio := 1.0 / 3.0
@export var min_y := -10000.0
@export var max_y := 100000.0
@export var fixed_x := 0.0

var _model := DescendingCameraModel.new()


func _ready() -> void:
	_model.top_anchor_ratio = top_anchor_ratio
	_model.min_y = min_y
	_model.max_y = max_y
	_model.fixed_x = fixed_x
	_model.reset(global_position.y)


func _process(_delta: float) -> void:
	if target == null:
		return
	global_position = _model.update(global_position, target.global_position, get_viewport_rect().size)


func configure_bounds(min_y_value: float, max_y_value: float) -> void:
	min_y = min_y_value
	max_y = max_y_value
	_model.min_y = min_y_value
	_model.max_y = max_y_value


func configure_horizontal_lock(fixed_x_value: float, zoom_value: Vector2) -> void:
	fixed_x = fixed_x_value
	_model.fixed_x = fixed_x_value
	zoom = zoom_value
