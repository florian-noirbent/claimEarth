extends GutTest


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
