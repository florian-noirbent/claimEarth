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
	var last_target := Vector2.ZERO

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		last_target = _target
		return anchor_to_return

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return valid


class FakeGrappleTarget:
	extends GrappleTarget

	var valid := true
	var center := Vector2.ZERO
	var circle_radius := 8.0
	var pulls: Array[Dictionary] = []

	func is_valid() -> bool:
		return valid

	func anchor_position() -> Vector2:
		return center

	func radius() -> float:
		return circle_radius

	func pull_toward(point: Vector2, overshoot: float, delta: float) -> void:
		pulls.append({"point": point, "overshoot": overshoot, "delta": delta})


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

	var resolved := model.constrain_position(Vector2.RIGHT * 100.0, Vector2.RIGHT * 60.0, 1.0)

	assert_almost_eq((resolved.position as Vector2).length(), model.state.rope_length, 0.001)
	assert_eq((resolved.velocity as Vector2).x, 0.0)


func test_anchor_within_leeway_pulls_in_smoothly_and_preserves_tangent() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(1, 1), Vector2.ZERO)
	var config = GrappleConfigScript.new()
	config.max_rope_length = 100.0
	config.attach_range_leeway_ratio = 0.1
	config.pull_in_speed = 50.0
	var model = GrappleModelScript.new(config, query)

	var attach_frame = GrappleInputFrameScript.new()
	attach_frame.hook_pressed = true
	attach_frame.aim_position = Vector2.ZERO
	model.update(attach_frame, Vector2.LEFT * 109.0, Vector2.ZERO, 0.016)

	assert_true(model.state.is_attached)
	assert_eq(model.state.rope_length, config.max_rope_length)

	var resolved := model.constrain_position(Vector2.LEFT * 109.0, Vector2(-20.0, 30.0), 0.1)

	assert_almost_eq((resolved.position as Vector2).length(), 104.0, 0.001)
	assert_eq((resolved.velocity as Vector2).x, 0.0)
	assert_eq((resolved.velocity as Vector2).y, 30.0)


func test_anchor_beyond_leeway_does_not_attach_or_change_velocity() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(1, 1), Vector2.ZERO)
	var config = GrappleConfigScript.new()
	config.max_rope_length = 100.0
	config.attach_range_leeway_ratio = 0.1
	var model = GrappleModelScript.new(config, query)
	var input_frame = GrappleInputFrameScript.new()
	input_frame.hook_pressed = true
	input_frame.aim_position = Vector2.LEFT * 111.0

	var velocity := model.update(input_frame, Vector2.LEFT * 111.0, Vector2(12.0, 34.0), 0.016)

	assert_false(model.state.is_attached)
	assert_eq(velocity, Vector2(12.0, 34.0))


func test_hook_press_queries_full_range_in_mouse_direction() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(1, 1), Vector2.RIGHT * 40.0)
	var config = GrappleConfigScript.new()
	config.max_rope_length = 100.0
	config.attach_range_leeway_ratio = 0.1
	var model = GrappleModelScript.new(config, query)
	var input_frame = GrappleInputFrameScript.new()
	input_frame.hook_pressed = true
	input_frame.aim_position = Vector2.RIGHT * 10.0

	model.update(input_frame, Vector2.ZERO, Vector2.ZERO, 0.016)

	assert_eq(query.last_target, Vector2.RIGHT * config.effective_attach_range())
	assert_true(model.state.is_attached)


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


func test_target_anchor_rope_runs_to_target_and_follows_it() -> void:
	var target := FakeGrappleTarget.new()
	target.center = Vector2(60, 0)
	var model = _model_attached_to_target(target, GrappleConfigScript.new())

	assert_true(model.is_target_attached())
	assert_false(model.is_swing_attached())
	assert_almost_eq(model.state.rope_length, 60.0, 0.001, "Rope spans to the anchor point, not the rim contact")
	assert_eq(model.current_anchor_position(), Vector2(60, 0))

	target.center = Vector2(90, -20)

	assert_eq(model.current_anchor_position(), Vector2(90, -20))
	assert_eq(model.state.anchor.current_position(), Vector2(90, -20))


func test_taut_target_rope_pulls_target_without_constraining_player() -> void:
	var target := FakeGrappleTarget.new()
	target.center = Vector2(50, 0)
	var model = _model_attached_to_target(target, GrappleConfigScript.new())

	var resolved: Dictionary = model.constrain_position(Vector2(-30, 0), Vector2(-60, 5), 0.1)

	assert_eq(resolved["position"], Vector2(-30, 0))
	assert_eq(resolved["velocity"], Vector2(-60, 5))
	assert_eq(target.pulls.size(), 1)
	assert_eq(target.pulls[0]["point"], Vector2(-30, 0))
	assert_almost_eq(float(target.pulls[0]["overshoot"]), 30.0, 0.001)
	assert_almost_eq(float(target.pulls[0]["delta"]), 0.1, 0.000001)


