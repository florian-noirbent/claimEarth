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
		func() -> void: feedback.spawn_gib_splat(&"blood_splat", HERE, Vector2.UP, 500.0),
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

	# Every effect a death sequence can ask for by key.
	for key: StringName in (load(LIBRARY_PATH) as GameplayEffectLibrary).death_cue_by_key:
		feedback.effects().clear()
		feedback.spawn_death_cue(key, HERE, Vector2.RIGHT, 1.0)
		assert_gt(feedback.effects().live_particle_count(), 0, "Death cue %s shows an effect" % key)
	feedback.effects().clear()
	feedback.spawn_death_cue(&"no_such_cue", HERE, Vector2.RIGHT, 1.0)
	feedback.spawn_gib_splat(&"no_such_cue", HERE, Vector2.UP, 900.0)
	feedback.spawn_gib_splat(&"blood_splat", HERE, Vector2.UP, 20.0)
	assert_eq(feedback.effects().live_particle_count(), 0, "Unknown cues and soft landings show nothing")

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


func test_every_thrown_catalog_item_with_an_attached_effect_has_valid_tuning() -> void:
	var library := _library()
	assert_eq(library.validate(), PackedStringArray())
	for key: StringName in [&"small_bomb", &"large_bomb", &"flare", &"flag", &"fluid_bottle"]:
		assert_true(library.projectile_effect_by_key.has(key), String(key))
	var broken := AttachedEffect.new()
	assert_gt(broken.validate().size(), 0, "An attached effect needs a recipe")


func test_attached_effect_plays_at_the_attach_point_until_the_projectile_is_freed() -> void:
	var feedback := _feedback()
	var projectile := _projectile("small_bomb")
	var effect: AttachedEffect = _library().projectile_effect_by_key[&"small_bomb"]
	projectile.velocity = Vector2(-200.0, 0.0)
	projectile.advance_body(STEP)

	feedback.show_projectile_effect(projectile, _item("small_bomb"))
	assert_eq(feedback.attached_effect_count(), 1)
	assert_eq(feedback.effects().live_particle_count(), 0, "The first play waits for the next frame")
	feedback._process(STEP)

	var fuse_tip := projectile.visual_point(effect.attach_offset)
	assert_lt(fuse_tip.x, projectile.global_position.x, "The fuse tip leads a mirrored left throw")
	assert_lt(fuse_tip.y, projectile.global_position.y)
	var first := feedback.effects().live_particle_count()
	assert_eq(first, effect.recipe.emitters.size())
	for layer: EffectBatch in feedback.effects().get_children():
		for slot in layer.used_count():
			assert_almost_eq(layer._position[slot], fuse_tip, Vector2(0.001, 0.001))

	feedback._process(effect.interval_seconds * 0.4)
	assert_eq(feedback.effects().live_particle_count(), first, "Plays are spaced by the interval")
	feedback._process(effect.interval_seconds)
	assert_gt(feedback.effects().live_particle_count(), first)

	projectile.queue_free()
	var before_end := feedback.effects().live_particle_count()
	feedback._process(effect.interval_seconds * 2.0)
	assert_eq(feedback.attached_effect_count(), 0, "A resolved projectile drops its effect at once")
	assert_eq(feedback.effects().live_particle_count(), before_end)
	await wait_process_frames(2)
	feedback._process(1.0)
	assert_false(is_instance_valid(projectile), "The effect never keeps the projectile alive")


func test_attached_effect_survives_a_projectile_freed_without_notice() -> void:
	var feedback := _feedback()
	var projectile := _projectile("flare")
	feedback.show_projectile_effect(projectile, _item("flare"))
	feedback.show_projectile_effect(null, _item("flare"))
	feedback.show_projectile_effect(_projectile("flare"), null)
	feedback.show_projectile_effect(_projectile("pickaxe"), _item("pickaxe"))
	assert_eq(feedback.attached_effect_count(), 1, "Only a live projectile of an item with an entry carries an effect")

	projectile.free()
	feedback._process(STEP)

	assert_eq(feedback.attached_effect_count(), 0)
	assert_eq(feedback.effects().live_particle_count(), 0)


func test_attached_effects_stay_inside_the_particle_budget() -> void:
	var feedback := _feedback()
	var item := _item("small_bomb")
	for index in 40:
		var projectile := _projectile("small_bomb")
		projectile.global_position = Vector2(index * 30.0, 0.0)
		feedback.show_projectile_effect(projectile, item)

	for _frame in 240:
		feedback._process(STEP)
		feedback.effects().advance(STEP)

	assert_lte(feedback.effects().live_particle_count(), feedback.effects().particle_capacity())
	assert_eq(feedback.get_child_count(), 1, "Attached effects add no nodes")


