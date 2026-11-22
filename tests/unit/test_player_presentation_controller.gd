extends GutTest


func test_rig_follows_movement_state_facing_and_ragdoll_spin() -> void:
	var presentation := await _presentation()
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.grounded = true
	snapshot.velocity = Vector2.LEFT * 280.0

	presentation.update_body(snapshot, 0.1)
	assert_eq(presentation.animation_state(), PlayerAnimationState.RUN)
	assert_eq(presentation.rig.current_state(), PlayerAnimationState.RUN)
	assert_lt(presentation.rig.scale.x, 0.0)
	assert_eq(presentation.body_visual.rotation, 0.0)

	snapshot.grounded = false
	snapshot.velocity = Vector2(120.0, -300.0)
	presentation.update_body(snapshot, 0.1)
	assert_eq(presentation.rig.current_state(), PlayerAnimationState.JUMP)
	assert_gt(presentation.rig.scale.x, 0.0)

	snapshot.ragdolling = true
	snapshot.ragdoll_spin_direction = -1.0
	snapshot.ragdoll_spin_speed = 8.0
	presentation.update_body(snapshot, 0.1)
	assert_eq(presentation.rig.current_state(), PlayerAnimationState.RAGDOLL)
	assert_almost_eq(presentation.body_visual.rotation, -0.8, 0.001)


func test_knocked_out_body_rolls_with_its_ground_speed_then_lies_flat_and_gets_up() -> void:
	var presentation := await _presentation()
	var step := 1.0 / 60.0
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.ragdolling = true
	snapshot.grounded = true
	snapshot.ragdoll_spin_direction = 1.0
	snapshot.ragdoll_spin_speed = 8.0
	snapshot.velocity = Vector2(presentation.ragdoll_roll_radius * 4.0, 0.0)

	for _step in 120:
		presentation.update_body(snapshot, step)
	var rolled := presentation.body_visual.rotation
	presentation.update_body(snapshot, step)
	assert_almost_eq(presentation.body_visual.rotation - rolled, 4.0 * step, 0.001, "Rolling turns with the distance covered")

	snapshot.velocity = Vector2.ZERO
	for _step in 120:
		presentation.update_body(snapshot, step)
	assert_almost_eq(absf(sin(presentation.body_visual.rotation)), 1.0, 0.001, "A resting body lies flat")
	assert_gt(presentation.body_visual.position.y, 1.0, "A lying body rests on the ground")
	var flat := presentation.body_visual.rotation
	presentation.update_body(snapshot, step)
	assert_almost_eq(presentation.body_visual.rotation, flat, 0.001, "A lying body stays put")

	snapshot.ragdolling = false
	presentation.update_body(snapshot, step)
	assert_eq(presentation.animation_state(), PlayerAnimationState.LAND)
	for _step in 120:
		presentation.update_body(snapshot, step)
	assert_almost_eq(wrapf(presentation.body_visual.rotation, -PI, PI), 0.0, 0.001)
	assert_almost_eq(presentation.body_visual.position.y, 0.0, 0.001)
	assert_eq(presentation.animation_state(), PlayerAnimationState.IDLE)


func test_knocked_out_limbs_hang_toward_the_ground_within_their_joints_then_recover() -> void:
	var presentation := await _presentation()
	var step := 1.0 / 60.0
	var rig := presentation.rig
	var upper_arm := rig.get_node("%UpperArm") as Node2D
	var shin := rig.get_node("%Shin") as Node2D
	var hand := rig.get_node("%Grip") as Node2D
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.ragdolling = true
	# No spin, so the body stays upright and only gravity acts on the limbs.
	snapshot.ragdoll_spin_speed = 0.0

	for _step in 240:
		presentation.update_body(snapshot, step)
	assert_eq(rig.limp_weight(), 1.0)
	var arm_direction := (hand.global_position - upper_arm.global_position).normalized()
	assert_gt(arm_direction.dot(Vector2.DOWN), 0.95, "A limp arm hangs straight down")

	# Falling fast trails the limbs upward, but a knee never bends backward.
	snapshot.velocity = Vector2(0.0, 3000.0)
	for _step in 240:
		presentation.update_body(snapshot, step)
	arm_direction = (hand.global_position - upper_arm.global_position).normalized()
	assert_lt(arm_direction.dot(Vector2.DOWN), 0.0, "Air drag lifts a limp arm")
	assert_gte(shin.rotation, -0.001)
	assert_lte(shin.rotation, deg_to_rad(140.0) + 0.001)

	snapshot.ragdolling = false
	snapshot.grounded = true
	snapshot.velocity = Vector2.ZERO
	for _step in 120:
		presentation.update_body(snapshot, step)
	assert_eq(rig.limp_weight(), 0.0)
	var animated := upper_arm.rotation
	rig.advance(0.0)
	assert_almost_eq(upper_arm.rotation, animated, 0.001, "Recovered limbs follow the animation alone")


