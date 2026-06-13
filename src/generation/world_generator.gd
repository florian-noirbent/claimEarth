class_name WorldGenerator
extends RefCounted


var _passes: Array[GenerationPass] = [
	BaseNoisePass.new(),
	PocketNoisePass.new(),
	SpawnChamberPass.new(),
	ShowcasePocketPass.new(),
	BoundarySealPass.new(),
	GenerationValidationPass.new(),
]


func generate(profile: GenerationProfile, terrain_registry: TerrainRegistry, seed: int) -> WorldGenerationResult:
	for attempt in range(profile.max_retries + 1):
		var attempt_seed := SeedUtils.derive_seed(seed, "attempt_%d" % attempt)
		var world := WorldGrid.new(profile.create_dimensions(), 0)
		var context := GenerationContext.new(profile, attempt_seed, terrain_registry, world)

		var passed := true
		for generation_pass in _passes:
			if not generation_pass.apply(context):
				passed = false
				break

		if passed:
			var result := WorldGenerationResult.new()
			result.world = world
			result.final_seed = attempt_seed
			result.attempts = attempt + 1
			result.spawn_rect = context.spawn_rect
			result.world_hash = world.committed_hash()
			return result

	push_error("World generation failed after %d attempts for seed %d" % [profile.max_retries + 1, seed])
	return null
