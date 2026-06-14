class_name ShowcasePocketPass
extends GenerationPass


func get_name() -> String:
	return "showcase_pockets"


func apply(context: GenerationContext) -> bool:
	if context.spawn_rect.size == Vector2i.ZERO:
		return false

	var sand_id := _terrain_id(context.terrain_registry, "Sand")
	var water_id := _terrain_id(context.terrain_registry, "Water")
	var lava_id := _terrain_id(context.terrain_registry, "Lava")
	var air_id := _terrain_id(context.terrain_registry, "Air")
	if sand_id < 0 or water_id < 0 or lava_id < 0 or air_id < 0:
		return false

	var rng := RandomNumberGenerator.new()
	rng.seed = SeedUtils.derive_seed(context.run_seed, "showcase_pockets")

	_place_blob(context, rng, sand_id, 16, 36, 6, 10, 4, 6)
	_place_blob(context, rng, water_id, 28, 70, 8, 14, 5, 8)
	_place_blob(context, rng, lava_id, 52, 110, 7, 12, 4, 7)
	return true


func _place_blob(
	context: GenerationContext,
	rng: RandomNumberGenerator,
	cell_id: int,
	min_row: int,
	max_row: int,
	min_radius_x: int,
	max_radius_x: int,
	min_radius_y: int,
	max_radius_y: int
) -> void:
	var width := context.profile.width
	var left_margin := 6
	var right_margin := width - 7
	var left_side_limit := context.spawn_rect.position.x - 8
	var right_side_limit := context.spawn_rect.end.x + 8
	var place_left := rng.randf() < 0.5
	var min_col := left_margin if place_left else right_side_limit
	var max_col := left_side_limit if place_left else right_margin
	if max_col <= min_col:
		min_col = left_margin
		max_col = right_margin

	var center_col := rng.randi_range(min_col, max_col)
	var center_row := rng.randi_range(min_row, mini(max_row, context.profile.depth - 4))
	var radius_x := rng.randi_range(min_radius_x, max_radius_x)
	var radius_y := rng.randi_range(min_radius_y, max_radius_y)

	for row in range(maxi(1, center_row - radius_y), mini(context.profile.depth - 2, center_row + radius_y + 1)):
		for col in range(maxi(1, center_col - radius_x), mini(context.profile.width - 2, center_col + radius_x + 1)):
			if context.spawn_rect.has_point(Vector2i(col, row)):
				continue
			var dx := float(col - center_col) / float(max(1, radius_x))
			var dy := float(row - center_row) / float(max(1, radius_y))
			var falloff := dx * dx + dy * dy
			if falloff > 1.0:
				continue
			context.world.set_committed_by_offset(col, row, cell_id)


func _terrain_id(registry: TerrainRegistry, display_name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == display_name:
			return definition.stable_id
	return -1
