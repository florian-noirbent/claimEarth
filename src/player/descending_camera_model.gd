## Pure model for descending camera movement, off-screen recovery, and bounds clamping.
class_name DescendingCameraModel
extends RefCounted


var top_anchor_ratio := 1.0 / 3.0
var upward_recovery_screen_ratio_per_second := 0.25
var upward_recovery_margin_y := 0.0
var camera_y := -INF
var min_y := -INF
var max_y := INF
var fixed_x := 0.0
var _recovering_upward := false


func reset(current_camera_y: float) -> void:
	camera_y = current_camera_y
	_recovering_upward = false


func update(target_position: Vector2, visible_world_size: Vector2, delta: float) -> Vector2:
	var half_visible_height := visible_world_size.y * 0.5
	var top_edge_y := camera_y - half_visible_height
	if not _recovering_upward and target_position.y < top_edge_y:
		_recovering_upward = true

	if _recovering_upward:
		var recovery_target_y := target_position.y + half_visible_height - upward_recovery_margin_y
		var recovery_distance := visible_world_size.y * upward_recovery_screen_ratio_per_second * delta
		if camera_y > recovery_target_y:
			camera_y = maxf(recovery_target_y, camera_y - recovery_distance)
		else:
			_recovering_upward = false
		camera_y = clampf(camera_y, min_y, max_y)
		return Vector2(fixed_x, camera_y)

	var target_camera_y := target_position.y + visible_world_size.y * (0.5 - top_anchor_ratio)
	if target_camera_y > camera_y:
		camera_y = target_camera_y
	camera_y = clampf(camera_y, min_y, max_y)
	return Vector2(fixed_x, camera_y)