func test_suspended_session_freezes_effects_attached_effects_and_shake_until_it_resumes() -> void:
	var feedback := _feedback()
	var camera := _camera()
	feedback.set_camera(camera)
	var projectile := _projectile("flare")
	feedback.show_projectile_effect(projectile, _item("flare"))
	feedback.spawn_knockout_stars(HERE, 3.0)
	feedback.spawn_explosion(Vector2(40.0, 0.0), Color.ORANGE, 160.0, true)
	await wait_process_frames(3)
	var layer := feedback.effects().get_child(1) as EffectBatch

	feedback.set_active(false)
	assert_true(feedback.is_suspended())
	await wait_process_frames(1)
	var particles := feedback.effects().live_particle_count()
	var ages := layer._age.duplicate()
	var positions := layer._position.duplicate()
	var trauma := camera.shake_trauma()
	var camera_position := camera.global_position
	var camera_rotation := camera.global_rotation
	assert_gt(trauma, 0.0)
	assert_ne(camera_position, Vector2.ZERO, "The view is displaced by the shake")
	await wait_process_frames(12)

	assert_eq(feedback.effects().live_particle_count(), particles, "No particle ends and no attached effect plays")
	assert_eq(layer._age, ages)
	assert_eq(layer._position, positions)
	assert_eq(camera.shake_trauma(), trauma)
	assert_eq(camera.global_position, camera_position, "The shaken view holds still")
	assert_eq(camera.global_rotation, camera_rotation)

	feedback.set_active(true)
	assert_false(feedback.is_suspended())
	await wait_process_frames(6)

	assert_ne(layer._age, ages, "Effects go on from where they stopped")
	assert_lt(camera.shake_trauma(), trauma)
	assert_gt(camera.shake_trauma(), 0.0, "The shake decays on instead of restarting or snapping back")


func test_run_ending_moments_keep_feedback_running_while_the_session_is_inactive() -> void:
	var moments: Array[Callable] = [
		func(feedback: GameplayFeedback) -> void: feedback.spawn_death(HERE, DeathCause.BOMB),
		func(feedback: GameplayFeedback) -> void: feedback.spawn_flag_planted(HERE),
		func(feedback: GameplayFeedback) -> void: feedback.spawn_flag_destroyed(HERE, &"lava"),
	]
	for moment in moments:
		var feedback := _feedback()
		var camera := _camera()
		feedback.set_camera(camera)
		feedback.set_active(false)
		assert_true(feedback.is_suspended())

		moment.call(feedback)
		feedback.request_shake(12.0, Vector2.ZERO)
		var trauma := camera.shake_trauma()
		var layer := feedback.effects().get_child(1) as EffectBatch
		var ages := layer._age.duplicate()
		feedback.set_active(false)
		await wait_process_frames(4)

		assert_false(feedback.is_suspended(), "The run is over; its last effects play out")
		assert_ne(layer._age, ages)
		assert_lt(camera.shake_trauma(), trauma)


func test_camera_handed_over_while_suspended_is_suspended_too() -> void:
	var feedback := _feedback()
	var camera := _camera()
	feedback.set_active(false)

	feedback.set_camera(camera)
	camera.apply_shake(12.0)
	var trauma := camera.shake_trauma()
	await wait_process_frames(3)
	assert_eq(camera.shake_trauma(), trauma)

	feedback.set_camera(null)
	await wait_process_frames(3)
	assert_lt(camera.shake_trauma(), trauma, "A camera that is handed back shakes on by itself")


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


func _item(item_name: String) -> ItemDefinition:
	return load("res://config/items/%s.tres" % item_name) as ItemDefinition


func _camera() -> DescendingCameraController:
	var target := Node2D.new()
	add_child_autofree(target)
	var camera := DescendingCameraController.new()
	camera.target = target
	add_child_autofree(camera)
	return camera


## A projectile showing the named item's icon the way a throw configures it.
func _projectile(item_name: String) -> ItemProjectile:
	var item := _item(item_name)
	var projectile := ItemProjectile.new()
	projectile.configure({
		"gravity": 0.0,
		"fuse_seconds": 60.0,
		"visual_texture": item.icon,
		"visual_scale": 0.3,
		"visual_mirror_with_heading": true,
	})
	projectile.global_position = HERE
	add_child_autofree(projectile)
	projectile.set_physics_process(false)
	return projectile
