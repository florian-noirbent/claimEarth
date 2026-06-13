extends GutTest


func test_generation_task_reports_progress_and_returns_result() -> void:
	var host := Node.new()
	add_child_autofree(host)

	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var task := WorldGenerationTask.new()

	watch_signals(task)
	var result := await task.generate_async(host, profile, registry, 77)

	assert_signal_emitted(task, "progress_changed")
	assert_signal_emitted(task, "completed")
	assert_not_null(result)
	assert_true(result.world_hash != 0)
