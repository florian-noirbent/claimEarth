class_name WorldGenerator
extends RefCounted


var _passes: Array[GenerationPass] = [
	BaseNoisePass.new(),
	PocketNoisePass.new(),
	SpawnChamberPass.new(),
	ShowcasePocketPass.new(),
	BoundarySealPass.new(),
]


func generate(profile: GenerationProfile, terrain_registry: TerrainRegistry, run_seed: int) -> WorldGenerationResult:
	var world := WorldGrid.new(profile.create_dimensions(), 0)
	var context := GenerationContext.new(profile, run_seed, terrain_registry, world)

	for generation_pass in _passes:
		if not generation_pass.apply(context):
			push_error("World generation pass failed: %s for seed %d" % [generation_pass.get_name(), run_seed])
			return null

	var result := WorldGenerationResult.new()
	result.world = world
	result.final_seed = run_seed
	result.attempts = 1
	result.spawn_rect = context.spawn_rect
	result.world_hash = world.committed_hash()
	return result
