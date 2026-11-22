extends GutTest

const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")
const DeathCauseScript = preload("res://src/player/death_cause.gd")

const ANCHOR_POSITION := Vector2(64, -24)


class FakeAnchorQuery extends GrappleAnchorQuery:
	var valid := true

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return GrappleAnchor.new(Vector2i(1, 1), ANCHOR_POSITION)

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return valid


class FakeGrappleTarget extends GrappleTarget:
	func is_valid() -> bool:
		return true

	func anchor_position() -> Vector2:
		return ANCHOR_POSITION

	func radius() -> float:
		return 8.0

	func pull_toward(_point: Vector2, _overshoot: float, _delta: float) -> void:
		pass


class FakeTargetAnchorQuery extends GrappleAnchorQuery:
	var target := FakeGrappleTarget.new()

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return GrappleAnchor.new(Vector2i(-1, -1), ANCHOR_POSITION + Vector2.LEFT * 8.0, target)

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return true


class MissingAnchorQuery extends GrappleAnchorQuery:
	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return null

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return false


func after_each() -> void:
	for action in [InputActions.HOOK, InputActions.JUMP, InputActions.MOVE_RIGHT]:
		Input.action_release(action)


func test_hook_reports_launch_attach_and_input_release() -> void:
	var player := await _player_with_query(FakeAnchorQuery.new())
	watch_signals(player)

	ScenarioDriverScript.set_mouse_world_position(player, ANCHOR_POSITION)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(2)

	assert_signal_emit_count(player, "hook_launched", 1)
	assert_signal_emit_count(player, "hook_attached", 1)
	assert_eq(get_signal_parameters(player, "hook_attached"), [ANCHOR_POSITION, false])
	assert_signal_not_emitted(player, "hook_missed")
	assert_signal_not_emitted(player, "hook_released")

	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(2)

	assert_signal_emit_count(player, "hook_released", 1)
	assert_eq(get_signal_parameters(player, "hook_released"), [ANCHOR_POSITION, true])


func test_hook_on_a_moving_target_reports_the_target_anchor() -> void:
	var player := await _player_with_query(FakeTargetAnchorQuery.new())
	watch_signals(player)

	ScenarioDriverScript.set_mouse_world_position(player, ANCHOR_POSITION)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(2)

	assert_eq(get_signal_parameters(player, "hook_attached"), [ANCHOR_POSITION, true])


func test_hook_without_an_anchor_reports_a_miss_at_full_range() -> void:
	var player := await _player_with_query(MissingAnchorQuery.new())
	watch_signals(player)

	ScenarioDriverScript.set_mouse_world_position(player, player.global_position + Vector2(10.0, 0.0))
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(2)

	assert_signal_emit_count(player, "hook_launched", 1)
	assert_signal_emit_count(player, "hook_missed", 1)
	assert_signal_not_emitted(player, "hook_attached")
	var missed: Array = get_signal_parameters(player, "hook_missed")
	assert_almost_eq(
		(missed[1] as Vector2).distance_to(missed[0] as Vector2),
		player.grapple_config.effective_attach_range(),
		0.01
	)


func test_lost_anchor_reports_a_release_that_was_not_input() -> void:
	var query := FakeAnchorQuery.new()
	var player := await _player_with_query(query)
	ScenarioDriverScript.set_mouse_world_position(player, ANCHOR_POSITION)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(2)
	watch_signals(player)

	query.valid = false
	await wait_physics_frames(2)

	assert_signal_emit_count(player, "hook_released", 1)
	assert_eq(get_signal_parameters(player, "hook_released"), [ANCHOR_POSITION, false])


func test_knockout_impact_reports_hard_impact_and_knockout_with_speed() -> void:
	var player := await _player_with_query(null)
	player.set_physics_process(false)
	var impact_speed := player.movement_config.medium_impact_speed
	watch_signals(player)

	player._handle_terrain_impact(player.movement_config.impact_hazard_minimum_speed * 0.5)
	assert_signal_not_emitted(player, "hard_impact")
	player._handle_terrain_impact(impact_speed)

	assert_eq(get_signal_parameters(player, "hard_impact"), [player.global_position, impact_speed])
	assert_eq(
		get_signal_parameters(player, "knocked_out"),
		[player.global_position, impact_speed, player.movement_config.ragdoll_seconds]
	)


func test_lethal_impact_reports_hard_impact_without_knockout() -> void:
	var player := await _player_with_query(null)
	player.set_physics_process(false)
	watch_signals(player)

	player._handle_terrain_impact(player.movement_config.lethal_impact_speed)

	assert_signal_emit_count(player, "hard_impact", 1)
	assert_signal_not_emitted(player, "knocked_out")
	assert_signal_emitted_with_parameters(player, "death_requested", [DeathCauseScript.IMPACT])


func test_jump_and_landing_are_reported_once_each() -> void:
	var player := await _player_on_floor()
	watch_signals(player)
	await wait_physics_frames(10)
	assert_signal_not_emitted(player, "landed", "Standing still must not report landings")

	Input.action_press(InputActions.JUMP)
	await wait_physics_frames(2)
	Input.action_release(InputActions.JUMP)

	assert_signal_emit_count(player, "jumped", 1)
	assert_eq(get_signal_parameters(player, "jumped")[1], false)
	await wait_until(func() -> bool: return get_signal_emit_count(player, "landed") > 0, 3.0)
	assert_signal_emit_count(player, "landed", 1)
	var landing: Array = get_signal_parameters(player, "landed")
	assert_gt(float(landing[1]), 50.0, "A full jump lands with real downward speed")
	assert_gt(float(landing[2]), 0.3, "A full jump reports its time in the air")
	assert_signal_emit_count(player, "jumped", 1)


