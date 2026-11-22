extends GutTest
## Covers the death sequence on the real player scene: every cause plays to a settled end,
## the body comes apart and stays apart, the sequence drives itself, and the facts it reports.


const STEP := 1.0 / 60.0
const HEX := 16.0
const FLOOR_ROW := 14
const BEAT := 2.0
const CAUSES: Array[StringName] = [
	DeathCause.COOKED, DeathCause.SUFFOCATION, DeathCause.ACID, DeathCause.POISON,
	DeathCause.BOMB, DeathCause.IMPACT, DeathCause.BOUNDS,
]


func test_every_cause_plays_to_a_settled_end_with_every_part_loose_and_out_of_terrain() -> void:
	for cause in CAUSES:
		var player := await _player_in_room("Air")
		var animator := player.presentation.death
		watch_signals(player)

		player.begin_death(cause, BEAT, DeathContext.from_source(player.global_position + Vector2(-30.0, 10.0)))
		var steps := _play_out(animator)

		assert_false(animator.is_playing(), "%s finishes" % cause)
		assert_lte(steps * STEP, BEAT + 0.75, "%s is settled when the beat ends or just after" % cause)
		assert_eq(animator.detached_part_count(), 16, "%s frees every part" % cause)
		assert_true(animator.simulation().all_asleep())
		for gib in animator.simulation().count():
			assert_false(
				player._terrain_query.is_solid_at_world(animator.simulation().position_of(gib)),
				"%s leaves no part inside terrain" % cause
			)
			assert_lt(animator.simulation().position_of(gib).distance_to(player.global_position), 420.0, "%s keeps the parts near the body" % cause)
		assert_signal_emitted(player, "death_cue", "%s asks for world effects" % cause)
		assert_false(animator.is_physics_processing(), "A finished sequence stops stepping")


func test_the_body_is_whole_until_the_seam_and_never_whole_again_after_it() -> void:
	var player := await _player_in_room("Air")
	var rig := player.presentation.rig
	var animator := player.presentation.death
	await wait_physics_frames(3)

	assert_false(animator.has_begun())
	assert_false(animator.is_physics_processing(), "The animator idles while the player lives")
	assert_null(rig.part_sprite(0).material)
	assert_eq(rig.z_index, 0)
	var head := _part(rig, &"Head")
	var followed := rig.part_sprite(head).global_position
	assert_almost_eq(followed, (rig.get_node("%Head") as Node2D).global_position, Vector2(0.01, 0.01))

	player.begin_death(DeathCause.BOMB, BEAT)
	assert_true(animator.has_begun())
	assert_true(animator.is_playing())
	assert_eq(rig.z_index, rig.burrow_z_index, "The remains are drawn above terrain and liquids")
	assert_false(rig.z_as_relative)
	assert_not_null(rig.part_sprite(0).material)
	assert_eq(animator.detached_part_count(), 16, "A bomb bursts the body at once")
	_play_out(animator)

	var pieces := animator.sequence()
	assert_same(pieces, animator.library.sequences[DeathCause.BOMB])
	assert_gt(rig.part_sprite(head).global_position.distance_to(followed), 4.0)
	var apart := 0.0
	for part in rig.part_count():
		assert_true(rig.part_sprite(part).visible)
		assert_eq(rig.part_outline(part).global_position, rig.part_sprite(part).global_position, "The silhouette follows its part")
		apart = maxf(apart, rig.part_sprite(part).global_position.distance_to(rig.part_sprite(head).global_position))
	assert_gt(apart, 20.0, "The parts lie scattered")
	# A second call changes nothing: the seam runs once.
	player.begin_death(DeathCause.ACID, BEAT)
	assert_same(animator.sequence(), pieces)


func test_the_sequence_steps_itself_while_the_dead_player_no_longer_simulates() -> void:
	var player := await _player_in_room("Air")
	var animator := player.presentation.death

	player.begin_death(DeathCause.POISON, BEAT)
	var started := animator.progress()
	await wait_physics_frames(12)

	assert_false(player.is_physics_processing())
	assert_true(animator.is_physics_processing())
	assert_almost_eq(animator.progress() - started, 12.0 * STEP / BEAT, 3.0 * STEP / BEAT, "It advances one physics step at a time")
	assert_eq(player.presentation.rig.current_state(), animator.sequence().pose, "The whole body holds the sequence's pose")
	assert_eq(animator.detached_part_count(), 0, "Poison swells first and bursts later")


