extends GutTest


func test_newer_chunk_job_replaces_and_merges_older_layers() -> void:
	var registry := FixtureLoader.terrain_registry()
	var metadata := CompiledTerrainData.compile(registry)
	var world := WorldGrid.new(WorldDimensions.new(4, 4), FixtureLoader.terrain_id("Air"))
	var rect := Rect2i(0, 0, 4, 4)
	var first := ChunkBuildJob.new()
	first.configure(Vector2i.ZERO, 1, TerrainLayerMask.FLUID_VISUAL, rect, rect, world.copy_committed_region(rect), world.copy_committed_fill_region(rect), metadata, 16.0, 4)
	var second := ChunkBuildJob.new()
	second.configure(Vector2i.ZERO, 2, TerrainLayerMask.SAND_VISUAL, rect, rect, world.copy_committed_region(rect), world.copy_committed_fill_region(rect), metadata, 16.0, 4)
	var executor := CooperativeChunkJobExecutor.new()
	executor.enqueue(first)
	executor.enqueue(second)

	assert_eq(executor.pending_count(), 1)
	executor.advance(1000000)
	var completed := executor.take_completed()
	assert_eq(completed.size(), 1)
	assert_eq(completed[0].revision, 2)
	assert_eq(completed[0].layer_mask, TerrainLayerMask.FLUID_VISUAL | TerrainLayerMask.SAND_VISUAL)
