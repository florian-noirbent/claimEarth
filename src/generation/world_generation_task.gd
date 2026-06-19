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
	var steps := PackedStringArray(["Preparing generation"])
	for pass_resource in profile.active_passes():
		steps.append(pass_resource.get_progress_label())

	for index in range(steps.size()):
		progress_changed.emit(float(index) / float(steps.size()), steps[index])
		await Engine.get_main_loop().process_frame
		if not is_instance_valid(host) or host.is_queued_for_deletion():
			return null

	var result := _generator.generate(profile, terrain_registry, run_seed)
	progress_changed.emit(1.0, "Generation complete")
	completed.emit(result)
	return result
