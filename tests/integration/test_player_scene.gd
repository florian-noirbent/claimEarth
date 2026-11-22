extends GutTest

const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")
## Height of one hex row at the test hex radius of 16.
const HEX_ROW := 16.0 * sqrt(3.0)

class FakeAnchorQuery extends GrappleAnchorQuery:
	var anchor := GrappleAnchor.new(Vector2i(1, 1), Vector2(64, -24))

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return anchor

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return true


class FakeGrappleTarget extends GrappleTarget:
	var valid := true
	var center := Vector2(64, -24)
	var pulls: Array[Dictionary] = []

	func is_valid() -> bool:
		return valid

	func anchor_position() -> Vector2:
		return center

	func radius() -> float:
		return 8.0

	func pull_toward(point: Vector2, overshoot: float, delta: float) -> void:
		pulls.append({"point": point, "overshoot": overshoot, "delta": delta})


class FakeTargetAnchorQuery extends GrappleAnchorQuery:
	var target := FakeGrappleTarget.new()

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return GrappleAnchor.new(Vector2i(-1, -1), target.center + Vector2.LEFT * target.radius(), target)

	func is_anchor_valid(anchor: GrappleAnchor) -> bool:
		return anchor != null and anchor.target != null and anchor.target.is_valid()


class RecordingInputController extends GameplayInputController:
	var attached_flags: Array[bool] = []

	func sample_player_input(player_position: Vector2, grapple_attached: bool) -> GrappleInputFrame:
		attached_flags.append(grapple_attached)
		return super.sample_player_input(player_position, grapple_attached)


class MissingAnchorQuery extends GrappleAnchorQuery:
	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return null

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return false


func test_player_scene_loads_with_camera_and_visual() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	assert_not_null(player.camera)
	assert_not_null(player.world_light_source)
	assert_eq(player.world_light_source.definition.update_mode, WorldLightSourceDefinition.UpdateMode.HIGH_FREQUENCY)
	assert_eq(player.world_light_source.definition.light_level, 190)
	assert_eq(player.world_light_source.definition.update_radius, 18)
	assert_not_null(player.presentation)
	assert_not_null(player.presentation.rig)
	assert_gt(player.movement_config.impact_hazard_minimum_speed, 0.0)
	assert_lt(player.movement_config.impact_hazard_minimum_speed, player.movement_config.medium_impact_speed)
	assert_gt(player.movement_config.medium_impact_speed, 0.0)
	assert_gt(player.movement_config.lethal_impact_speed, player.movement_config.medium_impact_speed)
	assert_almost_eq(player.movement_config.impact_hazard_recovery_seconds, 5.0, 0.001)
	assert_gt(player.movement_config.terminal_velocity, player.movement_config.lethal_impact_speed, "A long fall can kill on its own")
	assert_not_null(player.movement_config.impact_hazard_icon)


func test_medium_terrain_impact_ragdolls_and_suppresses_control_for_tuned_duration() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)
	player.velocity = Vector2(100.0, 620.0)
	player._movement_model.velocity = player.velocity

	player._handle_terrain_impact(player.movement_config.medium_impact_speed)

	assert_true(player.is_ragdolling())
	assert_almost_eq(player.ragdoll_remaining(), 1.0, 0.001)
	var impact_status: HazardStatus = player._environment_status.statuses()[0]
	assert_almost_eq(impact_status.level, impact_status.secondary_threshold, 0.001)
	assert_true(impact_status.lethal_end)
	Input.action_press(InputActions.MOVE_RIGHT)
	player._physics_process(0.1)
	Input.action_release(InputActions.MOVE_RIGHT)
	assert_true(player.is_ragdolling())
	assert_almost_eq(player.velocity.x, 100.0, 0.001)
	player._advance_ragdoll(0.9)
	assert_false(player.is_ragdolling())


func test_high_terrain_impact_requests_impact_death_without_ragdoll() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)
	watch_signals(player)

	player._handle_terrain_impact(player.movement_config.lethal_impact_speed)

	assert_signal_emitted_with_parameters(player, "death_requested", [DeathCause.IMPACT])
	assert_false(player.is_ragdolling())
	assert_almost_eq(player._environment_status.level_for(DeathCause.IMPACT), 1.0, 0.001)


