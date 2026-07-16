@tool
## Overrides cells in a configured depth band with one terrain type.
extends GenerationPassResource


@export var fill_terrain: TerrainDefinition


func get_pass_type_name() -> String:
	return "Fill"


func get_progress_label() -> String:
	if fill_terrain == null:
		return "Filling map"
	return "Filling with %s" % fill_terrain.display_name


func _default_seed_key() -> String:
	return "fill_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	if fill_terrain == null or not context.terrain_registry.has_definition(fill_terrain.stable_id):
		return false

	var row_range := target_row_range(context.profile.depth)
	for row in range(row_range.x, row_range.y):
		for col in range(context.profile.width):
			if should_replace_cell(context, col, row):
				context.world.set_committed_by_offset(col, row, fill_terrain.stable_id)

	return true


## Returns a half-open row range so narrow depth bands do not scan the whole map.
func target_row_range(depth: int) -> Vector2i:
	if depth <= 0:
		return Vector2i.ZERO

	var low_ratio := clampf(minf(min_depth_ratio, max_depth_ratio), 0.0, 1.0)
	var high_ratio := clampf(maxf(min_depth_ratio, max_depth_ratio), 0.0, 1.0)
	if depth == 1:
		return Vector2i(0, 1) if low_ratio <= 0.0 else Vector2i.ZERO

	var last_row := depth - 1
	var first_row := clampi(int(ceil(low_ratio * float(last_row))), 0, last_row)
	var end_row := clampi(int(floor(high_ratio * float(last_row))) + 1, 0, depth)
	return Vector2i(first_row, maxi(first_row, end_row))
