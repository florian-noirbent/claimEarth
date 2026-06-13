class_name BaseNoisePass
extends GenerationPass


func get_name() -> String:
	return "base_noise"


func apply(context: GenerationContext) -> bool:
	var air_id := _terrain_id(context.terrain_registry, "Air")
	var stone_id := _terrain_id(context.terrain_registry, "Stone")
	var dirt_id := _terrain_id(context.terrain_registry, "Dirt")
	var noise := FastNoiseLite.new()
	noise.seed = SeedUtils.derive_seed(context.seed, "base_noise")
	noise.frequency = 1.0
	noise.fractal_octaves = context.profile.base_octaves
	noise.fractal_gain = context.profile.base_gain

	var strata_noise := FastNoiseLite.new()
	strata_noise.seed = SeedUtils.derive_seed(context.seed, "strata_noise")
	strata_noise.frequency = 1.0
	strata_noise.fractal_octaves = max(1, context.profile.base_octaves - 1)
	strata_noise.fractal_gain = 0.5

	for row in range(context.profile.depth):
		var depth_ratio := float(row) / float(max(1, context.profile.depth - 1))
		for col in range(context.profile.width):
			var column_noise := noise.get_noise_2d(
				float(col) * context.profile.base_frequency_x,
				float(row) * context.profile.base_frequency_y
			)
			var strata_noise_value := strata_noise.get_noise_2d(
				0.0,
				float(row) * context.profile.base_frequency_y * 2.0
			)
			var horizontal_strata := sin(float(row) * 0.09 + float(col) * 0.006) * 0.14
			var cave_bias := lerpf(0.28, 0.12, depth_ratio)
			var adjusted := strata_noise_value * 0.68 + column_noise * 0.16 + horizontal_strata + cave_bias
			var cell_id := stone_id
			if adjusted > context.profile.dirt_threshold:
				cell_id = stone_id
			elif adjusted > context.profile.cave_threshold:
				cell_id = dirt_id
			else:
				cell_id = air_id
			context.world.set_committed_by_offset(col, row, cell_id)

	return true


func _terrain_id(registry: TerrainRegistry, name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == name:
			return definition.stable_id
	return -1
