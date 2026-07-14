@tool
## Places one configured world-item kind through deterministic jittered grid areas.
extends GenerationPassResource


@export var item_definition: GeneratedItemPlacementDefinition
@export_range(1, 3, 1) var area_columns := 2
@export_range(1, 4096, 1) var area_height_rows := 50
@export_range(0, 4096, 1) var column_vertical_offset_rows := 25
@export_range(0.0, 1.0, 0.01) var area_spawn_chance := 1.0


func get_pass_type_name() -> String:
	return "Generated Item"


func get_progress_label() -> String:
	return "Placing generated items"


func _default_seed_key() -> String:
	return "generated_item_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	if context == null or item_definition == null or not item_definition.validate().is_empty():
		return false
	if area_columns < 1 or area_columns > 3 or area_height_rows <= 0:
		return false
	if column_vertical_offset_rows < 0 or area_spawn_chance < 0.0 or area_spawn_chance > 1.0:
		return false
	if area_spawn_chance <= 0.0:
		return true
	var depth_band := _depth_band(context)
	if depth_band.x > depth_band.y:
		return true
	var edge_clearance := maxi(0, item_definition.required_edge_clearance())
	for column_index in range(area_columns):
		if not _place_column_areas(context, column_index, depth_band, edge_clearance):
			return false
	return true


func _place_column_areas(
	context: GenerationContext,
	column_index: int,
	depth_band: Vector2i,
	edge_clearance: int
) -> bool:
	var raw_left := int(float(column_index * context.profile.width) / float(area_columns))
	var raw_right := int(float((column_index + 1) * context.profile.width) / float(area_columns)) - 1
	var left := maxi(raw_left, edge_clearance)
	var right := mini(raw_right, context.profile.width - 1 - edge_clearance)
	if left > right:
		return true
	var shifted_start := depth_band.x + column_index * column_vertical_offset_rows
	var steps_back := ceili(float(shifted_start - depth_band.x) / float(area_height_rows))
	var area_start := shifted_start - steps_back * area_height_rows
	while area_start + area_height_rows - 1 < depth_band.x:
		area_start += area_height_rows
	while area_start <= depth_band.y:
		var clipped_top := maxi(area_start, depth_band.x)
		var clipped_bottom := mini(area_start + area_height_rows - 1, depth_band.y)
		var top := maxi(clipped_top, edge_clearance)
		var bottom := mini(clipped_bottom, context.profile.depth - 1 - edge_clearance)
		if top <= bottom and _area_spawns(context.run_seed, column_index, area_start):
			var area_rect := Rect2i(left, top, right - left + 1, bottom - top + 1)
			var anchor := _reserve_random_anchor(context, area_rect, column_index, area_start)
			if anchor.x >= 0:
				if not item_definition.prepare_terrain(context, anchor):
					context.release_generated_item_anchor(anchor)
					return false
				var spawn_seed := SeedUtils.derive_seed(
					context.run_seed,
					"%s:spawn:%d:%d:%d:%d" % [
						pass_seed_key,
						column_index,
						area_start,
						anchor.x,
						anchor.y,
					]
				)
				if not item_definition.record_spawn(context, anchor, spawn_seed):
					context.release_generated_item_anchor(anchor)
					return false
		area_start += area_height_rows
	return true


func _depth_band(context: GenerationContext) -> Vector2i:
	var last_row := context.profile.depth - 1
	var low_ratio := clampf(minf(min_depth_ratio, max_depth_ratio), 0.0, 1.0)
	var high_ratio := clampf(maxf(min_depth_ratio, max_depth_ratio), 0.0, 1.0)
	var first_row := clampi(ceili(low_ratio * float(last_row)), 0, last_row)
	var final_row := clampi(floori(high_ratio * float(last_row)), 0, last_row)
	while first_row <= final_row and context.depth_blend_weight(self, first_row) <= 0.0:
		first_row += 1
	while final_row >= first_row and context.depth_blend_weight(self, final_row) <= 0.0:
		final_row -= 1
	return Vector2i(first_row, final_row)


func _area_spawns(run_seed: int, column_index: int, area_start: int) -> bool:
	if area_spawn_chance >= 1.0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = SeedUtils.derive_seed(
		run_seed,
		"%s:chance:%d:%d" % [pass_seed_key, column_index, area_start]
	)
	return rng.randf() < area_spawn_chance


func _reserve_random_anchor(
	context: GenerationContext,
	area_rect: Rect2i,
	column_index: int,
	area_start: int
) -> Vector2i:
	var candidate_count := area_rect.size.x * area_rect.size.y
	if candidate_count <= 0:
		return Vector2i(-1, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = SeedUtils.derive_seed(
		context.run_seed,
		"%s:anchor:%d:%d" % [pass_seed_key, column_index, area_start]
	)
	var first_index := rng.randi_range(0, candidate_count - 1)
	for probe in range(candidate_count):
		var candidate_index := (first_index + probe) % candidate_count
		var anchor := Vector2i(
			area_rect.position.x + candidate_index % area_rect.size.x,
			area_rect.position.y + int(candidate_index / area_rect.size.x)
		)
		if context.try_reserve_generated_item_anchor(anchor):
			return anchor
	return Vector2i(-1, -1)
