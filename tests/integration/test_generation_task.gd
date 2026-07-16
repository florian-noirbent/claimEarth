extends GutTest

const BaseNoisePassScript = preload("res://src/generation/base_noise_pass.gd")
const FillPassScript = preload("res://src/generation/fill_pass.gd")


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


func test_generation_task_progress_reflects_active_pass_stack() -> void:
	var host := Node.new()
	add_child_autofree(host)

	var registry := FixtureLoader.terrain_registry()
	var profile := GenerationProfile.new()
	profile.width = 8
	profile.depth = 12

	var base_pass = BaseNoisePassScript.new()
	base_pass.pass_seed_key = "base"
	base_pass.label = "Base Layer"
	var fill_pass = FillPassScript.new()
	fill_pass.pass_seed_key = "fill"
	fill_pass.label = "Fill"
	fill_pass.fill_terrain = FixtureLoader.terrain_definition_named("Lava")
	fill_pass.min_depth_ratio = 0.9
	profile.passes = [base_pass, fill_pass]

	var task := WorldGenerationTask.new()
	var labels: Array[String] = []
	task.progress_changed.connect(func(_progress: float, label: String) -> void:
		labels.append(label)
	)

	var result := await task.generate_async(host, profile, registry, 90)

	assert_not_null(result)
	assert_eq(labels[0], "Preparing generation")
	assert_eq(labels[1], base_pass.get_progress_label())
	assert_eq(labels[2], fill_pass.get_progress_label())
