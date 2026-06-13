extends GutTest


func test_camera_never_moves_upward_once_deeper_position_is_seen() -> void:
	var model := DescendingCameraModel.new()
	model.reset(100.0)
	model.min_y = 0.0
	model.max_y = 5000.0

	var first := model.update(Vector2(0, 100), Vector2(50, 300), Vector2(1200, 720))
	var second := model.update(first, Vector2(80, 220), Vector2(1200, 720))

	assert_true(second.y >= first.y)


func test_camera_clamps_to_bounds() -> void:
	var model := DescendingCameraModel.new()
	model.reset(0.0)
	model.min_y = 10.0
	model.max_y = 100.0

	var position := model.update(Vector2.ZERO, Vector2(0, 1000), Vector2(1200, 720))
	assert_eq(position.y, 100.0)
