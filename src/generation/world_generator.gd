## Executes generation profiles into deterministic WorldGrid instances.
class_name WorldGenerator
extends RefCounted


func generate(profile: GenerationProfile, terrain_registry: TerrainRegistry, run_seed: int) -> WorldGenerationResult:
	if profile == null:
		return null
	profile.ensure_pass_seed_keys()
	var world := WorldGrid.new(profile.create_dimensions(), 0)
	var context := GenerationContext.new(profile, run_seed, terrain_registry, world)

	for generation_pass in profile.active_passes():
		if not generation_pass.apply(context):
			push_error("World generation pass failed: %s for seed %d" % [generation_pass.get_display_name(), run_seed])
			return null

	var result := WorldGenerationResult.new()
	result.world = world
	result.final_seed = run_seed
	result.attempts = 1
	result.spawn_rect = context.spawn_rect
	result.item_chest_spawns = context.item_chest_spawns.duplicate()
	result.perk_geode_spawns = context.perk_geode_spawns.duplicate()
	result.world_hash = world.committed_hash()
	return result