func test_consecutive_impacts_accumulate_into_knockout_and_death() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var knockout_player := scene.instantiate() as PlayerController
	add_child_autofree(knockout_player)
	await wait_process_frames(1)
	watch_signals(knockout_player)

	var config := knockout_player.movement_config
	var span := config.lethal_impact_speed - config.impact_hazard_minimum_speed
	var knockout_level := (config.medium_impact_speed - config.impact_hazard_minimum_speed) / span
	# Each hit alone stays under the knockout mark; two together pass it.
	var light_hit := config.impact_hazard_minimum_speed + span * knockout_level * 0.6
	knockout_player._handle_terrain_impact(light_hit)
	assert_false(knockout_player.is_ragdolling())
	assert_almost_eq(knockout_player._environment_status.level_for(DeathCause.IMPACT), knockout_level * 0.6, 0.001)
	knockout_player._handle_terrain_impact(light_hit)
	assert_true(knockout_player.is_ragdolling())
	assert_signal_not_emitted(knockout_player, "death_requested")

	var lethal_player := scene.instantiate() as PlayerController
	add_child_autofree(lethal_player)
	await wait_process_frames(1)
	watch_signals(lethal_player)
	var heavy_hit := config.impact_hazard_minimum_speed + span * 0.5
	lethal_player._handle_terrain_impact(heavy_hit)
	assert_signal_not_emitted(lethal_player, "death_requested")
	lethal_player._handle_terrain_impact(heavy_hit)
	assert_signal_emitted_with_parameters(lethal_player, "death_requested", [DeathCause.IMPACT])


func test_a_short_free_fall_is_harmless() -> void:
	var player := await _player_above_floor(5.0)
	watch_signals(player)

	_fall_until_landed(player)

	assert_signal_not_emitted(player, "hard_impact", "Five rows leave the impact meter alone")
	assert_true(player._environment_status.statuses().is_empty())
	assert_false(player.is_ragdolling())


func test_a_free_fall_past_the_safe_height_hurts_without_a_knockout() -> void:
	var player := await _player_above_floor(8.0)
	watch_signals(player)

	_fall_until_landed(player)

	assert_signal_emitted(player, "hard_impact")
	assert_gt(player._environment_status.level_for(DeathCause.IMPACT), 0.0)
	assert_false(player.is_ragdolling())
	assert_signal_not_emitted(player, "death_requested")


func test_a_medium_free_fall_knocks_out_and_a_second_one_soon_after_kills() -> void:
	var player := await _player_above_floor(12.0)
	watch_signals(player)

	_fall_until_landed(player)

	assert_true(player.is_ragdolling(), "Twelve rows knock out")
	assert_signal_not_emitted(player, "death_requested")
	assert_gt(player._environment_status.level_for(DeathCause.IMPACT), 0.5, "The meter is left more than half full")

	# Ten rows alone only knock out; on top of the first fall they kill.
	player.global_position.y -= 10.0 * HEX_ROW
	player.velocity = Vector2.ZERO
	player._movement_model.velocity = Vector2.ZERO
	player._grounded = false
	_fall_until_landed(player)

	assert_signal_emitted_with_parameters(player, "death_requested", [DeathCause.IMPACT])

	var fresh := await _player_above_floor(10.0)
	watch_signals(fresh)
	_fall_until_landed(fresh)
	assert_true(fresh.is_ragdolling())
	assert_signal_not_emitted(fresh, "death_requested")


func test_a_long_free_fall_kills_on_its_own() -> void:
	var survivor := await _player_above_floor(13.0)
	watch_signals(survivor)
	_fall_until_landed(survivor)
	assert_signal_not_emitted(survivor, "death_requested", "Thirteen rows are still survivable")
	assert_true(survivor.is_ragdolling())

	var player := await _player_above_floor(15.0)
	watch_signals(player)
	_fall_until_landed(player)

	assert_signal_emitted_with_parameters(player, "death_requested", [DeathCause.IMPACT])
	assert_almost_eq(player._lethal_impact.surface_normal, Vector2.UP, Vector2(0.05, 0.05), "The death knows the floor it hit")
	assert_gt(player._lethal_impact.velocity.y, player.movement_config.lethal_impact_speed)


