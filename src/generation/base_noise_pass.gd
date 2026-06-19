@tool
extends GenerationPassResource


@export_range(1, 8, 1) var octaves := 4
@export_range(0.001, 1.0, 0.001) var frequency_x := 0.045
@export_range(0.001, 1.0, 0.001) var frequency_y := 0.012
@export_range(0.0, 1.0, 0.001) var gain := 0.58
@export_range(-1.0, 1.0, 0.001) var cave_threshold := 0.26
@export_range(-1.0, 1.0, 0.001) var dirt_threshold := 0.5

func get_pass_type_name() -> String:
	return "Base Noise"


func get_progress_label() -> String:
	return "Sampling cave layers"


func _default_seed_key() -> String:
	return "base_noise_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	var air_id := terrain_id(context.terrain_registry, "Air")
	var stone_id := terrain_id(context.terrain_registry, "Stone")
	var dirt_id := terrain_id(context.terrain_registry, "Dirt")
	var noise := FastNoiseLite.new()
	noise.seed = SeedUtils.derive_seed(context.run_seed, "base_noise")
	noise.frequency = 1.0
	noise.fractal_octaves = octaves
	noise.fractal_gain = gain
	noise.fractal_lacunarity = 2.1

	var shape_noise := FastNoiseLite.new()
	shape_noise.seed = SeedUtils.derive_seed(context.run_seed, "shape_noise")
	shape_noise.frequency = 1.0
	shape_noise.fractal_octaves = octaves + 1
	shape_noise.fractal_gain = 0.52
	shape_noise.fractal_lacunarity = 2.25

	var strata_noise := FastNoiseLite.new()
	strata_noise.seed = SeedUtils.derive_seed(context.run_seed, "strata_noise")
	strata_noise.frequency = 1.0
	strata_noise.fractal_octaves = max(1, octaves - 2)
	strata_noise.fractal_gain = 0.42

	for row in range(context.profile.depth):
		var depth_ratio := context.depth_ratio_for_row(row)
		for col in range(context.profile.width):
			var primary_noise := noise.get_noise_2d(
				float(col) * frequency_x,
				float(row) * frequency_y
			)
			var blob_noise := shape_noise.get_noise_2d(
				float(col) * frequency_x * 0.62 + 18.0,
				float(row) * frequency_y * 0.78 + 41.0
			)
			var strata_noise_value := strata_noise.get_noise_2d(
				float(col) * frequency_x * 0.15,
				float(row) * frequency_y * 1.35
			)
			var horizontal_strata := sin(float(row) * 0.05 + float(col) * 0.012) * 0.03
			var cave_bias := lerpf(0.24, 0.16, depth_ratio)
			var adjusted := primary_noise * 0.5 + blob_noise * 0.3 + strata_noise_value * 0.17 + horizontal_strata + cave_bias
			var cell_id := stone_id
			if adjusted > dirt_threshold:
				cell_id = stone_id
			elif adjusted > cave_threshold:
				cell_id = dirt_id
			else:
				cell_id = air_id
			if should_replace_cell(context, col, row):
				context.world.set_committed_by_offset(col, row, cell_id)

	return true
