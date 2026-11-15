extends GutTest


const HEX_RADIUS := 16.0
const STEP := 1.0 / 60.0

var _air_id := 0
var _stone_id := 0


func before_all() -> void:
	_air_id = FixtureLoader.terrain_id("Air")
	_stone_id = FixtureLoader.terrain_id("Stone")


func test_barrel_falls_and_comes_to_rest_on_terrain_at_any_frame_rate() -> void:
	var rest_positions: Array[Vector2] = []
	for step_seconds: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0]:
		var barrel := await _configured_barrel(_world_with_floor(9), Vector2i(5, 2))
		var start := barrel.global_position
		_step_until_resting(barrel, step_seconds)

		assert_true(barrel.is_resting(), "The barrel must come to rest at %.4f s steps" % step_seconds)
		assert_true(barrel.is_grounded())
		assert_eq(barrel.velocity, Vector2.ZERO)
		assert_false(barrel.is_sleeping(), "An untracked barrel never sleeps")
		assert_gt(barrel.global_position.y, start.y + 64.0)
		assert_false(barrel._terrain_query.circle_overlaps_solid(barrel.global_position, barrel.body_radius() - 0.5))
		assert_false(barrel.explosive.is_consumed(), "A short drop must not detonate the barrel")
		rest_positions.append(barrel.global_position)
	for position in rest_positions:
		assert_almost_eq(position.x, rest_positions[1].x, 1.0)
		assert_almost_eq(position.y, rest_positions[1].y, 1.0)


func test_resting_barrel_without_sleep_rechecks_terrain_on_the_grounded_interval() -> void:
	var world := _world_with_floor(9)
	var barrel := await _configured_barrel(world, Vector2i(5, 2))
	_step_until_resting(barrel, STEP)
	var rest_position := barrel.global_position

	_remove_floor(world, 9)
	barrel._physics_process(STEP)
	assert_eq(barrel.global_position, rest_position, "Between checks a resting barrel does not move")
	for _step in ceili(barrel.barrel_definition().grounded_check_interval_seconds / STEP) + 1:
		barrel._physics_process(STEP)
	assert_false(barrel.is_resting())
	assert_gt(barrel.global_position.y, rest_position.y)


func test_barrel_rolls_off_a_ledge_instead_of_resting_on_its_corner() -> void:
	var world := WorldGrid.new(WorldDimensions.new(20, 24), _air_id)
	for col in range(0, 6):
		world.set_committed_by_offset(col, 9, _stone_id)
	for col in range(20):
		world.set_committed_by_offset(col, 14, _stone_id)
	var barrel := await _configured_barrel(world, Vector2i(5, 7))
	barrel.global_position.x = HexMetrics.center_for_offset(5, 7, HEX_RADIUS).x + HEX_RADIUS * 0.9

	_step_until_resting(barrel, STEP)

	assert_true(barrel.is_resting())
	assert_false(barrel.explosive.is_consumed())
	assert_gt(barrel.global_position.y, HexMetrics.center_for_offset(5, 11, HEX_RADIUS).y)


func test_sleep_enabled_barrel_stops_physics_steps_and_wakes_on_watched_terrain_change() -> void:
	var world := _world_with_floor(9)
	var barrel := await _configured_barrel(world, Vector2i(5, 2))
	barrel.set_sleep_enabled(true)
	_step_until_resting(barrel, STEP)

	assert_true(barrel.is_sleeping())
	assert_false(barrel.is_physics_processing())
	world.set_committed_light_by_offset(5, 9, 200)
	assert_false(barrel.sleep_state().wake_if_terrain_changed(), "Light changes must not wake a resting barrel")

	_remove_floor(world, 9)
	assert_true(barrel.sleep_state().wake_if_terrain_changed())
	assert_false(barrel.is_sleeping())
	assert_true(barrel.is_physics_processing())
	var rest_position := barrel.global_position
	barrel._physics_process(STEP)
	assert_gt(barrel.global_position.y, rest_position.y)


func test_blast_impulse_wakes_a_sleeping_barrel_only_inside_the_radius() -> void:
	var barrel := await _sleeping_barrel(_world_with_floor(9))
	barrel.apply_blast_impulse(barrel.global_position + Vector2(400.0, 0.0), 1000.0, 100.0)
	assert_true(barrel.is_sleeping())

	barrel.apply_blast_impulse(barrel.global_position + Vector2(40.0, 0.0), 1000.0, 100.0)
	assert_false(barrel.is_sleeping())
	assert_true(barrel.is_physics_processing())
	assert_lt(barrel.velocity.x, 0.0)