func test_swinging_body_leans_along_the_rope_and_holds_it_on_the_center_line() -> void:
	var presentation := await _presentation()
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.swinging = true
	var anchor := presentation.global_position + Vector2(200.0, -200.0)

	for _step in 60:
		presentation.update_grapple(true, anchor, 1.0 / 60.0)
		presentation.update_body(snapshot, 1.0 / 60.0)

	assert_eq(presentation.rig.current_state(), PlayerAnimationState.HOOK_SWING)
	assert_almost_eq(presentation.body_visual.rotation, PI * 0.25 * presentation.swing_lean, 0.01)
	presentation.update_grapple(true, anchor, 1.0 / 60.0)
	var rope_start := presentation.to_local(presentation.rig.grip_position())
	assert_almost_eq(presentation.grapple.rope_grip_end().x, rope_start.x, 0.001)
	assert_almost_eq(presentation.grapple.rope_grip_end().y, rope_start.y, 0.001)
	assert_lt(_rope_bend(presentation.grapple), 0.05, "A settled rope under load is straight")
	assert_almost_eq(presentation.rig.to_local(presentation.rig.grip_position()).x, 0.0, 0.1)
	assert_lt(presentation.rig.to_local(presentation.rig.grip_position()).y, presentation.rig.to_local(presentation.rig.arm_aim.global_position).y, "The hand is above the shoulder")

	# Turning around mirrors the body about its center line, which must not move the rope.
	snapshot.velocity = Vector2(-200.0, 0.0)
	presentation.update_body(snapshot, 1.0 / 60.0)
	presentation.update_grapple(true, anchor, 1.0 / 60.0)
	assert_lt(presentation.rig.scale.x, 0.0)
	assert_lt(presentation.grapple.rope_grip_end().distance_to(rope_start), 0.25)


func test_standing_arms_reach_for_the_hook_anchor() -> void:
	var presentation := await _presentation()
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.grounded = true
	var anchor := presentation.global_position + Vector2(200.0, -200.0)

	for _step in 60:
		presentation.update_grapple(true, anchor, 1.0 / 60.0)
		presentation.update_body(snapshot, 1.0 / 60.0)
	presentation.update_grapple(true, anchor, 1.0 / 60.0)

	var shoulder := presentation.rig.arm_aim.global_position
	var arm_direction := (presentation.rig.grip_position() - shoulder).normalized()
	assert_gt(arm_direction.dot((anchor - shoulder).normalized()), 0.98)


func test_hook_target_turns_a_standing_body_toward_it() -> void:
	var presentation := await _presentation()
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.grounded = true

	presentation.update_grapple(true, presentation.global_position + Vector2(-80.0, -40.0), 0.1)
	presentation.update_body(snapshot, 0.1)

	assert_eq(presentation.rig.current_state(), PlayerAnimationState.IDLE)
	assert_lt(presentation.rig.scale.x, 0.0)


func test_hook_launch_flies_from_the_hand_then_a_miss_falls_back_and_hides() -> void:
	var presentation := await _presentation()
	var grapple := presentation.grapple
	presentation.global_position = Vector2(10.0, 20.0)
	presentation.hook_launch_animation_seconds = 0.1
	grapple.miss_retract_seconds = 0.2
	assert_false(grapple.rope_line.visible)
	assert_false(grapple.hook.visible)

	presentation.start_hook_launch(Vector2(210.0, 20.0))
	presentation.update_grapple(false, Vector2.ZERO, 0.05)

	assert_true(grapple.rope_line.visible)
	assert_true(grapple.hook.visible)
	var grip := presentation.to_local(presentation.rig.grip_position())
	var halfway := grip.lerp(Vector2(200.0, 0.0), 0.5)
	assert_almost_eq(grapple.hook.position.x, halfway.x, 0.001)
	assert_almost_eq(grapple.hook.position.y, halfway.y, 0.001)
	assert_almost_eq(grapple.rope_grip_end().x, grip.x, 0.001)
	assert_almost_eq(grapple.rope_grip_end().y, grip.y, 0.001)
	assert_lt(grapple.rope_claw_end().distance_to(grapple.hook.position), 12.0, "The rope runs into the claw")
	assert_gt(_rope_bend(grapple), 0.5, "A flying rope waves")

	# The hook reaches its full range, then falls back to the hand instead of vanishing.
	presentation.update_grapple(false, Vector2.ZERO, 0.05)
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.RETRACTING)
	assert_true(grapple.rope_line.visible)
	assert_almost_eq(grapple.hook.position.x, 200.0, 0.001)
	presentation.update_grapple(false, Vector2.ZERO, 0.1)
	assert_true(grapple.hook.visible)
	assert_lt(grapple.hook.position.x, 200.0)
	assert_gt(grapple.hook.position.x, grapple.rope_grip_end().x)
	assert_gt(_rope_bend(grapple), 0.5, "A returning rope is slack")

	presentation.update_grapple(false, Vector2.ZERO, 0.1)
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.STOWED)
	assert_false(grapple.rope_line.visible)
	assert_false(grapple.hook.visible)


