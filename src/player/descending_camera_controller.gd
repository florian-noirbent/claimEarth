## Applies descending camera model output to the active Camera2D.
class_name DescendingCameraController
extends Camera2D


@export var target: Node2D
@export var top_anchor_ratio := 1.0 / 3.0
@export var min_y := -10000.0
@export var max_y := 100000.0
@export var fixed_x := 0.0
@export var shake_decay := 6.0

var _model := DescendingCameraModel.new()
var _shake_strength := 0.0


func _ready() -> void:
	_model.top_anchor_ratio = top_anchor_ratio
	_model.min_y = min_y
	_model.max_y = max_y
	_model.fixed_x = fixed_x
	_model.reset(global_position.y)


func _process(_delta: float) -> void:
	if target == null:
		return
	var target_position := _model.update(global_position, target.global_position, get_viewport_rect().size)
	if _shake_strength > 0.001:
		_shake_strength = maxf(0.0, _shake_strength - _delta * shake_decay)
		target_position += Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	global_position = target_position


func configure_bounds(min_y_value: float, max_y_value: float) -> void:
	min_y = min_y_value
	max_y = max_y_value
	_model.min_y = min_y_value
	_model.max_y = max_y_value


func configure_horizontal_lock(fixed_x_value: float, zoom_value: Vector2) -> void:
	fixed_x = fixed_x_value
	_model.fixed_x = fixed_x_value
	zoom = zoom_value


func apply_shake(intensity: float) -> void:
	_shake_strength = maxf(_shake_strength, intensity)
