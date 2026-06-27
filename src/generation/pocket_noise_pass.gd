@tool
## Places deterministic material pockets within configured depth bands.
extends GenerationPassResource


enum HazardType {
	SAND,
	WATER,
	LAVA,
}


@export_range(1, 8, 1) var octaves := 3
@export_range(0.001, 1.0, 0.001) var frequency_x := 0.075
@export_range(0.001, 1.0, 0.001) var frequency_y := 0.03
@export_range(0.0, 1.0, 0.001) var gain := 0.56
@export var hazard_type := HazardType.SAND
@export_range(0.0, 1.0, 0.001) var placement_threshold := 0.72

func get_pass_type_name() -> String:
	return "Hazard Pocket"


func get_progress_label() -> String:
	return "Seeding %s pockets" % _hazard_type_display_name()


func _default_seed_key() -> String:
	return "hazard_pocket_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	var terrain_name := _hazard_type_display_name()
	var hazard_id := terrain_id(context.terrain_registry, terrain_name)
	if hazard_id < 0:
		return false
	var pass_key := pass_seed_key if not pass_seed_key.is_empty() else _default_seed_key()

	var noise := FastNoiseLite.new()
	noise.seed = SeedUtils.derive_seed(context.run_seed, "pocket_noise_%s" % pass_key)
	noise.frequency = 1.0
	noise.fractal_octaves = octaves
	noise.fractal_gain = gain
	noise.fractal_lacunarity = 2.1

	var blob_noise := FastNoiseLite.new()
	blob_noise.seed = SeedUtils.derive_seed(context.run_seed, "pocket_blob_noise_%s" % pass_key)
	blob_noise.frequency = 1.0
	blob_noise.fractal_octaves = octaves + 1
	blob_noise.fractal_gain = clampf(gain - 0.08, 0.0, 1.0)
	blob_noise.fractal_lacunarity = 2.35

	for row in range(context.profile.depth):
		for col in range(context.profile.width):
			var sample := noise.get_noise_2d(
				float(col) * frequency_x,
				float(row) * frequency_y
			)
			var blob_sample := blob_noise.get_noise_2d(
				float(col) * frequency_x * 0.72 + 11.0,
				float(row) * frequency_y * 0.84 + 73.0
			)
			var normalized := (sample * 0.58 + blob_sample * 0.42) * 0.5 + 0.5

			if normalized >= placement_threshold and should_replace_cell(context, col, row, hazard_type + 1):
				context.world.set_committed_by_offset(col, row, hazard_id)

	return true


func _hazard_type_display_name() -> String:
	match hazard_type:
		HazardType.WATER:
			return "Water"
		HazardType.LAVA:
			return "Lava"
		_:
			return "Sand"
