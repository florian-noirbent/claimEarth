extends GutTest

const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")

class FakeAnchorQuery extends GrappleAnchorQuery:
	var anchor := GrappleAnchor.new(Vector2i(1, 1), Vector2(64, -24))

	func find_anchor(_origin: Vector2, _target: Vector2) -> GrappleAnchor:
		return anchor

	func is_anchor_valid(_anchor: GrappleAnchor) -> bool:
		return true


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
