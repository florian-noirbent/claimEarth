extends SceneTree


const WIDTH := 100
const DEPTH := 2000
const ACTIVE_ROWS := 96
const SAMPLE_COUNT := 20


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := FixtureLoader.terrain_registry()
	var scenarios := {}
	for scenario_name in ["settled", "fluid", "sand", "mixed", "dense"]:
		var world := _make_world(scenario_name)
		scenarios[scenario_name] = _benchmark_scenario(world, registry)
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var generated := WorldGenerator.new().generate(profile, registry, SeedUtils.seed_from_text("terrain-benchmark"))
	scenarios["generated_world"] = _benchmark_scenario(generated.world, registry)
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
	world.working_cells = world.committed_cells.duplicate()
	world.working_fill = world.committed_fill.duplicate()
	return world


func _benchmark_scenario(source_world: WorldGrid, registry: TerrainRegistry) -> Dictionary:
	var original := source_world.committed_cells.duplicate()
	var original_fill := source_world.committed_fill.duplicate()
	var initial_tick_samples: Array[int] = []
	var steady_tick_samples: Array[int] = []
	var build_samples: Array[int] = []
	var changed_counts: Array[int] = []
	var dirty_chunk_counts: Array[int] = []
	var collision_chunk_counts: Array[int] = []
	for _sample in range(SAMPLE_COUNT):
		var world := WorldGrid.new(source_world.dimensions, 0)
		world.committed_cells = original.duplicate()
		world.working_cells = original.duplicate()
		world.committed_fill = original_fill.duplicate()
		world.working_fill = original_fill.duplicate()
		var backend := CooperativeChunkBackend.new()
		backend.initialize(world, registry, 12345)
		var activity := ChunkActivityIndex.new(world.dimensions)
		backend.schedule(activity.visible_chunks_for_depth_window(0, ACTIVE_ROWS))
		var started := Time.get_ticks_usec()
		var progress := backend.advance(1000000)
		while not progress.step_completed:
			progress = backend.advance(1000000)
		initial_tick_samples.append(Time.get_ticks_usec() - started)
		var commit := backend.commit_if_ready()
		changed_counts.append(commit.changed_cell_count())
		if commit.did_commit:
			activity.mark_change_set(commit.change_set)
			dirty_chunk_counts.append(commit.change_set.chunk_masks.size())
			var collision_chunks := 0
			for mask_variant in commit.change_set.chunk_masks.values():
				if (int(mask_variant) & TerrainLayerMask.COLLISION) != 0:
					collision_chunks += 1
			collision_chunk_counts.append(collision_chunks)
			started = Time.get_ticks_usec()
			_build_dirty_chunks(world, registry, activity, commit.revision)
			build_samples.append(Time.get_ticks_usec() - started)
		else:
			dirty_chunk_counts.append(0)
			collision_chunk_counts.append(0)
			build_samples.append(0)
		started = Time.get_ticks_usec()
		progress = backend.advance(1000000)
		while not progress.step_completed:
			progress = backend.advance(1000000)
		steady_tick_samples.append(Time.get_ticks_usec() - started)
	return {
		"initial_tick_usec": _stats(initial_tick_samples),
		"steady_tick_usec": _stats(steady_tick_samples),
		"chunk_data_build_usec": _stats(build_samples),
		"changed_cells": _stats(changed_counts),
		"dirty_chunks": _stats(dirty_chunk_counts),
		"collision_chunks": _stats(collision_chunk_counts),
	}


func _build_dirty_chunks(world: WorldGrid, registry: TerrainRegistry, activity: ChunkActivityIndex, revision: int) -> void:
	var metadata := CompiledTerrainData.compile(registry)
	var visible_lookup := {}
	for chunk in activity.visible_chunks_for_depth_window(0, ACTIVE_ROWS):
		visible_lookup[chunk] = true
	var dirty_work := activity.consume_dirty_work()
	for coord_variant in dirty_work.keys():
		var coord := coord_variant as Vector2i
		if not visible_lookup.has(coord):
			continue
		var chunk_rect := activity.chunk_rect(coord)
		var snapshot_rect := chunk_rect.grow(1).intersection(Rect2i(Vector2i.ZERO, Vector2i(world.dimensions.width, world.dimensions.depth)))
		var job := ChunkBuildJob.new()
		var work := dirty_work[coord] as Dictionary
		job.configure(coord, revision, int(work["mask"]), chunk_rect, snapshot_rect, world.copy_committed_region(snapshot_rect), world.copy_committed_fill_region(snapshot_rect), metadata, 16.0, world.dimensions.width, work["collision_indices"] as PackedInt32Array)
		while not job.advance(1000000):
			pass


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
