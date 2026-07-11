extends GutTest

const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")

class FakeAnchorQuery extends GrappleAnchorQuery:
	var anchor := GrappleAnchor.new(Vector2i(1, 1), Vector2(64, -24))

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return anchor

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return true


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
	assert_not_null(player.body_polygon)


func test_player_emits_bounds_exit_when_falling_past_limit() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.world_bottom_y = 10.0
	add_child_autofree(player)
	await wait_process_frames(1)

	watch_signals(player)
	player.global_position.y = 20.0
	await wait_physics_frames(1)

	assert_signal_emitted(player, "bounds_exited")


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


func test_player_hook_launch_animation_plays_without_anchor() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.configure_grapple_anchor_query(MissingAnchorQuery.new())
	player.hook_launch_animation_seconds = 0.1
	add_child_autofree(player)
	await wait_process_frames(1)

	ScenarioDriverScript.set_mouse_world_position(player, Vector2.RIGHT * 10000.0)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)

	assert_false(player.is_grapple_attached())
	assert_true(player.rope_line.visible)
	assert_true(player.hook_indicator.visible)
	assert_gt(player.rope_line.points[1].length(), 0.0)
	assert_lt(player.rope_line.points[1].length(), player.grapple_config.effective_attach_range())

	Input.action_release(InputActions.HOOK)
	await wait_physics_frames(1)


func test_player_hook_launch_animation_uses_full_range_for_close_cursor() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	player.configure_grapple_anchor_query(MissingAnchorQuery.new())
	player.hook_launch_animation_seconds = 0.1
	add_child_autofree(player)
	await wait_process_frames(1)

	ScenarioDriverScript.set_mouse_world_position(player, Vector2.RIGHT * 20.0)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(1)

	assert_true(player.rope_line.visible)
	assert_gt(player.rope_line.points[1].length(), 20.0)

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
	world.set_committed_by_offset(4, 2, FixtureLoader.terrain_id("Air"))
	player.configure_environment(world, FixtureLoader.terrain_registry(), 16.0)
	player.global_position = HexMetrics.center_for_offset(2, 2, 16.0)
	player.velocity = Vector2(-20.0, 30.0)
	var start_position := player.global_position
	var air_center := HexMetrics.center_for_offset(4, 2, 16.0)

	player._apply_terrain_unstuck(0.1)

	assert_gt(player.global_position.distance_to(air_center), 0.0)
	assert_lt(player.global_position.distance_to(air_center), start_position.distance_to(air_center))
	assert_almost_eq(player.global_position.distance_to(start_position), 4.0, 0.001)
	assert_eq(player.velocity.x, 0.0)
	assert_eq(player.velocity.y, 30.0)


func test_suffocation_samples_air_above_a_partial_head_hex() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)

	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Stone"))
	var head_cell := Vector2i(3, 3)
	var above_cell := HexCoord.from_offset_odd_q(head_cell.x, head_cell.y).neighbor(2).to_offset_odd_q()
	world.set_committed_by_offset(head_cell.x, head_cell.y, FixtureLoader.terrain_id("Water"), 128)
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
	world.set_committed_by_offset(head_cell.x, head_cell.y, FixtureLoader.terrain_id("Water"), 255)
	player.configure_environment(world, registry, 16.0)
	player.global_position = HexMetrics.center_for_offset(head_cell.x, head_cell.y, 16.0)

	assert_false(player._head_has_breathable_air())
	assert_not_null(player._suffocation_effect_at_head())
