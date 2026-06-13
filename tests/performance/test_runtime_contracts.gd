extends GutTest

const GameplayAssertionsScript = preload("res://tests/helpers/gameplay_assertions.gd")
const ScenarioDriverScript = preload("res://tests/helpers/scenario_driver.gd")

func before_each() -> void:
	var path := "user://gut_perf_runtime.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_idle_play_does_not_rebuild_visible_chunks_every_frame() -> void:
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
	app_root.world_presenter.reset_stats()
	await ScenarioDriverScript.wait_process_frames(1)
	app_root.world_presenter.reset_stats()
	await ScenarioDriverScript.wait_process_frames(60)

	assert_lte(app_root.world_presenter.rebuild_count(), app_root.world_presenter.visible_chunk_count())
	assert_eq(app_root.world_presenter.last_refresh_rebuild_count(), 0)
	assert_true(app_root.world_presenter.refresh_count() >= 60)


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

	app_root.world_presenter.reset_stats()
	var start_physics_frames := app_root.get_player().physics_frame_count()
	await ScenarioDriverScript.wait_physics_frames(300)

	GameplayAssertionsScript.assert_no_scene_leaks(self, app_root.world_presenter, 15)
	assert_gte(app_root.get_player().physics_frame_count() - start_physics_frames, 250)
	assert_gte(app_root.simulation_backend().advances_performed(), 5)
	assert_lte(app_root.simulation_backend().commits_performed(), app_root.simulation_backend().advances_performed())
