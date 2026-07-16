extends GutTest


func test_body_visuals_follow_movement_facing_and_ragdoll_state() -> void:
	var presentation := await _presentation()

	presentation.update_body(
		PlayerMovementState.RUN,
		Vector2.LEFT,
		false,
		1.0,
		8.0,
		0.1
	)
	assert_eq(presentation.body_visual.scale, Vector2(-1.05, 0.95))
	assert_eq(presentation.body_visual.rotation, 0.0)

	presentation.update_body(
		PlayerMovementState.JUMP,
		Vector2.RIGHT,
		false,
		1.0,
		8.0,
		0.1
	)
	assert_eq(presentation.body_visual.scale, Vector2(0.95, 1.08))

	presentation.update_body(
		PlayerMovementState.FALL,
		Vector2.ZERO,
		true,
		-1.0,
		8.0,
		0.1
	)
	assert_eq(presentation.body_visual.scale, Vector2(1.06, 0.94))
	assert_almost_eq(presentation.body_visual.rotation, -0.8, 0.001)


func test_hook_launch_interpolates_then_hides_without_attachment() -> void:
	var presentation := await _presentation()
	presentation.global_position = Vector2(10.0, 20.0)
	presentation.hook_launch_animation_seconds = 0.1

	presentation.start_hook_launch(Vector2(110.0, 20.0))
	presentation.update_grapple(false, Vector2.ZERO, 0.05)

	assert_true(presentation.rope_line.visible)
	assert_true(presentation.hook_indicator.visible)
	assert_almost_eq(presentation.rope_line.points[1].x, 50.0, 0.001)
	assert_almost_eq(presentation.rope_line.points[1].y, 0.0, 0.001)

	presentation.update_grapple(false, Vector2.ZERO, 0.05)
	assert_false(presentation.rope_line.visible)
	assert_false(presentation.hook_indicator.visible)


func test_attached_grapple_draws_world_anchor_and_cancel_stops_launch() -> void:
	var presentation := await _presentation()
	presentation.global_position = Vector2(10.0, 20.0)
	presentation.hook_launch_animation_seconds = 1.0
	presentation.start_hook_launch(Vector2(110.0, 20.0))
	presentation.cancel_hook_launch()

	presentation.update_grapple(true, Vector2(50.0, -20.0), 0.1)

	assert_true(presentation.rope_line.visible)
	assert_true(presentation.hook_indicator.visible)
	assert_eq(presentation.rope_line.points[1], Vector2(40.0, -40.0))
	assert_eq(presentation.hook_indicator.position, Vector2(40.0, -40.0))


func test_sand_burrow_visibility_is_presentation_only() -> void:
	var presentation := await _presentation()

	presentation.set_sand_burrow_visible(true)
	assert_true(presentation.sand_outline.visible)
	presentation.set_sand_burrow_visible(false)
	assert_false(presentation.sand_outline.visible)


func _presentation() -> PlayerPresentationController:
	var scene := load(
		"res://scenes/player/player_presentation.tscn"
	) as PackedScene
	var presentation := scene.instantiate() as PlayerPresentationController
	add_child_autofree(presentation)
	await wait_process_frames(1)
	return presentation