func test_impact_hazard_starts_only_above_its_configured_safe_speed() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	player._handle_terrain_impact(player.movement_config.impact_hazard_minimum_speed)
	assert_true(player._environment_status.statuses().is_empty())
	player._handle_terrain_impact(player.movement_config.impact_hazard_minimum_speed + 1.0)
	assert_eq(player._environment_status.statuses().size(), 1)
	assert_gt(player._environment_status.level_for(DeathCause.IMPACT), 0.0)
	assert_false(player.is_ragdolling())


func test_full_fluid_drag_damps_both_velocity_axes_by_viscosity() -> void:
	var initial_velocity := Vector2(120.0, -80.0)
	var water_player := await _player_in_uniform_terrain("Water")
	water_player.velocity = initial_velocity
	water_player._apply_fluid_drag(1.0)
	var expected_water := initial_velocity * exp(-0.8)
	assert_almost_eq(water_player.velocity.x, expected_water.x, 0.001)
	assert_almost_eq(water_player.velocity.y, expected_water.y, 0.001)

	var lava_player := await _player_in_uniform_terrain("Lava")
	lava_player.velocity = initial_velocity
	lava_player._apply_fluid_drag(1.0)
	var expected_lava := initial_velocity * exp(-4.0)
	assert_almost_eq(lava_player.velocity.x, expected_lava.x, 0.001)
	assert_almost_eq(lava_player.velocity.y, expected_lava.y, 0.001)
	assert_lt(lava_player.velocity.length(), water_player.velocity.length())


func test_fluid_drag_is_frame_rate_independent_and_does_not_create_impact() -> void:
	var single_step_player := await _player_in_uniform_terrain("Water")
	var split_step_player := await _player_in_uniform_terrain("Water")
	var initial_velocity := Vector2(900.0, 300.0)
	single_step_player.velocity = initial_velocity
	split_step_player.velocity = initial_velocity

	single_step_player._apply_fluid_drag(1.0)
	for _step in 10:
		split_step_player._apply_fluid_drag(0.1)

	assert_almost_eq(single_step_player.velocity.x, split_step_player.velocity.x, 0.001)
	assert_almost_eq(single_step_player.velocity.y, split_step_player.velocity.y, 0.001)
	single_step_player._handle_physics_impacts(
		TerrainBodyMotionResult.new(),
		TerrainBodyMotionResult.new(),
		TerrainBodyUnstuckResult.new()
	)
	assert_almost_eq(single_step_player._environment_status.level_for(DeathCause.IMPACT), 0.0, 0.001)


func test_player_fluid_drag_averages_partial_fill_and_mixed_body_samples() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0) + Vector2(0.0, 10.0)
	var sample_counts := {}
	for sample_position in player._occupied_sample_positions():
		var cell := HexMetrics.offset_for_world(sample_position, 16.0)
		sample_counts[cell] = int(sample_counts.get(cell, 0)) + 1
	assert_eq(sample_counts.size(), 2)
	var sampled_cells := sample_counts.keys()
	var water_cell := sampled_cells[0] as Vector2i
	var lava_cell := sampled_cells[1] as Vector2i
	world.set_committed_by_offset(water_cell.x, water_cell.y, FixtureLoader.terrain_id("Water"), 64)
	world.set_committed_by_offset(lava_cell.x, lava_cell.y, FixtureLoader.terrain_id("Lava"), 127)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	var expected := (
		float(sample_counts[water_cell]) * 0.8 * 64.0 / 127.0
		+ float(sample_counts[lava_cell]) * 4.0
	) / 3.0

	assert_almost_eq(player._average_body_fluid_viscosity(), expected, 0.001)


func test_player_hook_attaches_adjusts_rope_and_releases_with_input() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.configure_grapple_anchor_query(FakeAnchorQuery.new())
	add_child_autofree(player)
	await wait_process_frames(1)

	ScenarioDriverScript.set_mouse_world_position(player, Vector2(64, -24))
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)

	assert_true(player.is_grapple_attached())
	var start_rope_length := player.current_rope_length()

	Input.action_press(InputActions.ROPE_UP)
	await wait_physics_frames(3)
	Input.action_release(InputActions.ROPE_UP)
	assert_lt(player.current_rope_length(), start_rope_length)

	Input.action_press(InputActions.MOVE_RIGHT)
	await wait_physics_frames(3)
	Input.action_release(InputActions.MOVE_RIGHT)
	assert_gt(player.velocity.x, 0.0)

	await wait_physics_frames(1)
	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)
	assert_false(player.is_grapple_attached())


