extends GutTest

const STEP := 1.0 / 60.0


func test_ground_speed_selects_idle_walk_and_run() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _grounded(Vector2.ZERO)

	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.IDLE)

	snapshot.velocity.x = selector.walk_speed + 1.0
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.WALK)

	snapshot.velocity.x = -selector.run_speed
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.RUN)


func test_airborne_body_jumps_while_rising_and_falls_after() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _airborne(Vector2(0.0, -400.0))

	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.JUMP)

	snapshot.velocity.y = 50.0
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.FALL)


func test_brief_loss_of_footing_keeps_the_ground_state() -> void:
	var selector := PlayerAnimationSelector.new()
	selector.advance(_grounded(Vector2(280.0, 0.0)), 0.0, STEP)
	var stumble := _airborne(Vector2(280.0, 30.0))

	selector.advance(stumble, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.RUN)

	for _step in ceili(selector.air_grace_seconds / STEP) + 1:
		selector.advance(stumble, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.FALL)


func test_hard_landing_crouches_for_its_duration_and_soft_landing_does_not() -> void:
	var selector := PlayerAnimationSelector.new()
	selector.advance(_airborne(Vector2(0.0, selector.land_speed + 100.0)), 0.0, 0.2)
	var standing := _grounded(Vector2.ZERO)

	selector.advance(standing, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.LAND)
	selector.advance(standing, 0.0, selector.land_seconds * 0.5)
	assert_eq(selector.state, PlayerAnimationState.LAND)
	selector.advance(standing, 0.0, selector.land_seconds)
	assert_eq(selector.state, PlayerAnimationState.IDLE)

	selector.advance(_airborne(Vector2(0.0, selector.land_speed - 100.0)), 0.0, 0.2)
	selector.advance(standing, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.IDLE)


func test_jumping_out_of_a_landing_cancels_the_crouch() -> void:
	var selector := PlayerAnimationSelector.new()
	selector.advance(_airborne(Vector2(0.0, selector.land_speed + 100.0)), 0.0, 0.2)
	selector.advance(_grounded(Vector2.ZERO), 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.LAND)

	selector.advance(_airborne(Vector2(0.0, -400.0)), 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.JUMP)
	selector.advance(_airborne(Vector2(0.0, 10.0)), 0.0, STEP)
	selector.advance(_grounded(Vector2.ZERO), 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.IDLE)


func test_knocked_out_body_gets_up_through_the_landing_crouch() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _grounded(Vector2.ZERO)
	snapshot.ragdolling = true
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.RAGDOLL)

	snapshot.ragdolling = false
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.LAND)
	selector.advance(snapshot, 0.0, selector.land_seconds)
	assert_eq(selector.state, PlayerAnimationState.IDLE)

	var airborne := _airborne(Vector2(0.0, 100.0))
	airborne.ragdolling = true
	selector.advance(airborne, 0.0, STEP)
	airborne.ragdolling = false
	selector.advance(airborne, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.FALL, "Coming to in the air keeps falling")


func test_special_states_take_priority_in_order() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _airborne(Vector2(0.0, 100.0))
	snapshot.liquid_submersion = 1.0
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.SWIM)

	snapshot.swinging = true
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.HOOK_SWING)

	snapshot.sand_burrowing = true
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.BURROW)

	snapshot.ragdolling = true
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.state, PlayerAnimationState.RAGDOLL)


func test_grounded_body_walks_in_liquid_and_while_holding_the_rope() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _grounded(Vector2(60.0, 0.0))
	snapshot.liquid_submersion = 1.0
	snapshot.swinging = true

	selector.advance(snapshot, 0.0, STEP)

	assert_eq(selector.state, PlayerAnimationState.WALK)


func test_partial_submersion_below_the_threshold_does_not_swim() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _airborne(Vector2(0.0, 100.0))
	snapshot.liquid_submersion = selector.swim_submersion - 0.2

	selector.advance(snapshot, 0.0, 0.2)

	assert_eq(selector.state, PlayerAnimationState.FALL)


func test_facing_follows_velocity_then_the_hook_side_and_holds_otherwise() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _grounded(Vector2(-100.0, 0.0))

	selector.advance(snapshot, 1.0, STEP)
	assert_eq(selector.facing, -1.0, "Movement outranks the hook side")

	snapshot.velocity = Vector2.ZERO
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.facing, -1.0, "Standing still keeps the last facing")

	selector.advance(snapshot, 1.0, STEP)
	assert_eq(selector.facing, 1.0)


func test_swing_only_turns_at_speed_and_ragdoll_never_turns() -> void:
	var selector := PlayerAnimationSelector.new()
	var snapshot := _airborne(Vector2(-(selector.swing_turn_speed - 5.0), 0.0))
	snapshot.swinging = true

	selector.advance(snapshot, -1.0, STEP)
	assert_eq(selector.facing, 1.0)

	snapshot.velocity.x = -(selector.swing_turn_speed + 5.0)
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.facing, -1.0)

	snapshot.ragdolling = true
	snapshot.velocity.x = 500.0
	selector.advance(snapshot, 0.0, STEP)
	assert_eq(selector.facing, -1.0)


func test_every_animation_state_has_a_clip_and_cross_fades_to_every_other() -> void:
	var rig := (load("res://scenes/player/player_rig.tscn") as PackedScene).instantiate() as PlayerRig
	add_child_autofree(rig)
	var player := rig.get_node("AnimationPlayer") as AnimationPlayer
	var machine := rig.animation_tree.tree_root as AnimationNodeStateMachine

	for state in PlayerAnimationState.ALL:
		assert_true(player.has_animation(state), "Missing clip %s" % state)
		assert_true(machine.has_node(state), "Missing state %s" % state)
		for other in PlayerAnimationState.ALL:
			if other != state:
				assert_true(machine.has_transition(state, other), "Missing transition %s -> %s" % [state, other])


func _grounded(velocity: Vector2) -> PlayerAnimationSnapshot:
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.grounded = true
	snapshot.velocity = velocity
	return snapshot


func _airborne(velocity: Vector2) -> PlayerAnimationSnapshot:
	var snapshot := PlayerAnimationSnapshot.new()
	snapshot.velocity = velocity
	return snapshot