func test_slack_target_rope_does_not_pull() -> void:
	var target := FakeGrappleTarget.new()
	target.center = Vector2(50, 0)
	var model = _model_attached_to_target(target, GrappleConfigScript.new())

	model.constrain_position(Vector2(20, 0), Vector2.ZERO, 0.1)

	assert_true(target.pulls.is_empty())


func test_reeling_in_a_target_pulls_by_the_shortened_length() -> void:
	var target := FakeGrappleTarget.new()
	target.center = Vector2(100, 0)
	var config = GrappleConfigScript.new()
	config.rope_adjust_speed = 40.0
	var model = _model_attached_to_target(target, config)
	var reel_frame = GrappleInputFrameScript.new()
	reel_frame.rope_axis = -1.0

	model.update(reel_frame, Vector2.ZERO, Vector2.ZERO, 0.5)
	var resolved: Dictionary = model.constrain_position(Vector2.ZERO, Vector2.ZERO, 0.5)

	assert_almost_eq(model.state.rope_length, 80.0, 0.001)
	assert_eq(resolved["position"], Vector2.ZERO)
	assert_eq(target.pulls.size(), 1)
	assert_almost_eq(float(target.pulls[0]["overshoot"]), 20.0, 0.001)


func test_target_attachment_applies_no_swing_acceleration() -> void:
	var target := FakeGrappleTarget.new()
	target.center = Vector2(0, -80)
	var config = GrappleConfigScript.new()
	config.tangential_acceleration = 500.0
	var model = _model_attached_to_target(target, config)
	var move_frame = GrappleInputFrameScript.new()
	move_frame.move_axis = 1.0

	var velocity: Vector2 = model.update(move_frame, Vector2.ZERO, Vector2(3, 4), 0.5)

	assert_eq(velocity, Vector2(3, 4))
	assert_true(model.state.is_attached)


func test_invalid_target_is_not_pulled_and_detaches_on_next_update() -> void:
	var target := FakeGrappleTarget.new()
	target.center = Vector2(50, 0)
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(-1, -1), Vector2(42, 0), target)
	var model = GrappleModelScript.new(GrappleConfigScript.new(), query)
	_press_hook(model, Vector2.ZERO, Vector2(50, 0))
	target.center = Vector2(60, 0)
	assert_eq(model.current_anchor_position(), Vector2(60, 0))

	target.valid = false
	target.center = Vector2(500, 0)
	model.constrain_position(Vector2(-200, 0), Vector2.ZERO, 0.1)

	assert_true(target.pulls.is_empty())
	assert_eq(model.current_anchor_position(), Vector2(60, 0), "An invalid target keeps its last valid anchor point")

	query.valid = false
	model.update(GrappleInputFrameScript.new(), Vector2.ZERO, Vector2.ZERO, 0.016)

	assert_false(model.state.is_attached)
	assert_false(model.is_target_attached())


func test_hook_release_detaches_from_target() -> void:
	var target := FakeGrappleTarget.new()
	target.center = Vector2(50, 0)
	var model = _model_attached_to_target(target, GrappleConfigScript.new())
	var release_frame = GrappleInputFrameScript.new()
	release_frame.hook_released = true

	model.update(release_frame, Vector2.ZERO, Vector2.ZERO, 0.016)

	assert_false(model.state.is_attached)
	assert_eq(model.current_anchor_position(), Vector2.ZERO)


func test_terrain_anchor_reports_swing_attachment_at_fixed_contact() -> void:
	var query := FakeAnchorQuery.new()
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(4, 2), Vector2(100, 0))
	var model = GrappleModelScript.new(GrappleConfigScript.new(), query)

	_press_hook(model, Vector2.ZERO, Vector2(120, 0))

	assert_true(model.is_swing_attached())
	assert_false(model.is_target_attached())
	assert_eq(model.current_anchor_position(), Vector2(100, 0))
	assert_almost_eq(model.state.rope_length, 100.0, 0.001)


func _model_attached_to_target(target: FakeGrappleTarget, config: GrappleConfig):
	var query := FakeAnchorQuery.new()
	var contact := target.center - target.center.normalized() * target.circle_radius
	query.anchor_to_return = GrappleAnchorScript.new(Vector2i(-1, -1), contact, target)
	var model = GrappleModelScript.new(config, query)
	_press_hook(model, Vector2.ZERO, target.center)
	assert_true(model.state.is_attached)
	return model


func _press_hook(model, player_position: Vector2, aim_position: Vector2) -> void:
	var attach_frame = GrappleInputFrameScript.new()
	attach_frame.hook_pressed = true
	attach_frame.aim_position = aim_position
	model.update(attach_frame, player_position, Vector2.ZERO, 0.016)