func test_overlapping_body_pushes_barrel_out_horizontally_with_capped_velocity() -> void:
	var barrel := await _sleeping_barrel(_world_with_floor(9))
	var definition := barrel.barrel_definition()
	var player_radius := 14.0
	var rest_position := barrel.global_position
	var far_player := rest_position + Vector2(-(player_radius + barrel.body_radius() + 1.0), 0.0)

	assert_false(barrel.push_from(far_player, player_radius, Vector2(200.0, 0.0)))
	assert_true(barrel.is_sleeping())
	assert_eq(barrel.global_position, rest_position)

	var player_position := rest_position + Vector2(-20.0, 4.0)
	assert_true(barrel.push_from(player_position, player_radius, Vector2(200.0, 0.0)))
	assert_false(barrel.is_sleeping())
	assert_true(barrel.is_physics_processing())
	assert_gt(barrel.global_position.x, rest_position.x + 4.0, "A push moves the barrel away from the body")
	assert_almost_eq(barrel.global_position.y, rest_position.y, HEX_RADIUS * 0.5, "Pushing rides over floor bumps")
	assert_false(barrel._terrain_query.circle_overlaps_solid(barrel.global_position, barrel.body_radius() - 0.5))
	assert_almost_eq(barrel.velocity.x, 200.0 * definition.push_velocity_ratio, 0.001)

	player_position = barrel.global_position + Vector2(-20.0, 0.0)
	assert_true(barrel.push_from(player_position, player_radius, Vector2(2000.0, 0.0)))
	assert_eq(barrel.velocity.x, definition.max_push_speed)

	player_position = barrel.global_position + Vector2(-20.0, 0.0)
	assert_true(barrel.push_from(player_position, player_radius, Vector2(-50.0, 0.0)))
	assert_eq(barrel.velocity.x, definition.max_push_speed, "A slower or opposite body never brakes the barrel")


func test_push_stops_the_barrel_at_a_wall() -> void:
	var world := _world_with_floor(9)
	for row in range(0, 9):
		world.set_committed_by_offset(7, row, _stone_id)
	var barrel := await _sleeping_barrel(world)
	var player_position := barrel.global_position + Vector2(-20.0, 0.0)

	assert_true(barrel.push_from(player_position, 14.0, Vector2(100.0, 0.0)))

	assert_false(barrel._terrain_query.circle_overlaps_solid(barrel.global_position, barrel.body_radius()))
	assert_lt(barrel.global_position.x, HexMetrics.center_for_offset(7, 5, HEX_RADIUS).x)


func test_grapple_target_adapter_follows_and_pulls_the_barrel() -> void:
	var barrel := await _sleeping_barrel(_world_with_floor(9))
	var definition := barrel.barrel_definition()
	var target := barrel.grapple_target()

	assert_same(barrel.grapple_target(), target)
	assert_true(target.is_valid())
	assert_eq(target.anchor_position(), barrel.global_position)
	assert_eq(target.radius(), barrel.body_radius())

	var point := barrel.global_position + Vector2(0.0, -400.0)
	target.pull_toward(point, 0.0, STEP)
	assert_true(barrel.is_sleeping(), "A slack rope does not pull")

	target.pull_toward(point, 10.0, STEP)
	assert_false(barrel.is_sleeping())
	assert_almost_eq(barrel.velocity.y, -definition.hook_pull_acceleration * STEP, 0.001)
	for _step in 120:
		target.pull_toward(point, 10.0, STEP)
	assert_almost_eq(barrel.velocity.length(), definition.max_hook_pull_speed, 0.001)

	barrel.global_position += Vector2(10.0, -30.0)
	assert_eq(target.anchor_position(), barrel.global_position)