func test_attached_grapple_bites_the_world_anchor_and_cancel_stops_launch() -> void:
	var presentation := await _presentation()
	var grapple := presentation.grapple
	presentation.global_position = Vector2(10.0, 20.0)
	presentation.hook_launch_animation_seconds = 1.0
	presentation.start_hook_launch(Vector2(110.0, 20.0))
	presentation.cancel_hook_launch()
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.STOWED)

	presentation.update_grapple(true, Vector2(210.0, -180.0), 0.1)

	assert_true(grapple.rope_line.visible)
	assert_true(grapple.hook.visible)
	assert_eq(grapple.hook.position, Vector2(200.0, -200.0))
	var grip := presentation.to_local(presentation.rig.grip_position())
	assert_almost_eq(grapple.rope_grip_end().x, grip.x, 0.001)
	assert_almost_eq(grapple.rope_grip_end().y, grip.y, 0.001)
	assert_lt(grapple.rope_claw_end().distance_to(Vector2(200.0, -200.0)), 12.0, "The rope runs into the claw")
	assert_almost_eq(grapple.hook.rotation, (Vector2(200.0, -200.0) - grip).angle(), 0.001, "The claw points along the rope")
	assert_almost_eq(grapple.upper_jaw.rotation, -grapple.jaw_open_angle, 0.001, "The jaws arrive open")

	# A moving anchor, such as a hooked barrel, carries the claw along.
	presentation.update_grapple(true, Vector2(180.0, -150.0), 0.1)
	assert_eq(grapple.hook.position, Vector2(170.0, -170.0))
	assert_gt(grapple.upper_jaw.rotation, -grapple.jaw_open_angle * 0.5, "The jaws snap shut on the anchor")
	for _step in 60:
		presentation.update_grapple(true, Vector2(180.0, -150.0), 1.0 / 60.0)
	assert_lt(_rope_bend(grapple), 0.05, "The bite shiver dies out")
	assert_almost_eq(grapple.upper_jaw.rotation, -grapple.jaw_closed_angle, 0.01)
	assert_almost_eq(grapple.hook.scale.x, 1.0, 0.01)


func test_released_hook_whips_back_to_the_hand_before_hiding() -> void:
	var presentation := await _presentation()
	var grapple := presentation.grapple
	grapple.release_retract_seconds = 0.2
	var anchor := presentation.global_position + Vector2(150.0, -100.0)
	for _step in 30:
		presentation.update_grapple(true, anchor, 1.0 / 60.0)

	presentation.cancel_hook_launch()
	presentation.update_grapple(false, Vector2.ZERO, 0.1)
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.RETRACTING)
	assert_true(grapple.rope_line.visible)
	assert_eq(grapple.hook.position, presentation.to_local(anchor), "The hook leaves from where it held on")

	presentation.update_grapple(false, Vector2.ZERO, 0.1)
	var grip := grapple.rope_grip_end()
	var remaining := grapple.hook.position.distance_to(grip)
	assert_gt(remaining, 1.0)
	assert_lt(remaining, presentation.to_local(anchor).distance_to(grip))
	assert_almost_eq(grapple.upper_jaw.rotation, -grapple.jaw_open_angle, 0.05, "The jaws let go")

	presentation.update_grapple(false, Vector2.ZERO, 0.1)
	assert_false(grapple.rope_line.visible)
	assert_false(grapple.hook.visible)

	# A hook released in flight returns from where it got to.
	presentation.hook_launch_animation_seconds = 1.0
	presentation.start_hook_launch(anchor)
	presentation.update_grapple(false, Vector2.ZERO, 0.5)
	presentation.cancel_hook_launch()
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.RETRACTING)
	presentation.update_grapple(false, Vector2.ZERO, 0.3)
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.STOWED)


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


## Greatest distance of a rope point from the straight line between the rope's ends.
func _rope_bend(grapple: GrappleRopeVisual) -> float:
	var points := grapple.rope_line.points
	var start := points[0]
	var direction := (points[points.size() - 1] - start).normalized()
	var bend := 0.0
	for point in points:
		bend = maxf(bend, absf(direction.cross(point - start)))
	return bend
