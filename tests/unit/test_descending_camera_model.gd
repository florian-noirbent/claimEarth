extends GutTest


func test_camera_stays_fixed_when_player_moves_up_but_remains_visible() -> void:
	var model := DescendingCameraModel.new()
	model.reset(100.0)
	model.min_y = 0.0
	model.max_y = 5000.0
	model.fixed_x = 640.0

	var first := model.update(Vector2(50, 300), Vector2(1200, 720), 1.0 / 60.0)
	var second := model.update(Vector2(80, 220), Vector2(1200, 720), 1.0 / 60.0)

	assert_eq(second.y, first.y)
	assert_eq(second.x, 640.0)


func test_camera_recovers_upward_slowly_after_player_leaves_screen() -> void:
	var model := DescendingCameraModel.new()
	model.reset(1000.0)
	model.min_y = 0.0
	model.max_y = 5000.0
	model.upward_recovery_screen_ratio_per_second = 0.25
	model.upward_recovery_margin_y = 60.0

	var camera_position := model.update(Vector2(0.0, 500.0), Vector2(1200.0, 720.0), 0.5)

	assert_eq(camera_position.y, 910.0)


func test_upward_recovery_continues_until_two_hex_margin_is_visible() -> void:
	var model := DescendingCameraModel.new()
	var two_hex_margin := 2.0 * 16.0 * sqrt(3.0)
	model.reset(900.0)
	model.min_y = 0.0
	model.max_y = 5000.0
	model.upward_recovery_screen_ratio_per_second = 0.25
	model.upward_recovery_margin_y = two_hex_margin

	var first := model.update(Vector2(0.0, 500.0), Vector2(1200.0, 720.0), 0.5)
	var second := model.update(Vector2(0.0, 500.0), Vector2(1200.0, 720.0), 0.5)
	var settled := model.update(Vector2(0.0, 500.0), Vector2(1200.0, 720.0), 0.5)

	assert_eq(first.y, 810.0)
	assert_almost_eq(second.y, 500.0 + 360.0 - two_hex_margin, 0.001)
	assert_eq(settled.y, second.y)
	assert_almost_eq(500.0 - (settled.y - 360.0), two_hex_margin, 0.001)


func test_camera_clamps_to_bounds() -> void:
	var model := DescendingCameraModel.new()
	model.reset(0.0)
	model.min_y = 10.0
	model.max_y = 100.0

	var camera_position := model.update(Vector2(0, 1000), Vector2(1200, 720), 1.0 / 60.0)
	assert_eq(camera_position.y, 100.0)