func test_a_suspended_sequence_holds_its_frame_and_goes_on_when_resumed() -> void:
	var player := await _player_in_room("Air")
	var animator := player.presentation.death
	player.begin_death(DeathCause.BOMB, BEAT)
	await wait_physics_frames(4)

	player.set_death_suspended(true)
	var held_progress := animator.progress()
	var held_position := animator.simulation().position_of(0)
	await wait_physics_frames(10)
	assert_eq(animator.progress(), held_progress)
	assert_eq(animator.simulation().position_of(0), held_position)
	assert_true(animator.is_playing(), "Suspended is not finished")

	player.set_death_suspended(false)
	await wait_physics_frames(4)
	assert_gt(animator.progress(), held_progress)
	assert_ne(animator.simulation().position_of(0), held_position)


func test_a_death_suspended_before_it_begins_starts_held() -> void:
	var player := await _player_in_room("Air")
	player.set_death_suspended(true)

	player.begin_death(DeathCause.BOMB, BEAT)
	await wait_physics_frames(5)

	assert_eq(player.presentation.death.progress(), 0.0)
	assert_false(player.presentation.death.is_physics_processing())


func test_a_zero_beat_plays_everything_at_once_without_errors() -> void:
	for cause in CAUSES:
		var player := await _player_in_room("Air")
		var animator := player.presentation.death
		watch_signals(player)

		player.begin_death(cause, 0.0)

		assert_eq(animator.progress(), 1.0)
		assert_eq(animator.detached_part_count(), 16, "%s frees every part at once" % cause)
		assert_signal_emitted(player, "death_cue")
		assert_lte(get_signal_emit_count(player, "death_cue"), 16 * animator.sequence().cues.size() + 16, "Repeats collapse into one play")
		_play_out(animator)
		assert_false(animator.is_playing())


func test_equal_deaths_play_out_identically() -> void:
	var finals: Array[PackedVector2Array] = []
	for _run in 2:
		var player := await _player_in_room("Air")
		var animator := player.presentation.death
		player.begin_death(DeathCause.IMPACT, BEAT, _floor_impact())
		for _step in 90:
			animator.advance(STEP)
		var positions := PackedVector2Array()
		for gib in animator.simulation().count():
			positions.append(animator.simulation().position_of(gib))
		finals.append(positions)

	assert_eq(finals[0].size(), 16)
	assert_eq(finals[0], finals[1])


func test_a_blast_throws_the_parts_away_from_it_and_a_fall_off_the_floor_it_hit() -> void:
	var player := await _player_in_room("Air")
	player.begin_death(DeathCause.BOMB, BEAT, DeathContext.from_source(player.global_position + Vector2(-40.0, 0.0)))
	var simulation := player.presentation.death.simulation()
	var mean := Vector2.ZERO
	for gib in simulation.count():
		mean += simulation.velocity_of(gib) / simulation.count()
	assert_gt(mean.x, 150.0, "The blast came from the left")

	var fallen := await _player_in_room("Air")
	fallen._handle_terrain_impact(fallen.movement_config.lethal_impact_speed, Vector2(0.0, -1100.0))
	fallen.velocity = Vector2.ZERO
	fallen.begin_death(DeathCause.IMPACT, BEAT)
	var animator := fallen.presentation.death
	assert_eq(animator.detached_part_count(), 0, "The body squashes before it bursts")
	for _step in 5:
		animator.advance(STEP)
	assert_lt(fallen.presentation.body_visual.transform.y.length(), 0.6, "It is pressed flat against the floor")
	for _step in 6:
		animator.advance(STEP)
	assert_eq(animator.detached_part_count(), 16)
	for gib in animator.simulation().count():
		assert_lt(animator.simulation().velocity_of(gib).y, 250.0, "No part is thrown down into the floor it hit")


func test_the_terrain_at_the_body_selects_the_steam_variant() -> void:
	var steamed := await _player_in_room("Steam")
	steamed.begin_death(DeathCause.COOKED, BEAT)
	var cooked := steamed.presentation.death.library.sequences[DeathCause.COOKED]
	assert_same(steamed.presentation.death.sequence(), cooked.variant_by_terrain_tag[&"steam"])

	var burnt := await _player_in_room("Lava")
	burnt.begin_death(DeathCause.COOKED, BEAT)
	assert_same(burnt.presentation.death.sequence(), cooked)


