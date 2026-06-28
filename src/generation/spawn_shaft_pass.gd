@tool
## Carves the initial safe shaft from generated terrain.
extends GenerationPassResource


@export_range(4, 256, 1) var shaft_target_depth := 100
@export_range(2.0, 10.0, 0.25) var shaft_width := 4.0
## Rows per horizontal cell; larger values make the shaft more vertical.
@export_range(0.5, 2.0, 0.05) var shaft_steepness := 1.0
## Minimum and maximum rows between deterministic random direction changes.
@export_range(4, 40, 1) var zigzag_min_rows := 10
@export_range(4, 64, 1) var zigzag_max_rows := 24
@export_range(0.0, 12.0, 0.5) var centerline_jitter := 4.0
@export_range(0.001, 0.2, 0.001) var centerline_frequency := 0.045
@export_range(0.0, 2.0, 0.05) var edge_jitter := 1.0
@export_range(0.001, 0.4, 0.001) var edge_frequency := 0.12
@export_range(0.0, 1.0, 0.01) var segment_erase_threshold := 0.22
@export_range(0.001, 0.2, 0.001) var segment_frequency := 0.055
@export_range(0, 16, 1) var protected_surface_rows := 5
@export_range(1, 16, 1) var safe_edge_margin := 3


func get_pass_type_name() -> String:
	return "Spawn Shaft"


func get_progress_label() -> String:
	return "Carving spawn shaft"


func _default_seed_key() -> String:
	return "spawn_shaft_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	var air_id := terrain_id(context.terrain_registry, "Air")
	var center_col := int(context.profile.width >> 1)
	var max_row := mini(shaft_target_depth, context.profile.depth - 3)
	if max_row < 0:
		return true

	var pass_key := pass_seed_key if not pass_seed_key.is_empty() else _default_seed_key()
	var direction := -1.0 if context.deterministic_sample(self, center_col, 0, 19) < 0.5 else 1.0
	var margin := mini(safe_edge_margin, maxi(0, int(context.profile.width / 2) - 1))
	var min_center := float(margin)
	var max_center := float(maxi(margin, context.profile.width - 1 - margin))
	var half_width := maxf(1.0, shaft_width * 0.5)
	var shaft_center := float(center_col)
	var next_turn_row := _next_zigzag_turn_row(context, center_col, 0, 0)

	var center_noise := FastNoiseLite.new()
	center_noise.seed = SeedUtils.derive_seed(context.run_seed, "spawn_center_%s" % pass_key)
	center_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	center_noise.frequency = 1.0
	center_noise.fractal_octaves = 3
	center_noise.fractal_gain = 0.52
	center_noise.fractal_lacunarity = 2.05

	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = SeedUtils.derive_seed(context.run_seed, "spawn_edge_%s" % pass_key)
	edge_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	edge_noise.frequency = 1.0
	edge_noise.fractal_octaves = 2
	edge_noise.fractal_gain = 0.58
	edge_noise.fractal_lacunarity = 2.2

	var segment_noise := FastNoiseLite.new()
	segment_noise.seed = SeedUtils.derive_seed(context.run_seed, "spawn_segments_%s" % pass_key)
	segment_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	segment_noise.frequency = 1.0
	segment_noise.fractal_octaves = 2
	segment_noise.fractal_gain = 0.5
	segment_noise.fractal_lacunarity = 2.0

	var surface_min_col := context.profile.width
	var surface_max_col := 0
	for row in range(0, max_row + 1):
		if row >= next_turn_row:
			var sampled_direction := -1.0 if context.deterministic_sample(self, center_col, row, 23) < 0.5 else 1.0
			direction = -direction if is_equal_approx(sampled_direction, direction) else sampled_direction
			next_turn_row = _next_zigzag_turn_row(context, center_col, row, 31)
		if row > 0:
			shaft_center += direction / maxf(0.1, shaft_steepness)
			if shaft_center <= min_center or shaft_center >= max_center:
				direction *= -1.0
				shaft_center = clampf(shaft_center, min_center, max_center)
		var center_offset := center_noise.get_noise_2d(13.0, float(row) * centerline_frequency) * centerline_jitter
		var row_center := clampf(shaft_center + center_offset, min_center, max_center)
		var row_min_col := context.profile.width
		var row_max_col := 0
		var segment_sample := segment_noise.get_noise_2d(29.0, float(row) * segment_frequency) * 0.5 + 0.5
		var should_carve_segment := row == 0 or row < protected_surface_rows or row == max_row or segment_sample >= segment_erase_threshold

		if should_carve_segment:
			for col in range(context.profile.width):
				var edge_sample := edge_noise.get_noise_2d(float(col) * edge_frequency, float(row) * edge_frequency)
				var edge_offset := edge_sample * edge_jitter
				var carve_radius := half_width + edge_offset
				if absf(float(col) - row_center) <= carve_radius:
					context.world.set_committed_by_offset(col, row, air_id)
					row_min_col = mini(row_min_col, col)
					row_max_col = maxi(row_max_col, col)

			if row_min_col == context.profile.width:
				var fallback_col := clampi(roundi(row_center), 0, context.profile.width - 1)
				context.world.set_committed_by_offset(fallback_col, row, air_id)
				row_min_col = fallback_col
				row_max_col = fallback_col
		if row == 0:
			surface_min_col = row_min_col
			surface_max_col = row_max_col

	context.spawn_rect = Rect2i(surface_min_col, 0, surface_max_col - surface_min_col + 1, max_row + 1)

	return true


func _next_zigzag_turn_row(context: GenerationContext, center_col: int, current_row: int, salt: int) -> int:
	var min_rows := mini(zigzag_min_rows, zigzag_max_rows)
	var max_rows := maxi(zigzag_min_rows, zigzag_max_rows)
	var span_range := maxi(1, max_rows - min_rows + 1)
	var sample := context.deterministic_sample(self, center_col, current_row, salt)
	return current_row + min_rows + mini(span_range - 1, int(floor(sample * float(span_range))))
