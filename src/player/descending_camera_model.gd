class_name DescendingCameraModel
extends RefCounted


var top_anchor_ratio := 1.0 / 3.0
var deepest_camera_y := -INF
var min_y := -INF
var max_y := INF
var fixed_x := 0.0


func reset(current_camera_y: float) -> void:
	deepest_camera_y = current_camera_y


func update(current_camera: Vector2, target_position: Vector2, viewport_size: Vector2) -> Vector2:
	var target_camera_y := target_position.y + viewport_size.y * (0.5 - top_anchor_ratio)
	deepest_camera_y = maxf(deepest_camera_y, target_camera_y)
	var clamped_y := clampf(deepest_camera_y, min_y, max_y)
	return Vector2(fixed_x, clamped_y)