func test_glass_disables_free_air_control_but_preserves_attached_swing_control() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.configure_grapple_anchor_query(FakeAnchorQuery.new())
	add_child_autofree(player)
	await wait_process_frames(1)
	var base_air_acceleration := player.movement_config.air_acceleration
	player.set_perk_modifiers(_perk_modifiers(["res://config/perks/glass_cannon.tres"]))

	assert_eq(player.movement_config.air_acceleration, base_air_acceleration)
	Input.action_press(InputActions.MOVE_RIGHT)
	player._physics_process(0.1)
	Input.action_release(InputActions.MOVE_RIGHT)
	assert_almost_eq(player.velocity.x, 0.0, 0.001)

	player.velocity = Vector2.ZERO
	player._movement_model.velocity = Vector2.ZERO
	ScenarioDriverScript.set_mouse_world_position(player, Vector2(64, -24))
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)
	assert_true(player.is_grapple_attached())

	Input.action_press(InputActions.MOVE_RIGHT)
	await wait_physics_frames(3)
	Input.action_release(InputActions.MOVE_RIGHT)
	assert_gt(player.velocity.x, 0.0)

	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)


func test_glass_preserves_ground_control() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)
	player.set_perk_modifiers(_perk_modifiers(["res://config/perks/glass_cannon.tres"]))
	player._grounded = true
	player.velocity = Vector2.ZERO
	player._movement_model.velocity = Vector2.ZERO

	Input.action_press(InputActions.MOVE_RIGHT)
	player._physics_process(0.1)
	Input.action_release(InputActions.MOVE_RIGHT)

	assert_gt(player.velocity.x, 0.0)


func test_acrobat_and_glass_preserve_attached_swing_control() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.configure_grapple_anchor_query(FakeAnchorQuery.new())
	add_child_autofree(player)
	await wait_process_frames(1)
	player.set_perk_modifiers(_perk_modifiers([
		"res://config/perks/acrobat.tres",
		"res://config/perks/glass_cannon.tres",
	]))
	ScenarioDriverScript.set_mouse_world_position(player, Vector2(64, -24))
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)
	assert_true(player.is_grapple_attached())

	Input.action_press(InputActions.MOVE_RIGHT)
	await wait_physics_frames(3)
	Input.action_release(InputActions.MOVE_RIGHT)

	assert_gt(player.velocity.x, 0.0)
	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)


func test_hooked_target_is_pulled_while_player_falls_unconstrained() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	var query := FakeTargetAnchorQuery.new()
	var input_controller := RecordingInputController.new()
	player.configure_grapple_anchor_query(query)
	player.configure_input_controller(input_controller)
	add_child_autofree(player)
	add_child_autofree(input_controller)
	await wait_process_frames(1)
	_place_player_in_open_air(player)
	query.target.center = player.global_position + Vector2(64, -24)

	ScenarioDriverScript.set_mouse_world_position(player, query.target.center)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)
	assert_true(player.is_grapple_attached())
	assert_true(player.is_grapple_target_attached())
	var rope_length := player.current_rope_length()

	await wait_physics_frames(30)

	var rope_distance := player.global_position.distance_to(query.target.center)
	assert_gt(rope_distance, rope_length + 10.0, "The rope never holds the player back from a target")
	assert_gt(player.velocity.y, 0.0, "The player keeps falling under ordinary gravity")
	assert_false(query.target.pulls.is_empty())
	var last_pull: Dictionary = query.target.pulls.back()
	assert_almost_eq(
		float(last_pull["overshoot"]),
		(last_pull["point"] as Vector2).distance_to(query.target.center) - rope_length,
		0.001
	)
	assert_false(input_controller.attached_flags.has(true), "Touch input keeps jump controls while holding a target")

	query.target.center += Vector2(30, 10)
	await wait_physics_frames(1)

	assert_eq(player.current_grapple_anchor_position(), query.target.center)
	assert_true(player.presentation.grapple.rope_line.visible)
	var expected_hook_point := player.presentation.to_local(query.target.center)
	assert_almost_eq(player.presentation.grapple.hook.position.x, expected_hook_point.x, 0.001)
	assert_almost_eq(player.presentation.grapple.hook.position.y, expected_hook_point.y, 0.001)

	query.target.valid = false
	await wait_physics_frames(1)
	assert_false(player.is_grapple_attached())
	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)


