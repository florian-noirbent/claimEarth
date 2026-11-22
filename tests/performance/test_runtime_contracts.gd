extends GutTest

const GameplayAssertionsScript = preload("res://tests/helpers/gameplay_assertions.gd")
const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")

func before_each() -> void:
	var path := "user://gut_perf_runtime.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_idle_play_keeps_shader_renderer_stable() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_perf_runtime.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("perf-idle"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)

	GameplayAssertionsScript.assert_app_is_playing(self, app_root)
	await ScenarioDriverScript.wait_process_frames(1)
	for _frame in range(60):
		await ScenarioDriverScript.wait_process_frames(1)

	assert_eq(app_root.world_presenter.total_renderer_nodes(), 1)


func test_long_idle_run_keeps_scene_sizes_bounded_and_player_physics_active() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_perf_runtime.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("perf-long"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)

	var start_physics_frames := app_root.get_player().physics_frame_count()
	await ScenarioDriverScript.wait_physics_frames(300)

	GameplayAssertionsScript.assert_no_scene_leaks(self, app_root.world_presenter, 15)
	assert_gte(app_root.get_player().physics_frame_count() - start_physics_frames, 250)


func test_resting_generated_barrels_run_no_physics_steps() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_perf_runtime.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)

	app_root.start_run_for_test(SeedUtils.seed_from_text("perf-barrels"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)
	await ScenarioDriverScript.wait_physics_frames(30)

	var barrel_count := 0
	for child in app_root.item_controller.get_children():
		var barrel := child as ExplosiveBarrel
		if barrel == null:
			continue
		barrel_count += 1
		assert_true(barrel.is_sleeping(), "A resting generated barrel sleeps")
		assert_false(barrel.is_physics_processing(), "A sleeping barrel runs no physics steps")
		assert_false(barrel.explosive.is_physics_processing(), "An unarmed explosive runs no physics steps")
	assert_gt(barrel_count, 0)
	assert_eq(app_root.item_controller.explosive_barrel_count(), barrel_count)


func test_a_death_adds_no_nodes_stays_in_the_particle_budget_and_stops_stepping() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_perf_runtime.json")
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	app_root.start_run_for_test(SeedUtils.seed_from_text("perf-death"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 1.0)
	var player := app_root.get_player()
	var animator := player.presentation.death
	var effects := app_root.gameplay_feedback.effects()
	var player_nodes := _node_count(player)
	var feedback_nodes := _node_count(app_root.gameplay_feedback)

	# The worst case: every part bursts at once with trails, spurts, and splats.
	app_root._on_player_killed(DeathCause.BOMB, player.global_position + Vector2(-30.0, 10.0))
	var peak_particles := 0
	var slowest_step_usec := 0
	animator.set_physics_process(false)
	for _step in range(360):
		if not animator.is_playing():
			break
		var started := Time.get_ticks_usec()
		animator.advance(1.0 / 60.0)
		slowest_step_usec = maxi(slowest_step_usec, Time.get_ticks_usec() - started)
		effects.advance(1.0 / 60.0)
		peak_particles = maxi(peak_particles, effects.live_particle_count())

	assert_false(animator.is_playing(), "The sequence ends by itself")
	assert_eq(animator.detached_part_count(), 16)
	assert_eq(_node_count(player), player_nodes, "Loose parts reuse the rig's sprites")
	assert_eq(_node_count(app_root.gameplay_feedback), feedback_nodes, "Blood and smoke are pooled particles")
	assert_gt(peak_particles, 100)
	assert_lte(peak_particles, effects.particle_capacity())
	# Generous: a step takes about half a millisecond on a desktop.
	assert_lt(slowest_step_usec, 12000, "One step of the worst death stays far below a frame")


func _node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _node_count(child)
	return total
