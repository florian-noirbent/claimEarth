## Interactive, deterministic frame-time harness for WorldPresenter.
## Run through benchmark_world_presenter.ps1; this script deliberately does not
## run headless because the presenter must submit work to a real renderer.
extends SceneTree


const WIDTH := 100
const DEPTH := 512
const WARMUP_FRAMES := 90
const MEASURE_FRAMES := 240
const VIEW_CENTER_ROW := 72


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _options()
	var output_path := options.get("output", "") as String
	var screenshot_directory := options.get("screenshots", "") as String
	if output_path.is_empty():
		push_error("Expected --output <absolute JSON path>.")
		quit(2)
		return
	if not screenshot_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(screenshot_directory)
	var registry := _terrain_registry()
	var presentation_config := load("res://config/presentation/default_world_presentation.tres") as WorldPresentationConfig
	var results := {}
	for scenario_name in ["solid", "boundaries", "dark_air", "sand_streams", "liquid_heavy", "generated_world"]:
		results[scenario_name] = await _measure_scenario(scenario_name, registry, presentation_config, screenshot_directory)
	var result := {
		"schema_version": 1,
		"environment": {
			"godot": Engine.get_version_info().get("string", "unknown"),
			"renderer": RenderingServer.get_current_rendering_method(),
			"os": OS.get_name(),
			"viewport": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
			"warmup_frames": WARMUP_FRAMES,
			"measured_frames": MEASURE_FRAMES,
		},
		"scenarios": results,
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write benchmark output: %s" % output_path)
		quit(3)
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("WORLD_PRESENTER_BENCHMARK_JSON=" + output_path)
	quit()


func _measure_scenario(scenario_name: String, registry: TerrainRegistry, presentation_config: WorldPresentationConfig, screenshot_directory: String) -> Dictionary:
	var stage := Node2D.new()
	root.add_child(stage)
	var presenter := WorldPresenter.new()
	presenter.presentation_config = presentation_config
	stage.add_child(presenter)
	presenter.configure(_make_world(scenario_name, registry), registry)
	var camera := Camera2D.new()
	camera.position = HexMetrics.center_for_offset(WIDTH / 2, VIEW_CENTER_ROW, presenter.hex_radius)
	camera.zoom = Vector2(0.55, 0.55)
	stage.add_child(camera)
	camera.make_current()
	for _frame in range(WARMUP_FRAMES):
		await process_frame
	var samples_usec: Array[int] = []
	for _frame in range(MEASURE_FRAMES):
		var started := Time.get_ticks_usec()
		await process_frame
		samples_usec.append(Time.get_ticks_usec() - started)
	if not screenshot_directory.is_empty():
		var image := root.get_viewport().get_texture().get_image()
		image.save_png(screenshot_directory.path_join(scenario_name + ".png"))
	stage.queue_free()
	await process_frame
	return _stats(samples_usec)


func _make_world(scenario_name: String, registry: TerrainRegistry) -> WorldGrid:
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	var dirt := _terrain_id(registry, "Dirt")
	var sand := _terrain_id(registry, "Sand")
	var water := _terrain_id(registry, "Water")
	var lava := _terrain_id(registry, "Lava")
	var world := WorldGrid.new(WorldDimensions.new(WIDTH, DEPTH), air)
	match scenario_name:
		"solid":
			_fill_view(world, stone)
		"boundaries":
			for row in range(42, 104):
				for col in range(WIDTH):
					world.set_committed_by_offset(col, row, stone if (col + row) % 2 == 0 else dirt)
		"dark_air":
			for row in range(42, 104):
				for col in range(WIDTH):
					world.set_committed_light_by_offset(col, row, 0)
		"sand_streams":
			for col in range(4, WIDTH - 4, 8):
				for row in range(42, 96):
					world.set_committed_by_offset(col, row, sand, 128 + (row % 3) * 48)
		"liquid_heavy":
			for row in range(42, 104):
				for col in range(WIDTH):
					world.set_committed_by_offset(col, row, water if (col + row) % 5 else lava, 160 + (col % 3) * 32)
		"generated_world":
			var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
			return WorldGenerator.new().generate(profile, registry, SeedUtils.seed_from_text("world-presenter-benchmark")).world
	for col in range(WIDTH):
		world.set_committed_by_offset(col, DEPTH - 2, stone)
		world.set_committed_by_offset(col, DEPTH - 1, stone)
	world.upload_cpu_snapshot_to_texture()
	return world


func _fill_view(world: WorldGrid, terrain_id: int) -> void:
	for row in range(42, 104):
		for col in range(WIDTH):
			world.set_committed_by_offset(col, row, terrain_id)


func _terrain_registry() -> TerrainRegistry:
	var registry := TerrainRegistry.new()
	registry.try_configure(load("res://config/terrain/catalog.tres") as TerrainCatalog)
	return registry


func _terrain_id(registry: TerrainRegistry, display_name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == display_name:
			return definition.stable_id
	push_error("Benchmark terrain is missing: %s" % display_name)
	return 0


func _stats(values: Array[int]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for value in sorted:
		total += value
	return {
		"min_usec": sorted[0],
		"median_usec": sorted[sorted.size() / 2],
		"p95_usec": sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.95) - 1)],
		"p99_usec": sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.99) - 1)],
		"max_usec": sorted[-1],
		"mean_usec": float(total) / float(sorted.size()),
	}


func _options() -> Dictionary:
	var result := {}
	var arguments := OS.get_cmdline_user_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "--output":
			result["output"] = arguments[index + 1]
		if arguments[index] == "--screenshots":
			result["screenshots"] = arguments[index + 1]
	return result