func test_grapple_target_becomes_invalid_once_the_barrel_detonates_or_is_freed() -> void:
	var detonated := await _configured_barrel(_world_with_floor(9), Vector2i(5, 2))
	var detonated_target := detonated.grapple_target()
	assert_true(detonated.explosive.request_immediate_detonation())
	assert_false(detonated_target.is_valid())
	detonated_target.pull_toward(detonated.global_position + Vector2(0.0, -100.0), 10.0, STEP)
	assert_eq(detonated.velocity, Vector2.ZERO)

	var freed := await _configured_barrel(_world_with_floor(9), Vector2i(5, 2))
	var freed_target := freed.grapple_target()
	freed.free()
	assert_false(freed_target.is_valid())
	assert_eq(freed_target.radius(), 0.0)


func test_lava_or_acid_touching_the_body_detonates_the_barrel() -> void:
	for terrain_name in ["Lava", "Sulfuric Acid"]:
		var world := _world_with_floor(9)
		var barrel := await _configured_barrel(world, Vector2i(5, 2))
		watch_signals(barrel.explosive)
		var rim := barrel.global_position + Vector2(barrel.body_radius() - 1.0, 0.0)
		var cell := HexMetrics.offset_for_world(rim, HEX_RADIUS)
		var terrain := FixtureLoader.terrain_registry().get_definition(FixtureLoader.terrain_id(terrain_name))
		world.set_committed_by_offset(cell.x, cell.y, terrain.stable_id, terrain.maximum_quantity)

		barrel._physics_process(STEP)

		assert_signal_emit_count(barrel.explosive, "detonation_requested", 1, terrain_name)
		assert_true(barrel.explosive.is_consumed())


func test_water_touching_the_body_does_not_detonate_the_barrel() -> void:
	var world := _world_with_floor(9)
	var barrel := await _configured_barrel(world, Vector2i(5, 2))
	var water := FixtureLoader.terrain_registry().get_definition(FixtureLoader.terrain_id("Water"))
	var cell := HexMetrics.offset_for_world(barrel.global_position, HEX_RADIUS)
	world.set_committed_by_offset(cell.x, cell.y, water.stable_id, water.maximum_quantity)

	barrel._physics_process(STEP)

	assert_false(barrel.explosive.is_consumed())


func test_lava_reaching_a_sleeping_barrel_detonates_it_within_the_check_interval() -> void:
	var world := _world_with_floor(9)
	var barrel := await _configured_barrel(world, Vector2i(5, 2))
	var scheduler := WorldBodySleepScheduler.new()
	scheduler.track(barrel.sleep_state())
	_step_until_resting(barrel, STEP)
	assert_true(barrel.is_sleeping())
	var view := Rect2(barrel.global_position - Vector2(320.0, 180.0), Vector2(640.0, 360.0))
	scheduler.advance(0.2, view)
	watch_signals(barrel.explosive)

	# Simulated fluid replaces committed Air without a change notification.
	var lava := FixtureLoader.terrain_registry().get_definition(FixtureLoader.terrain_id("Lava"))
	var cell := HexMetrics.offset_for_world(barrel.global_position, HEX_RADIUS)
	world.set_committed_by_offset(cell.x, cell.y, lava.stable_id, lava.maximum_quantity)
	var elapsed := 0.0
	while elapsed <= barrel.barrel_definition().grounded_check_interval_seconds + STEP and not barrel.explosive.is_consumed():
		scheduler.advance(STEP, view)
		if barrel.is_physics_processing():
			barrel._physics_process(STEP)
		elapsed += STEP

	assert_true(barrel.explosive.is_consumed())
	assert_signal_emit_count(barrel.explosive, "detonation_requested", 1)


func test_barrel_in_non_air_fluid_rests_without_sleeping() -> void:
	var world := _world_with_floor(9)
	var water := FixtureLoader.terrain_registry().get_definition(FixtureLoader.terrain_id("Water"))
	for row in range(4, 9):
		for col in range(12):
			world.set_committed_by_offset(col, row, water.stable_id, water.maximum_quantity)
	var barrel := await _configured_barrel(world, Vector2i(5, 2))
	barrel.set_sleep_enabled(true)
	_step_until_resting(barrel, STEP)

	assert_true(barrel.is_resting())
	assert_false(barrel.is_sleeping(), "Fluid replacing fluid is invisible to the watch, so the barrel keeps polling")


