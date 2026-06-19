@tool
extends GenerationPassResource


@export_range(1, 8, 1) var octaves := 3
@export_range(0.001, 1.0, 0.001) var frequency_x := 0.075
@export_range(0.001, 1.0, 0.001) var frequency_y := 0.03
@export_range(0.0, 1.0, 0.001) var sand_threshold := 0.72
@export_range(0.0, 1.0, 0.001) var water_threshold := 0.81
@export_range(0.0, 1.0, 0.001) var lava_threshold := 0.89
@export_range(0.0, 1.0, 0.001) var water_depth_start_ratio := 0.16
@export_range(0.0, 1.0, 0.001) var lava_depth_start_ratio := 0.45

func get_pass_type_name() -> String:
	return "Pocket Noise"


func get_progress_label() -> String:
	return "Seeding hazard pockets"


func _default_seed_key() -> String:
	return "pocket_noise_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	var sand_id := terrain_id(context.terrain_registry, "Sand")
	var water_id := terrain_id(context.terrain_registry, "Water")
	var lava_id := terrain_id(context.terrain_registry, "Lava")
	var dirt_id := terrain_id(context.terrain_registry, "Dirt")
	var air_id := terrain_id(context.terrain_registry, "Air")

	var noise := FastNoiseLite.new()
	noise.seed = SeedUtils.derive_seed(context.run_seed, "pocket_noise")
	noise.frequency = 1.0
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.56
	noise.fractal_lacunarity = 2.1

	var blob_noise := FastNoiseLite.new()
	blob_noise.seed = SeedUtils.derive_seed(context.run_seed, "pocket_blob_noise")
	blob_noise.frequency = 1.0
	blob_noise.fractal_octaves = octaves + 1
	blob_noise.fractal_gain = 0.48
	blob_noise.fractal_lacunarity = 2.35

	for row in range(context.profile.depth):
		var depth_ratio := context.depth_ratio_for_row(row)
		for col in range(context.profile.width):
			var current_id := context.world.get_committed_by_offset(col, row)
			if current_id == air_id:
				continue

			var sample := noise.get_noise_2d(
				float(col) * frequency_x,
				float(row) * frequency_y
			)
			var blob_sample := blob_noise.get_noise_2d(
				float(col) * frequency_x * 0.72 + 11.0,
				float(row) * frequency_y * 0.84 + 73.0
			)
			var normalized := (sample * 0.58 + blob_sample * 0.42) * 0.5 + 0.5

			if normalized >= lava_threshold and depth_ratio >= lava_depth_start_ratio:
				if should_replace_cell(context, col, row, 1):
					context.world.set_committed_by_offset(col, row, lava_id)
			elif normalized >= water_threshold and depth_ratio >= water_depth_start_ratio:
				if should_replace_cell(context, col, row, 2):
					context.world.set_committed_by_offset(col, row, water_id)
			elif normalized >= sand_threshold and current_id == dirt_id:
				if should_replace_cell(context, col, row, 3):
					context.world.set_committed_by_offset(col, row, sand_id)

	return true