func test_glass_keeps_free_air_control_disabled_while_holding_a_target() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	var query := FakeTargetAnchorQuery.new()
	player.configure_grapple_anchor_query(query)
	add_child_autofree(player)
	await wait_process_frames(1)
	_place_player_in_open_air(player)
	query.target.center = player.global_position + Vector2(64, -24)
	player.set_perk_modifiers(_perk_modifiers(["res://config/perks/glass_cannon.tres"]))
	ScenarioDriverScript.set_mouse_world_position(player, query.target.center)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)
	assert_true(player.is_grapple_target_attached())

	Input.action_press(InputActions.MOVE_RIGHT)
	await wait_physics_frames(3)
	Input.action_release(InputActions.MOVE_RIGHT)

	assert_almost_eq(player.velocity.x, 0.0, 0.001)
	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)


func _place_player_in_open_air(player: PlayerController) -> void:
	var world := WorldGrid.new(WorldDimensions.new(40, 60), FixtureLoader.terrain_id("Air"))
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.set_spawn_position(HexMetrics.center_for_offset(20, 12, 16.0))
	player.velocity = Vector2.ZERO
	player._movement_model.velocity = Vector2.ZERO


func test_player_hook_launch_animation_plays_without_anchor() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.configure_grapple_anchor_query(MissingAnchorQuery.new())
	add_child_autofree(player)
	await wait_process_frames(1)
	player.presentation.hook_launch_animation_seconds = 0.1

	ScenarioDriverScript.set_mouse_world_position(player, Vector2.RIGHT * 10000.0)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)

	assert_false(player.is_grapple_attached())
	assert_true(player.presentation.grapple.rope_line.visible)
	assert_true(player.presentation.grapple.hook.visible)
	assert_gt(player.presentation.grapple.hook.position.length(), 0.0)
	assert_lt(player.presentation.grapple.hook.position.length(), player.grapple_config.effective_attach_range())

	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)


func test_player_hook_launch_animation_uses_full_range_for_close_cursor() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.configure_grapple_anchor_query(MissingAnchorQuery.new())
	add_child_autofree(player)
	await wait_process_frames(1)
	player.presentation.hook_launch_animation_seconds = 0.1

	ScenarioDriverScript.set_mouse_world_position(player, Vector2.RIGHT * 20.0)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)

	assert_true(player.presentation.grapple.rope_line.visible)
	assert_gt(player.presentation.grapple.hook.position.length(), 20.0)

	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)


func test_player_unstuck_push_moves_gradually_toward_nearest_air() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.terrain_unstuck_push_speed = 40.0
	player.terrain_unstuck_search_ring = 3
	add_child_autofree(player)
	await wait_process_frames(1)

	var world := WorldGrid.new(WorldDimensions.new(7, 5), FixtureLoader.terrain_id("Stone"))
	var air_hex := HexCoord.from_offset_odd_q(4, 2)
	_set_air_hex_radius(world, air_hex, 1)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.global_position = HexMetrics.center_for_offset(2, 2, 16.0)
	player.velocity = Vector2(-20.0, 30.0)
	var start_position := player.global_position
	var air_center := HexMetrics.center_for_offset(4, 2, 16.0)

	var result := player._apply_terrain_unstuck(0.1)

	assert_gt(player.global_position.distance_to(air_center), 0.0)
	assert_lt(player.global_position.distance_to(air_center), start_position.distance_to(air_center))
	assert_almost_eq(player.global_position.distance_to(start_position), 4.0, 0.001)
	assert_eq(player.velocity.x, 0.0)
	assert_eq(player.velocity.y, 30.0)
	assert_eq(result.velocity_change, Vector2(20.0, 0.0))