func test_parts_slow_down_in_liquid() -> void:
	var travelled := {}
	for fill: String in ["Air", "Lava"]:
		var player := await _player_in_room(fill)
		var animator := player.presentation.death
		animator.set_seed(7)
		player.begin_death(DeathCause.BOMB, BEAT, DeathContext.from_source(player.global_position + Vector2(0.0, 40.0)))
		for _step in 12:
			animator.advance(STEP)
		var total := 0.0
		for gib in animator.simulation().count():
			total += animator.simulation().position_of(gib).distance_to(player.global_position)
		travelled[fill] = total

	assert_lt(float(travelled["Lava"]), float(travelled["Air"]) * 0.8)


func test_the_rope_lets_go_and_falls_back() -> void:
	var player := await _player_in_room("Air")
	var grapple := player.presentation.grapple
	var anchor := player.global_position + Vector2(-120.0, -140.0)
	player.presentation.start_hook_launch(anchor)
	for _step in 12:
		player.presentation.update_grapple(true, anchor, STEP)
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.HOLDING)
	player._grapple_model.state.is_attached = true
	watch_signals(player)

	player.begin_death(DeathCause.BOMB, BEAT)

	assert_false(player.is_grapple_attached(), "The dead hand holds nothing")
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.RETRACTING)
	var animator := player.presentation.death
	var hook_start := grapple.hook.global_position
	for _step in 6:
		animator.advance(STEP)
	assert_true(grapple.rope_line.visible, "The rope is still falling")
	assert_gt(grapple.hook.global_position.distance_to(hook_start), 1.0)
	for _step in int(animator.library.rope_release_seconds / STEP) + 2:
		animator.advance(STEP)
	assert_eq(grapple.phase(), GrappleRopeVisual.Phase.STOWED)
	assert_false(grapple.rope_line.visible)
	assert_false(grapple.hook.visible)


func test_loose_parts_report_their_landings() -> void:
	var player := await _player_in_room("Air")
	watch_signals(player)
	player.begin_death(DeathCause.BOMB, BEAT, DeathContext.from_source(player.global_position + Vector2(0.0, -40.0)))

	_play_out(player.presentation.death)

	assert_signal_emitted(player, "gib_landed")
	var landing: Array = get_signal_parameters(player, "gib_landed")
	assert_eq(landing[0], player.presentation.death.sequence().splat_effect_key)
	assert_almost_eq((landing[2] as Vector2).length(), 1.0, 0.001, "The surface normal is a unit vector")
	assert_gte(float(landing[3]), player.presentation.death.sequence().splat_min_speed)
	assert_lte(get_signal_emit_count(player, "gib_landed"), 160, "Landings are rate-limited per part")


func test_freeing_the_player_mid_sequence_is_harmless() -> void:
	var player := await _player_in_room("Air")
	player.begin_death(DeathCause.BOMB, BEAT)
	await wait_physics_frames(3)

	player.queue_free()
	await wait_physics_frames(3)

	assert_false(is_instance_valid(player))


## Steps the sequence by hand until it stops; returns the steps it took.
func _play_out(animator: PlayerDeathAnimator) -> int:
	var steps := 0
	while animator.is_playing() and steps < 900:
		animator.advance(STEP)
		steps += 1
	return steps


func _floor_impact() -> DeathContext:
	var context := DeathContext.new()
	context.surface_normal = Vector2.UP
	return context


func _part(rig: PlayerRig, part_name: StringName) -> int:
	for part in rig.part_count():
		if rig.part_name(part) == part_name:
			return part
	return -1


## A player standing in a walled room filled with the given terrain above a stone floor.
func _player_in_room(fill_name: String) -> PlayerController:
	var fill := FixtureLoader.terrain_id(fill_name)
	var stone := FixtureLoader.terrain_id("Stone")
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(27, 18), fill)
	world.fill_committed(fill, registry.get_definition(fill).maximum_quantity)
	for row in world.dimensions.depth:
		for col in world.dimensions.width:
			if row >= FLOOR_ROW or col < 2 or col >= 25:
				world.set_committed_by_offset(col, row, stone)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	# The living player must not step before the death, or its pose would depend on timing.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(player)
	await wait_process_frames(1)
	player.set_physics_process(false)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.configure_environment(world, registry, HEX)
	var floor_center := HexMetrics.center_for_offset(13, FLOOR_ROW, HEX)
	player.global_position = Vector2(floor_center.x, floor_center.y - HEX - 15.0)
	player.velocity = Vector2.ZERO
	player.presentation.update_body(PlayerAnimationSnapshot.new(), STEP)
	return player
