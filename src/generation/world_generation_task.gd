class_name WorldGenerationTask
extends RefCounted


signal progress_changed(progress: float, label: String)
signal completed(result: WorldGenerationResult)


var _generator := WorldGenerator.new()


func generate_async(
	host: Node,
	profile: GenerationProfile,
	terrain_registry: TerrainRegistry,
	run_seed: int
) -> WorldGenerationResult:
	var steps := PackedStringArray([
		"Preparing generation",
		"Sampling cave layers",
		"Seeding hazard pockets",
		"Carving spawn chamber",
		"Validating map",
	])

	for index in range(steps.size()):
		progress_changed.emit(float(index) / float(steps.size()), steps[index])
		await host.get_tree().process_frame

	var result := _generator.generate(profile, terrain_registry, run_seed)
	progress_changed.emit(1.0, "Generation complete")
	completed.emit(result)
	return result