func test_player_unstuck_continues_until_clear_of_one_row_pit() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.terrain_unstuck_push_speed = 0.5
	add_child_autofree(player)
	await wait_process_frames(1)
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var pit_cell := Vector2i(3, 3)
	var pit_hex := HexCoord.from_offset_odd_q(pit_cell.x, pit_cell.y)
	for direction in [0, 4, 5]:
		var wall := pit_hex.neighbor(direction).to_offset_odd_q()
		world.set_committed_by_offset(wall.x, wall.y, FixtureLoader.terrain_id("Stone"))
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.global_position = HexMetrics.center_for_offset(pit_cell.x, pit_cell.y, 16.0)
	var start_y := player.global_position.y

	var first := player._apply_terrain_unstuck(0.1)
	var second := player._apply_terrain_unstuck(0.1)

	assert_true(first.moved)
	assert_true(second.moved)
	assert_lt(player.global_position.y, start_y)
	for _step in 20:
		if not player._terrain_query.circle_overlaps_solid(player.global_position, player.horizontal_collision_radius):
			break
		player._apply_terrain_unstuck(0.1)
	assert_false(player._terrain_query.circle_overlaps_solid(player.global_position, player.horizontal_collision_radius))


func test_solid_sand_unstuck_velocity_change_triggers_knockout_and_death() -> void:
	var medium_player := await _player_embedded_in_sand(128, Vector2.ZERO)
	medium_player.velocity.y = medium_player.movement_config.medium_impact_speed
	var medium_result := medium_player._apply_terrain_unstuck(0.1)
	medium_player._handle_physics_impacts(
		TerrainBodyMotionResult.new(),
		TerrainBodyMotionResult.new(),
		medium_result
	)

	assert_almost_eq(
		medium_result.velocity_change.length(),
		medium_player.movement_config.medium_impact_speed,
		0.001
	)
	assert_true(medium_player.is_ragdolling())

	var lethal_player := await _player_embedded_in_sand(128, Vector2.ZERO)
	lethal_player.velocity.y = lethal_player.movement_config.lethal_impact_speed
	watch_signals(lethal_player)
	var lethal_result := lethal_player._apply_terrain_unstuck(0.1)
	lethal_player._handle_physics_impacts(
		TerrainBodyMotionResult.new(),
		TerrainBodyMotionResult.new(),
		lethal_result
	)

	assert_almost_eq(
		lethal_result.velocity_change.length(),
		lethal_player.movement_config.lethal_impact_speed,
		0.001
	)
	assert_signal_emitted_with_parameters(lethal_player, "death_requested", [DeathCause.IMPACT])


func test_subthreshold_and_position_only_unstuck_are_harmless() -> void:
	var slow_player := await _player_embedded_in_sand(128, Vector2.ZERO)
	slow_player.velocity.y = slow_player.movement_config.medium_impact_speed - 1.0
	watch_signals(slow_player)
	var slow_result := slow_player._apply_terrain_unstuck(0.1)
	slow_player._handle_physics_impacts(
		TerrainBodyMotionResult.new(),
		TerrainBodyMotionResult.new(),
		slow_result
	)
	assert_almost_eq(
		slow_result.velocity_change.length(),
		slow_player.movement_config.medium_impact_speed - 1.0,
		0.001
	)
	assert_false(slow_player.is_ragdolling())
	assert_signal_not_emitted(slow_player, "death_requested")

	var upward_player := await _player_embedded_in_sand(128, Vector2(0.0, -700.0))
	var upward_result := upward_player._apply_terrain_unstuck(0.1)
	upward_player._handle_physics_impacts(
		TerrainBodyMotionResult.new(),
		TerrainBodyMotionResult.new(),
		upward_result
	)
	assert_true(upward_result.moved)
	assert_eq(upward_result.velocity_change, Vector2.ZERO)
	assert_false(upward_player.is_ragdolling())


