## Applies descending camera model output to the active Camera2D.
class_name DescendingCameraController
extends Camera2D


@export var target: Node2D
@export var top_anchor_ratio := 1.0 / 3.0
@export_range(0.0, 1.0, 0.01) var upward_recovery_screen_ratio_per_second := 0.25
@export_range(0.0, 10.0, 0.25) var upward_recovery_margin_hexes := 2.0
@export var min_y := -10000.0
@export var max_y := 100000.0
@export var fixed_x := 0.0
@export var shake_decay := 6.0

var _model := DescendingCameraModel.new()
var _shake_strength := 0.0
var _world_bottom_edge := INF


func _ready() -> void:
	_model.top_anchor_ratio = top_anchor_ratio
	_model.upward_recovery_screen_ratio_per_second = upward_recovery_screen_ratio_per_second
	_model.min_y = min_y
	_model.max_y = max_y
	_model.fixed_x = fixed_x
	_model.reset(global_position.y)


func _process(delta: float) -> void:
	if target == null:
		return
	var viewport_size := get_viewport_rect().size
	var visible_world_size := Vector2(
		viewport_size.x / maxf(absf(zoom.x), 0.001),
		viewport_size.y / maxf(absf(zoom.y), 0.001)
	)
	_apply_world_bottom_edge(visible_world_size.y)
	var target_position := _model.update(target.global_position, visible_world_size, delta)
	if _shake_strength > 0.001:
		_shake_strength = maxf(0.0, _shake_strength - delta * shake_decay)
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


func configure_world_bottom_edge(bottom_edge: float) -> void:
	_world_bottom_edge = bottom_edge


func _apply_world_bottom_edge(visible_world_height: float) -> void:
	if is_inf(_world_bottom_edge):
		return
	_model.max_y = _world_bottom_edge - maxf(visible_world_height, 0.0) * 0.5


func configure_horizontal_lock(fixed_x_value: float, zoom_value: Vector2) -> void:
	fixed_x = fixed_x_value
	_model.fixed_x = fixed_x_value
	zoom = zoom_value


func configure_upward_recovery_margin(hex_radius: float) -> void:
	_model.upward_recovery_margin_y = upward_recovery_margin_hexes * hex_radius * sqrt(3.0)


func apply_shake(intensity: float) -> void:
	_shake_strength = maxf(_shake_strength, intensity)
