class_name PocketNoisePass
extends GenerationPass


func get_name() -> String:
	return "pocket_noise"


func apply(context: GenerationContext) -> bool:
	var sand_id := _terrain_id(context.terrain_registry, "Sand")
	var water_id := _terrain_id(context.terrain_registry, "Water")
	var lava_id := _terrain_id(context.terrain_registry, "Lava")
	var dirt_id := _terrain_id(context.terrain_registry, "Dirt")
	var air_id := _terrain_id(context.terrain_registry, "Air")

	var noise := FastNoiseLite.new()
	noise.seed = SeedUtils.derive_seed(context.run_seed, "pocket_noise")
	noise.frequency = 1.0
	noise.fractal_octaves = context.profile.pocket_octaves
	noise.fractal_gain = 0.56
	noise.fractal_lacunarity = 2.1

	var blob_noise := FastNoiseLite.new()
	blob_noise.seed = SeedUtils.derive_seed(context.run_seed, "pocket_blob_noise")
	blob_noise.frequency = 1.0
	blob_noise.fractal_octaves = context.profile.pocket_octaves + 1
	blob_noise.fractal_gain = 0.48
	blob_noise.fractal_lacunarity = 2.35

	for row in range(context.profile.depth):
		var depth_ratio := float(row) / float(max(1, context.profile.depth - 1))
		for col in range(context.profile.width):
			var current_id := context.world.get_committed_by_offset(col, row)
			if current_id == air_id:
				continue

			var sample := noise.get_noise_2d(
				float(col) * context.profile.pocket_frequency_x,
				float(row) * context.profile.pocket_frequency_y
			)
			var blob_sample := blob_noise.get_noise_2d(
				float(col) * context.profile.pocket_frequency_x * 0.72 + 11.0,
				float(row) * context.profile.pocket_frequency_y * 0.84 + 73.0
			)
			var normalized := (sample * 0.58 + blob_sample * 0.42) * 0.5 + 0.5

			if normalized >= context.profile.lava_threshold and depth_ratio >= context.profile.lava_depth_start_ratio:
				context.world.set_committed_by_offset(col, row, lava_id)
			elif normalized >= context.profile.water_threshold and depth_ratio >= context.profile.water_depth_start_ratio:
				context.world.set_committed_by_offset(col, row, water_id)
			elif normalized >= context.profile.sand_threshold and current_id == dirt_id:
				context.world.set_committed_by_offset(col, row, sand_id)

	return true


func _terrain_id(registry: TerrainRegistry, name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == name:
			return definition.stable_id
	return -1
