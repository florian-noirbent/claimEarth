extends GutTest


const GrappleAnchorQueryScript = preload("res://src/player/grapple_anchor_query.gd")
const GrappleAnchorScript = preload("res://src/player/grapple_anchor.gd")
const GrappleModelScript = preload("res://src/player/grapple_model.gd")
const GrappleConfigScript = preload("res://src/player/grapple_config.gd")
const GrappleInputFrameScript = preload("res://src/player/grapple_input_frame.gd")


class FakeAnchorQuery:
	extends "res://src/player/grapple_anchor_query.gd"

	var anchor_to_return: GrappleAnchor
	var valid := true

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return anchor_to_return

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return valid


func test_hook_press_attaches_and_release_detaches() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(2, 3), Vector2(80, 20))
	var model = GrappleModelScript.new(GrappleConfigScript.new(), query)
	var input_frame = GrappleInputFrameScript.new()
	input_frame.hook_pressed = true
	input_frame.aim_position = Vector2(120, 0)

	model.update(input_frame, Vector2.ZERO, Vector2.ZERO, 0.016)

	assert_true(model.state.is_attached)
	assert_not_null(model.state.anchor)

	var release_frame = GrappleInputFrameScript.new()
	release_frame.hook_released = true
	model.update(release_frame, Vector2.ZERO, Vector2.ZERO, 0.016)

	assert_false(model.state.is_attached)
	assert_null(model.state.anchor)


func test_rope_adjustment_and_tangential_momentum_apply_while_attached() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(4, 2), Vector2(100, 0))
	var config = GrappleConfigScript.new()
	config.min_rope_length = 20.0
	config.max_rope_length = 200.0
	config.rope_adjust_speed = 50.0
	config.tangential_acceleration = 120.0
	var model = GrappleModelScript.new(config, query)

	var attach_frame = GrappleInputFrameScript.new()
	attach_frame.hook_pressed = true
	attach_frame.aim_position = Vector2(120, 0)
	model.update(attach_frame, Vector2.ZERO, Vector2.ZERO, 0.016)

	var swing_frame = GrappleInputFrameScript.new()
	swing_frame.move_axis = 1.0
	swing_frame.rope_axis = -1.0
	var velocity := model.update(swing_frame, Vector2(0, 100), Vector2.ZERO, 0.5)

	assert_lt(model.state.rope_length, 100.0)
	assert_gt(velocity.length(), 0.0)


func test_constraint_prevents_moving_farther_outward_than_rope_length() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(1, 1), Vector2.ZERO)
	var config = GrappleConfigScript.new()
	config.min_rope_length = 25.0
	var model = GrappleModelScript.new(config, query)

	var attach_frame = GrappleInputFrameScript.new()
	attach_frame.hook_pressed = true
	attach_frame.aim_position = Vector2.RIGHT * 30.0
	model.update(attach_frame, Vector2.RIGHT * 40.0, Vector2.RIGHT * 80.0, 0.016)

	var resolved := model.constrain_position(Vector2.RIGHT * 100.0, Vector2.RIGHT * 60.0)

	assert_almost_eq((resolved.position as Vector2).length(), model.state.rope_length, 0.001)
	assert_eq((resolved.velocity as Vector2).x, 0.0)


func test_invalid_anchor_drops_attachment() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(1, 1), Vector2(20, 20))
	var model = GrappleModelScript.new(GrappleConfigScript.new(), query)

	var attach_frame = GrappleInputFrameScript.new()
	attach_frame.hook_pressed = true
	attach_frame.aim_position = Vector2(20, 20)
	model.update(attach_frame, Vector2.ZERO, Vector2.ZERO, 0.016)

	query.valid = false
	model.update(GrappleInputFrameScript.new(), Vector2.ZERO, Vector2.ZERO, 0.016)

	assert_false(model.state.is_attached)
