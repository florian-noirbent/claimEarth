extends GutTest


const LIBRARY_PATH := "res://config/presentation/gameplay_effects.tres"
const STEP := 1.0 / 60.0
const HERE := Vector2(320.0, 640.0)


func test_every_feedback_moment_plays_without_a_camera() -> void:
	var feedback := _feedback()
	var item := ItemDefinition.new()
	var moments: Array[Callable] = [
		func() -> void: feedback.spawn_jump_dust(HERE, false),
		func() -> void: feedback.spawn_jump_dust(HERE, true),
		func() -> void: feedback.spawn_landing_dust(HERE, 600.0, 0.8),
		func() -> void: feedback.spawn_impact_flash(HERE, 800.0),
		func() -> void: feedback.spawn_knockout_stars(HERE, 1.0),
		func() -> void: feedback.spawn_hook_launch(HERE, HERE + Vector2(200.0, -100.0)),
		func() -> void: feedback.spawn_hook_spark(HERE, false),
		func() -> void: feedback.spawn_hook_spark(HERE, true),
		func() -> void: feedback.spawn_hook_miss(HERE),
		func() -> void: feedback.spawn_hook_release(HERE, true),
		func() -> void: feedback.spawn_hook_release(HERE, false),
		func() -> void: feedback.spawn_splash(HERE, Color.BLUE, 400.0, true),
		func() -> void: feedback.spawn_splash(HERE, Color.BLUE, 400.0, false),
		func() -> void: feedback.spawn_sand_burst(HERE, true),
		func() -> void: feedback.spawn_sand_burst(HERE, false),
		func() -> void: feedback.show_hazard_warning(HERE, DeathCause.ACID, 0.8, Color.GREEN),
		func() -> void: feedback.spawn_death(HERE, DeathCause.BOUNDS),
		func() -> void: feedback.spawn_throw(HERE, Vector2.RIGHT, item),
		func() -> void: feedback.spawn_tool_swing(HERE, Vector2.DOWN, item),
		func() -> void: feedback.spawn_bounce_spark(HERE, 500.0),
		func() -> void: feedback.spawn_projectile_end(HERE, item, &"fuse"),
		func() -> void: feedback.spawn_projectile_end(HERE, item, &"impact"),
		func() -> void: feedback.spawn_projectile_end(HERE, item, &"unknown_terrain_tag"),
		func() -> void: feedback.spawn_bottle_burst(HERE, Color.GREEN),
		func() -> void: feedback.spawn_explosion(HERE, Color.ORANGE, 80.0, false),
		func() -> void: feedback.spawn_explosion(HERE, Color.ORANGE, 160.0, true),
		func() -> void: feedback.spawn_fuse_warning(HERE, 0.3),
		func() -> void: feedback.spawn_fuse_warning(HERE, 0.0),
		func() -> void: feedback.spawn_object_debris(HERE, &"item_chest"),
		func() -> void: feedback.spawn_object_debris(HERE, &"unknown_object"),
		func() -> void: feedback.spawn_barrel_bump(HERE, 500.0),
		func() -> void: feedback.spawn_excavator_deploy(HERE),
		func() -> void: feedback.spawn_drill_debris(HERE, 0),
		func() -> void: feedback.spawn_drill_debris(HERE, 3),
		func() -> void: feedback.spawn_flag_planted(HERE),
		func() -> void: feedback.spawn_flag_destroyed(HERE, &"lava"),
		func() -> void: feedback.spawn_flag_destroyed(HERE, &"unknown_terrain_tag"),
		func() -> void: feedback.spawn_victory(HERE),
		func() -> void: feedback.spawn_chest_burst(HERE, &"item_chest"),
		func() -> void: feedback.spawn_chest_burst(HERE, &"perk_geode"),
		func() -> void: feedback.spawn_chest_burst(HERE, &"unknown_container"),
		func() -> void: feedback.spawn_reward_claimed(HERE, true),
		func() -> void: feedback.spawn_reward_claimed(HERE, false),
	]

	for index in moments.size():
		feedback.effects().clear()
		moments[index].call()
		assert_gt(feedback.effects().live_particle_count(), 0, "Moment %d shows an effect" % index)
		feedback.effects().advance(STEP)

	feedback.show_flag_flight(true)
	feedback.show_flag_flight(false)
	feedback.spawn_directional_pulse(HERE, Color.PURPLE, 24.0, 160.0, 0.5, 2.0)
	await wait_process_frames(2)
	assert_true(is_instance_valid(feedback))


func test_moments_do_nothing_without_an_effect_library() -> void:
	var feedback := GameplayFeedback.new()
	add_child_autofree(feedback)

	feedback.spawn_explosion(HERE, Color.ORANGE, 160.0, true)
	feedback.spawn_death(HERE, DeathCause.BOMB)
	feedback.spawn_flag_planted(HERE)

	assert_eq(feedback.effects().live_particle_count(), 0)
	assert_null(feedback.get_node_or_null("PlantedFlag"))


func test_footsteps_over_hex_steps_raise_no_landing_dust() -> void:
	var feedback := _feedback()

	for airborne_seconds: float in [0.03, 0.08, 0.15, 0.2]:
		feedback.spawn_landing_dust(HERE, 900.0, airborne_seconds)
	assert_eq(feedback.effects().live_particle_count(), 0, "Short hops are footsteps, however fast")

	feedback.spawn_landing_dust(HERE, 40.0, 1.0)
	assert_eq(feedback.effects().live_particle_count(), 0, "A slow touchdown raises nothing")

	feedback.spawn_landing_dust(HERE, 300.0, 0.5)
	var soft := feedback.effects().live_particle_count()
	feedback.effects().clear()
	feedback.spawn_landing_dust(HERE, 900.0, 0.5)
	var hard := feedback.effects().live_particle_count()

	assert_gt(soft, 0)
	assert_gt(hard, soft, "A harder landing raises more dust")