func test_entering_and_leaving_liquid_reports_the_liquid_color() -> void:
	var player := await _player_with_query(null)
	player.set_physics_process(false)
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var cell := Vector2i(3, 3)
	player.global_position = HexMetrics.center_for_offset(cell.x, cell.y, 16.0)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.velocity = Vector2(0.0, 120.0)
	var water_color := FixtureLoader.terrain_definition_named("Water").debug_color
	watch_signals(player)

	player._report_medium_changes()
	assert_signal_not_emitted(player, "liquid_entered")
	world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Water"), 127)
	player._report_medium_changes()
	player._report_medium_changes()

	assert_signal_emit_count(player, "liquid_entered", 1)
	assert_eq(get_signal_parameters(player, "liquid_entered"), [player.global_position, water_color, 120.0])
	world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Air"), WorldGrid.AIR_QUANTITY)
	player._report_medium_changes()

	assert_signal_emit_count(player, "liquid_exited", 1)
	assert_eq(get_signal_parameters(player, "liquid_exited"), [player.global_position, water_color, 120.0])


func test_sand_worm_burrow_changes_are_reported() -> void:
	var player := await _player_with_query(null)
	player.set_physics_process(false)
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var cell := Vector2i(3, 3)
	world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Sand"), 127)
	player.global_position = HexMetrics.center_for_offset(cell.x, cell.y, 16.0)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	watch_signals(player)

	player._report_medium_changes()
	assert_signal_not_emitted(player, "sand_burrow_changed", "Sand only counts for a Sand Worm player")
	var builder := PerkModifierBuilder.new()
	var effect := PerkModifierEffect.new()
	effect.domain = PerkModifierEffect.Domain.TERRAIN
	effect.modifier_key = "player_sand_passable"
	effect.operation = PerkModifierEffect.Operation.SET
	effect.value = 1.0
	effect.apply(builder)
	player.set_perk_modifiers(builder.build())
	player._report_medium_changes()

	assert_eq(get_signal_parameters(player, "sand_burrow_changed"), [player.global_position, true])
	world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Air"), WorldGrid.AIR_QUANTITY)
	player._report_medium_changes()
	assert_eq(get_signal_parameters(player, "sand_burrow_changed"), [player.global_position, false])
	assert_signal_emit_count(player, "sand_burrow_changed", 2)


func test_filling_hazard_meter_warns_at_the_level_and_repeats_at_the_interval() -> void:
	var player := await _player_with_query(null)
	player.set_physics_process(false)
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Lava"))
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.hazard_warning_level = 0.5
	player.hazard_warning_repeat_seconds = 0.04
	watch_signals(player)
	var warned_levels: Array[float] = []
	player.hazard_warning.connect(func(cause: StringName, level: float, _color: Color) -> void:
		if cause == DeathCauseScript.COOKED:
			warned_levels.append(level)
	)

	var elapsed := 0.0
	while get_signal_emit_count(player, "death_requested") == 0 and elapsed < 30.0:
		player._sample_environment(0.01)
		elapsed += 0.01

	assert_gt(warned_levels.size(), 1, "The warning repeats while the meter keeps filling")
	assert_gte(warned_levels[0], 0.5)
	assert_lt(warned_levels[0], 0.6, "The first warning fires as the meter crosses the level")
	var cooked_seconds := elapsed * (1.0 - warned_levels[0])
	assert_lte(warned_levels.size(), ceili(cooked_seconds / 0.04) + 1, "Warnings are rate-limited")


func _player_with_query(query: GrappleAnchorQuery) -> PlayerController:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	if query != null:
		player.configure_grapple_anchor_query(query)
	add_child_autofree(player)
	await wait_process_frames(1)
	return player


func _player_on_floor() -> PlayerController:
	var player := await _player_with_query(null)
	var world := WorldGrid.new(WorldDimensions.new(30, 12), FixtureLoader.terrain_id("Air"))
	for row in [8, 9, 10, 11]:
		for col in 30:
			world.set_committed_by_offset(col, row, FixtureLoader.terrain_id("Stone"), 127)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.global_position = HexMetrics.center_for_offset(4, 6, 16.0)
	player.velocity = Vector2.ZERO
	await wait_until(func() -> bool: return player._is_grounded_for_movement(), 3.0)
	await wait_physics_frames(5)
	return player


func test_running_over_hex_steps_reports_only_short_airborne_landings() -> void:
	var player := await _player_on_floor()
	var airborne: Array[float] = []
	player.landed.connect(func(_position: Vector2, _speed: float, airborne_seconds: float) -> void:
		airborne.append(airborne_seconds)
	)

	Input.action_press(InputActions.MOVE_RIGHT)
	await wait_physics_frames(60)
	Input.action_release(InputActions.MOVE_RIGHT)

	for airborne_seconds in airborne:
		assert_lt(airborne_seconds, 0.2, "A hex step is told apart from a jump by its air time")