func test_partial_sand_does_not_unstuck_or_fabricate_an_impact() -> void:
	var player := await _player_embedded_in_sand(63, Vector2.ZERO, false)
	player.velocity.y = player.movement_config.lethal_impact_speed
	watch_signals(player)
	var result := player._apply_terrain_unstuck(0.1)
	player._handle_physics_impacts(
		TerrainBodyMotionResult.new(),
		TerrainBodyMotionResult.new(),
		result
	)

	assert_false(result.moved)
	assert_eq(result.velocity_change, Vector2.ZERO)
	assert_false(player.is_ragdolling())
	assert_signal_not_emitted(player, "death_requested")


func test_suffocation_samples_air_above_a_partial_head_hex() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Stone"))
	var head_cell := Vector2i(3, 3)
	var above_cell := HexCoord.from_offset_odd_q(head_cell.x, head_cell.y).neighbor(2).to_offset_odd_q()
	world.set_committed_by_offset(head_cell.x, head_cell.y, FixtureLoader.terrain_id("Water"), 64)
	world.set_committed_by_offset(above_cell.x, above_cell.y, FixtureLoader.terrain_id("Air"))
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(head_cell.x, head_cell.y, 16.0)

	assert_true(player._head_has_breathable_air())
	assert_null(player._suffocation_effect_at_head())


func test_suffocation_starts_when_the_head_hex_is_full_non_air() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var head_cell := Vector2i(3, 3)
	world.set_committed_by_offset(head_cell.x, head_cell.y, FixtureLoader.terrain_id("Water"), 127)
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(head_cell.x, head_cell.y, 16.0)

	assert_false(player._head_has_breathable_air())
	assert_not_null(player._suffocation_effect_at_head())


func test_steam_is_breathable_and_applies_slow_cooked_heat() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Steam"))
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)

	assert_true(player._head_has_breathable_air())
	assert_null(player._suffocation_effect_at_head())
	var effect = player._hazard_effect_at(player.global_position)
	assert_eq(effect.cause, DeathCause.COOKED)
	assert_eq(effect.fill_seconds, 5.0)


func test_heat_resistance_delays_lava_and_prevents_steam_cooked_heat() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var steam_id := FixtureLoader.terrain_id("Steam")
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Lava"))
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)
	assert_eq(player._hazard_effect_at(player.global_position).fill_seconds, 0.2)
	player.set_perk_modifiers(_perk_modifiers(["res://config/perks/heat_resistance.tres"]))

	var lava_effect = player._hazard_effect_at(player.global_position)
	assert_eq(lava_effect.cause, DeathCause.COOKED)
	assert_eq(lava_effect.fill_seconds, 1.2)
	for quantity in [1, 63, registry.get_definition(steam_id).maximum_quantity]:
		world.fill_committed(steam_id, quantity)
		assert_null(
			player._hazard_effect_at(player.global_position),
			"Steam quantity %d must not heat a Heat Resistance player" % quantity
		)
		assert_true(player._head_has_breathable_air())

	player.set_perk_modifiers(null)
	world.fill_committed(steam_id, 63)
	assert_eq(player._hazard_effect_at(player.global_position).fill_seconds, 5.0)


func test_sulfur_resistance_makes_sulfur_dioxide_breathable_and_non_poisonous() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var sulfur_dioxide_id := FixtureLoader.terrain_id("Sulfur Dioxide")
	var world := WorldGrid.new(WorldDimensions.new(7, 7), sulfur_dioxide_id)
	# Only a full head hex blocks air, and gas holds more than the default fill.
	world.fill_committed(sulfur_dioxide_id, registry.get_definition(sulfur_dioxide_id).maximum_quantity)
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)

	assert_not_null(player._hazard_effect_at(player.global_position))
	assert_false(player._head_has_breathable_air())
	player.set_perk_modifiers(_perk_modifiers(["res://config/perks/sulfur_resistance.tres"]))
	assert_null(player._hazard_effect_at(player.global_position))
	assert_true(player._head_has_breathable_air())


func test_sulfur_resistance_extends_acid_hazard_duration() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Sulfuric Acid"))
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)

	assert_eq(player._hazard_effect_at(player.global_position).fill_seconds, 1.5)
	player.set_perk_modifiers(_perk_modifiers(["res://config/perks/sulfur_resistance.tres"]))
	assert_eq(player._hazard_effect_at(player.global_position).fill_seconds, 3.5)