func test_speed_thresholds_filter_weak_moments() -> void:
	var feedback := _feedback()

	feedback.spawn_bounce_spark(HERE, 20.0)
	feedback.spawn_splash(HERE, Color.BLUE, 5.0, true)
	feedback.spawn_impact_flash(HERE, 50.0)
	feedback.spawn_barrel_bump(HERE, 30.0)

	assert_eq(feedback.effects().live_particle_count(), 0)


func test_barrel_bumps_are_rate_limited() -> void:
	var feedback := _feedback()

	feedback.spawn_barrel_bump(HERE, 600.0)
	var first := feedback.effects().live_particle_count()
	feedback.spawn_barrel_bump(HERE, 600.0)
	feedback.spawn_barrel_bump(HERE + Vector2(40.0, 0.0), 600.0)
	assert_gt(first, 0)
	assert_eq(feedback.effects().live_particle_count(), first, "Bumps inside the cooldown are skipped")

	feedback._process(_library().barrel_bump_cooldown_seconds + 0.01)
	feedback.spawn_barrel_bump(HERE, 600.0)
	assert_gt(feedback.effects().live_particle_count(), first)


func test_larger_explosions_ask_for_more_shake_up_to_the_cap() -> void:
	var feedback := _feedback()
	var library := _library()

	assert_almost_eq(feedback.explosion_shake_intensity(80.0), 80.0 * library.explosion_shake_per_radius, 0.0001)
	assert_gt(feedback.explosion_shake_intensity(160.0), feedback.explosion_shake_intensity(80.0))
	assert_eq(feedback.explosion_shake_intensity(100000.0), library.explosion_shake_max)


func test_shake_requests_reach_the_camera_with_their_position() -> void:
	var feedback := _feedback()
	var target := Node2D.new()
	add_child_autofree(target)
	var camera := DescendingCameraController.new()
	camera.target = target
	add_child_autofree(camera)
	feedback.set_camera(camera)

	feedback.spawn_explosion(Vector2(0.0, camera.shake_zero_distance + 10.0), Color.ORANGE, 160.0, true)
	assert_eq(camera.shake_trauma(), 0.0, "A blast beyond the shake range leaves the camera still")

	feedback.spawn_explosion(Vector2(camera.shake_full_distance * 3.0, 0.0), Color.ORANGE, 160.0, true)
	var distant := camera.shake_trauma()
	assert_gt(distant, 0.0)

	feedback.spawn_explosion(Vector2(40.0, 0.0), Color.ORANGE, 160.0, true)
	assert_gt(camera.shake_trauma(), distant, "Shakes accumulate and near blasts add more")

	feedback.set_camera(null)
	feedback.spawn_explosion(Vector2.ZERO, Color.ORANGE, 160.0, true)
	assert_true(is_instance_valid(feedback), "Shake without a camera is ignored")


func test_anchored_effects_follow_the_camera_target() -> void:
	var feedback := _feedback()
	var target := Node2D.new()
	add_child_autofree(target)
	var camera := DescendingCameraController.new()
	camera.target = target
	add_child_autofree(camera)
	feedback.set_camera(camera)
	target.global_position = Vector2(100.0, 50.0)

	feedback.spawn_knockout_stars(target.global_position, 2.0)
	target.global_position = Vector2(400.0, 90.0)
	feedback._process(STEP)

	var layer := feedback.effects().get_child(0) as EffectBatch
	assert_eq(layer._anchor_position, Vector2(400.0, 90.0))
	assert_eq(layer._position[0], _library().player_head_offset, "Anchored particles are stored relative to the target")


func test_flag_landing_leaves_one_planted_flag() -> void:
	var feedback := _feedback()

	feedback.spawn_flag_planted(HERE)
	var marker := feedback.get_node("PlantedFlag") as Sprite2D

	assert_eq(marker.texture, _library().flag_marker_texture)
	assert_eq(marker.global_position, HERE + _library().flag_marker_offset)

	feedback.show_flag_flight(false)
	assert_true(is_instance_valid(marker) and not marker.is_queued_for_deletion(), "The end of the flight keeps the flag")
	feedback.show_flag_flight(true)
	assert_true(marker.is_queued_for_deletion(), "A new throw removes the old flag")


func test_freeing_feedback_mid_effect_is_safe() -> void:
	var feedback := GameplayFeedback.new()
	var effects := WorldEffects.new()
	effects.name = GameplayFeedback.EFFECTS_NODE_NAME
	effects.library = _library()
	feedback.add_child(effects)
	add_child(feedback)
	feedback.spawn_explosion(HERE, Color.ORANGE, 160.0, true)
	feedback.spawn_victory(HERE)
	feedback.spawn_flag_planted(HERE)
	await wait_process_frames(2)

	feedback.queue_free()
	await wait_process_frames(2)

	assert_false(is_instance_valid(feedback))


func _library() -> GameplayEffectLibrary:
	return load(LIBRARY_PATH) as GameplayEffectLibrary


func _feedback() -> GameplayFeedback:
	var feedback := GameplayFeedback.new()
	var effects := WorldEffects.new()
	effects.name = GameplayFeedback.EFFECTS_NODE_NAME
	effects.library = _library()
	feedback.add_child(effects)
	add_child_autofree(feedback)
	effects.set_seed(5)
	return feedback
