extends SceneTree


const WIDTH := 100
const DEPTH := 2000
const ACTIVE_ROWS := 96
const SAMPLE_COUNT := 20
const MAX_FRAMES_PER_TICK := 120
const SimulationShader := preload("res://src/simulation/render_texture_simulation.gdshader")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := FixtureLoader.terrain_registry()
	var scenarios := {}
	for scenario_name in ["settled", "fluid", "sand", "mixed", "dense"]:
		var world := _make_world(scenario_name)
		scenarios[scenario_name] = await _benchmark_scenario(world, registry)
		if scenarios[scenario_name].is_empty():
			return
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var generated := WorldGenerator.new().generate(profile, registry, SeedUtils.seed_from_text("terrain-benchmark"))
	scenarios["generated_world"] = await _benchmark_scenario(generated.world, registry)
	if scenarios["generated_world"].is_empty():
		return
	var output := {
		"environment": {
			"godot": Engine.get_version_info().get("string", "unknown"),
			"renderer": RenderingServer.get_current_rendering_method(),
			"width": WIDTH,
			"depth": DEPTH,
			"active_rows": ACTIVE_ROWS,
			"samples": SAMPLE_COUNT,
		},
		"scenarios": scenarios,
	}
	print("TERRAIN_BENCHMARK_JSON_BEGIN")
	print(JSON.stringify(output, "  "))
	print("TERRAIN_BENCHMARK_JSON_END")
	quit()


func _make_world(scenario_name: String) -> WorldGrid:
	var air := FixtureLoader.terrain_id("Air")
	var stone := FixtureLoader.terrain_id("Stone")
	var sand := FixtureLoader.terrain_id("Sand")
	var water := FixtureLoader.terrain_id("Water")
	var world := WorldGrid.new(WorldDimensions.new(WIDTH, DEPTH), air)
	for col in range(WIDTH):
		world.set_committed_by_offset(col, ACTIVE_ROWS + 2, stone)
	match scenario_name:
		"fluid":
			for index in range(12):
				world.set_committed_by_offset(4 + index * 7, 8 + (index % 4) * 12, water)
		"sand":
			for index in range(12):
				world.set_committed_by_offset(4 + index * 7, 8 + (index % 4) * 12, sand)
		"mixed":
			for index in range(24):
				world.set_committed_by_offset(2 + (index * 4) % 96, 6 + (index % 6) * 12, sand if index % 2 == 0 else water)
		"dense":
			for row in range(1, ACTIVE_ROWS, 2):
				for col in range(1, WIDTH - 1):
					world.set_committed_by_offset(col, row, sand if (col + row) % 3 else water)
	return world


func _benchmark_scenario(source_world: WorldGrid, registry: TerrainRegistry) -> Dictionary:
	var original := source_world.copy_rgba_bytes()
	var initial_tick_samples: Array[int] = []
	var steady_tick_samples: Array[int] = []
	var committed_revisions: Array[int] = []
	for _sample in range(SAMPLE_COUNT):
		var world := WorldGrid.new(source_world.dimensions, 0)
		world.replace_from_rgba_bytes(original)
		var backend := RenderTextureSimulationBackend.new()
		backend.set_simulation_shader(SimulationShader)
		backend.initialize(world, registry, 12345)
		backend.attach_to(root)
		await process_frame
		var started := Time.get_ticks_usec()
		if not await _complete_one_tick(backend):
			return {}
		initial_tick_samples.append(Time.get_ticks_usec() - started)
		var commit := backend.commit_if_ready()
		committed_revisions.append(commit.revision)
		started = Time.get_ticks_usec()
		if not await _complete_one_tick(backend):
			return {}
		steady_tick_samples.append(Time.get_ticks_usec() - started)
		backend.shutdown()
	return {
		"initial_tick_usec": _stats(initial_tick_samples),
		"steady_tick_usec": _stats(steady_tick_samples),
		"committed_revision": _stats(committed_revisions),
	}


# The GPU backend renders its passes across frames, so a tick needs frames to finish.
func _complete_one_tick(backend: RenderTextureSimulationBackend) -> bool:
	var target_ticks := backend.ticks_completed() + 1
	for _frame in range(MAX_FRAMES_PER_TICK):
		backend.advance(RenderTextureSimulationBackend.PASS_COUNT)
		await process_frame
		if backend.ticks_completed() >= target_ticks:
			return true
	backend.shutdown()
	push_error("A terrain simulation tick did not finish within %d frames." % MAX_FRAMES_PER_TICK)
	quit(1)
	return false


func _stats(values: Array[int]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for value in sorted:
		total += value
	return {
		"min": sorted[0],
		"median": sorted[int(sorted.size() / 2)],
		"p95": sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.95)) - 1)],
		"max": sorted[-1],
		"mean": float(total) / float(sorted.size()),
	}