func test_glass_is_immune_to_acid_and_poison() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Sulfuric Acid"))
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)
	player.set_perk_modifiers(_perk_modifiers(["res://config/perks/glass_cannon.tres"]))
	assert_null(player._hazard_effect_at(player.global_position))

	world.set_committed_by_offset(3, 3, FixtureLoader.terrain_id("Sulfur Dioxide"), 63)
	assert_null(player._hazard_effect_at(player.global_position))


## A player at rest in open air, rows hex rows above where it would stand on a flat
## stone floor. Its physics is stepped by hand with _fall_until_landed.
func _player_above_floor(rows: float) -> PlayerController:
	var registry := FixtureLoader.terrain_registry()
	var air := FixtureLoader.terrain_id("Air")
	var stone := FixtureLoader.terrain_id("Stone")
	var floor_row := 30
	var world := WorldGrid.new(WorldDimensions.new(15, 34), air)
	for row in range(floor_row, world.dimensions.depth):
		for col in world.dimensions.width:
			world.set_committed_by_offset(col, row, stone)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(player)
	await wait_process_frames(1)
	player.set_physics_process(false)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.configure_environment(world, registry, 16.0)
	# Find where the body stands, then lift it from there.
	var floor_center := HexMetrics.center_for_offset(7, floor_row, 16.0)
	player.global_position = Vector2(floor_center.x, floor_center.y - 16.0 - player.horizontal_collision_radius - 2.0)
	_fall_until_landed(player)
	assert_true(player._grounded, "The fixture floor carries the player")
	player.global_position.y -= rows * HEX_ROW
	player.velocity = Vector2.ZERO
	player._movement_model.velocity = Vector2.ZERO
	player._grounded = false
	return player


## Steps the player's own physics until it stands on the floor or asks to die.
func _fall_until_landed(player: PlayerController) -> void:
	var died := [false]
	var on_death := func(_cause: StringName) -> void: died[0] = true
	player.death_requested.connect(on_death)
	for _step in 600:
		player._physics_process(1.0 / 60.0)
		if died[0] or player._grounded:
			break
	player.death_requested.disconnect(on_death)


func _player_embedded_in_sand(fill: int, initial_velocity: Vector2, surrounded := true) -> PlayerController:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.terrain_unstuck_push_speed = 40.0
	add_child_autofree(player)
	await wait_process_frames(1)
	var base_terrain := FixtureLoader.terrain_id("Stone") if surrounded else FixtureLoader.terrain_id("Air")
	var world := WorldGrid.new(WorldDimensions.new(7, 7), base_terrain)
	var sand_cell := Vector2i(3, 3)
	world.set_committed_by_offset(sand_cell.x, sand_cell.y, FixtureLoader.terrain_id("Sand"), fill)
	if surrounded:
		var sand_hex := HexCoord.from_offset_odd_q(sand_cell.x, sand_cell.y)
		var chamber_center := sand_hex.neighbor(2).neighbor(2)
		_set_air_hex_radius(world, chamber_center, 1)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.global_position = HexMetrics.center_for_offset(sand_cell.x, sand_cell.y, 16.0)
	player.velocity = initial_velocity
	return player


func _player_in_uniform_terrain(terrain_name: String, quantity := 127) -> PlayerController:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id(terrain_name))
	if quantity < 127:
		for row in world.dimensions.depth:
			for col in world.dimensions.width:
				world.set_committed_by_offset(col, row, FixtureLoader.terrain_id(terrain_name), quantity)
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)
	return player


func _set_air_hex_radius(world: WorldGrid, center: HexCoord, radius: int) -> void:
	for delta_q in range(-radius, radius + 1):
		var min_delta_r := maxi(-radius, -delta_q - radius)
		var max_delta_r := mini(radius, -delta_q + radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var cell := center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q()
			if world.dimensions.is_in_bounds_offset(cell.x, cell.y):
				world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Air"))


func _perk_modifiers(resource_paths: Array[String]) -> PerkModifierSnapshot:
	var builder := PerkModifierBuilder.new()
	for resource_path in resource_paths:
		var definition := load(resource_path) as PerkDefinition
		for effect in definition.effects:
			effect.apply(builder)
	return builder.build()
