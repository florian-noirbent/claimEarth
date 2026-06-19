@tool
extends GenerationPassResource


@export var sand_min_row := 16
@export var sand_max_row := 36
@export var sand_min_radius_x := 6
@export var sand_max_radius_x := 10
@export var sand_min_radius_y := 4
@export var sand_max_radius_y := 6
@export var water_min_row := 28
@export var water_max_row := 70
@export var water_min_radius_x := 8
@export var water_max_radius_x := 14
@export var water_min_radius_y := 5
@export var water_max_radius_y := 8
@export var lava_min_row := 52
@export var lava_max_row := 110
@export var lava_min_radius_x := 7
@export var lava_max_radius_x := 12
@export var lava_min_radius_y := 4
@export var lava_max_radius_y := 7

func get_pass_type_name() -> String:
	return "Showcase Pockets"


func get_progress_label() -> String:
	return "Adding showcase pockets"


func _default_seed_key() -> String:
	return "showcase_pockets_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	var spawn_rect := _effective_spawn_rect(context)

	var sand_id := terrain_id(context.terrain_registry, "Sand")
	var water_id := terrain_id(context.terrain_registry, "Water")
	var lava_id := terrain_id(context.terrain_registry, "Lava")
	var air_id := terrain_id(context.terrain_registry, "Air")
	if sand_id < 0 or water_id < 0 or lava_id < 0 or air_id < 0:
		return false

	var rng := RandomNumberGenerator.new()
	rng.seed = SeedUtils.derive_seed(context.run_seed, "showcase_pockets_%s" % pass_seed_key)

	_place_blob(context, spawn_rect, rng, sand_id, sand_min_row, sand_max_row, sand_min_radius_x, sand_max_radius_x, sand_min_radius_y, sand_max_radius_y, 1)
	_place_blob(context, spawn_rect, rng, water_id, water_min_row, water_max_row, water_min_radius_x, water_max_radius_x, water_min_radius_y, water_max_radius_y, 2)
	_place_blob(context, spawn_rect, rng, lava_id, lava_min_row, lava_max_row, lava_min_radius_x, lava_max_radius_x, lava_min_radius_y, lava_max_radius_y, 3)
	return true


func _effective_spawn_rect(context: GenerationContext) -> Rect2i:
	if context.spawn_rect.size != Vector2i.ZERO:
		return context.spawn_rect
	var center_col := int(context.profile.width >> 1)
	var start_col := maxi(1, center_col - int(context.profile.spawn_width >> 1))
	return Rect2i(start_col, context.profile.spawn_margin_top, context.profile.spawn_width, context.profile.spawn_height)


func _place_blob(
	context: GenerationContext,
	spawn_rect: Rect2i,
	rng: RandomNumberGenerator,
	cell_id: int,
	min_row: int,
	max_row: int,
	min_radius_x: int,
	max_radius_x: int,
	min_radius_y: int,
	max_radius_y: int,
	salt: int
) -> void:
	var width := context.profile.width
	var left_margin := 6
	var right_margin := width - 7
	var left_side_limit := spawn_rect.position.x - 8
	var right_side_limit := spawn_rect.end.x + 8
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
			if spawn_rect.has_point(Vector2i(col, row)):
				continue
			var dx := float(col - center_col) / float(max(1, radius_x))
			var dy := float(row - center_row) / float(max(1, radius_y))
			var falloff := dx * dx + dy * dy
			if falloff > 1.0:
				continue
			if should_replace_cell(context, col, row, salt):
				context.world.set_committed_by_offset(col, row, cell_id)
