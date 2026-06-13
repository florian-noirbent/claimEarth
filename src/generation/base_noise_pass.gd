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

	for row in range(context.profile.depth):
		var depth_ratio := float(row) / float(max(1, context.profile.depth - 1))
		for col in range(context.profile.width):
			var sample := noise.get_noise_2d(
				float(col) * context.profile.base_frequency_x,
				float(row) * context.profile.base_frequency_y
			)
			var cave_bias := lerpf(0.05, -0.12, depth_ratio)
			var adjusted := sample + cave_bias
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