func test_high_speed_impact_detonates_the_barrel() -> void:
	var world := WorldGrid.new(WorldDimensions.new(12, 60), _air_id)
	for col in range(12):
		world.set_committed_by_offset(col, 58, _stone_id)
	var barrel := await _configured_barrel(world, Vector2i(5, 2))
	watch_signals(barrel.explosive)

	for _step in 600:
		if barrel.explosive.is_consumed():
			break
		barrel._physics_process(STEP)

	assert_signal_emit_count(barrel.explosive, "detonation_requested", 1)
	assert_gt(barrel.global_position.y, HexMetrics.center_for_offset(5, 50, HEX_RADIUS).y)


func test_barrel_explosive_opts_in_to_blast_radius_arming_from_its_definition() -> void:
	var barrel := await _configured_barrel(_world_with_floor(9), Vector2i(5, 2))
	assert_true(barrel.explosive.arms_in_blast_radius())

	var definition := barrel.barrel_definition().duplicate() as ExplosiveBarrelDefinition
	definition.detonates_in_blast_radius = false
	var opted_out := await _configured_barrel(_world_with_floor(9), Vector2i(5, 2), definition)
	assert_false(opted_out.explosive.arms_in_blast_radius())


func test_inactive_barrel_freezes_physics_fuse_push_and_pull() -> void:
	var barrel := await _configured_barrel(_world_with_floor(9), Vector2i(5, 2))
	assert_true(barrel.is_physics_processing())
	assert_true(barrel.explosive.try_arm_from_blast(barrel.global_position, 1, HEX_RADIUS))
	assert_true(barrel.explosive.is_physics_processing())

	barrel.set_active(false)
	assert_false(barrel.is_physics_processing())
	assert_false(barrel.explosive.is_physics_processing())
	var position := barrel.global_position
	barrel._physics_process(STEP)
	assert_eq(barrel.global_position, position)
	assert_false(barrel.push_from(position + Vector2(-10.0, 0.0), 14.0, Vector2(200.0, 0.0)))
	barrel.pull_toward(position + Vector2(0.0, -100.0), 10.0, STEP)
	assert_eq(barrel.velocity, Vector2.ZERO)

	barrel.set_active(true)
	assert_true(barrel.is_physics_processing())
	assert_true(barrel.explosive.is_physics_processing())


func test_preview_barrel_never_runs_physics() -> void:
	var barrel := (load("res://scenes/objects/explosive_barrel.tscn") as PackedScene).instantiate() as ExplosiveBarrel
	add_child_autofree(barrel)
	await wait_process_frames(1)
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	barrel.configure(GeneratedExplosiveBarrelSpawn.new(Vector2i(5, 2), definition, 1), HEX_RADIUS, false)

	barrel.set_active(true)
	assert_false(barrel.is_physics_processing())
	assert_false(barrel.push_from(barrel.global_position, 14.0, Vector2(100.0, 0.0)))


func _configured_barrel(
	world: WorldGrid,
	anchor: Vector2i,
	definition: ExplosiveBarrelDefinition = null
) -> ExplosiveBarrel:
	var barrel := (load("res://scenes/objects/explosive_barrel.tscn") as PackedScene).instantiate() as ExplosiveBarrel
	add_child_autofree(barrel)
	await wait_process_frames(1)
	if definition == null:
		definition = load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	barrel.configure(
		GeneratedExplosiveBarrelSpawn.new(anchor, definition, 1),
		HEX_RADIUS,
		true,
		null,
		world,
		FixtureLoader.terrain_registry()
	)
	return barrel


func _sleeping_barrel(world: WorldGrid) -> ExplosiveBarrel:
	var barrel := await _configured_barrel(world, Vector2i(5, 2))
	barrel.set_sleep_enabled(true)
	_step_until_resting(barrel, STEP)
	assert_true(barrel.is_sleeping())
	return barrel


func _world_with_floor(row: int) -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(12, 20), _air_id)
	for col in range(12):
		world.set_committed_by_offset(col, row, _stone_id)
	for col in range(12):
		world.set_committed_by_offset(col, 19, _stone_id)
	return world


func _remove_floor(world: WorldGrid, row: int) -> void:
	for col in range(12):
		world.set_committed_by_offset(col, row, _air_id)


func _step_until_resting(barrel: ExplosiveBarrel, step_seconds: float, maximum_seconds: float = 10.0) -> void:
	for _step in ceili(maximum_seconds / step_seconds):
		if barrel.is_resting() or barrel.explosive.is_consumed():
			return
		barrel._physics_process(step_seconds)
