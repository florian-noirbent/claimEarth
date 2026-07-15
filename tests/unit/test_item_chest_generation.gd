extends GutTest


const GeneratedItemPassScript = preload("res://src/generation/generated_item_pass.gd")


class RecordingItemDefinition extends GeneratedItemPlacementDefinition:
	var anchors: Array[Vector2i] = []
	var prepare_count := 0

	func prepare_terrain(_context: GenerationContext, _anchor: Vector2i) -> bool:
		prepare_count += 1
		return true

	func record_spawn(_context: GenerationContext, anchor: Vector2i, _spawn_seed: int) -> bool:
		anchors.append(anchor)
		return true


func test_default_generation_places_deterministic_stratified_chests_and_carves_chambers() -> void:
	var profile := load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile
	var registry := FixtureLoader.terrain_registry()
	var generator := WorldGenerator.new()
	var seed := SeedUtils.seed_from_text("item-chest-generation")
	var result := generator.generate(profile, registry, seed)
	var repeat := generator.generate(profile, registry, seed)
	var baseline_profile := profile.duplicate(true) as GenerationProfile
	for generation_pass in baseline_profile.passes:
		if generation_pass.get_script() != null and String(generation_pass.get_script().resource_path).ends_with("generated_item_pass.gd"):
			generation_pass.enabled = false
	var baseline := generator.generate(baseline_profile, registry, seed)
	assert_not_null(result)
	assert_not_null(repeat)
	assert_eq(result.item_chest_spawns.size(), 19)
	assert_eq(repeat.item_chest_spawns.size(), 19)
	assert_eq(_spawn_signature(result.item_chest_spawns), _spawn_signature(repeat.item_chest_spawns))

	var air_id := FixtureLoader.terrain_id("Air")
	var lava_id := FixtureLoader.terrain_id("Lava")
	for spawn in result.item_chest_spawns:
		var depth_ratio := float(spawn.anchor_offset.y) / float(profile.depth - 1)
		assert_true(depth_ratio >= 0.05 and depth_ratio <= 0.9)
		assert_true(_chamber_is_in_bounds(result.world, spawn.anchor_offset, 3))
	_assert_chambers_only_carve_their_upper_halves(
		result.world,
		baseline.world,
		result.item_chest_spawns,
		3,
		air_id
	)

	for row in range(profile.depth - 2, profile.depth):
		for col in range(profile.width):
			assert_eq(result.world.get_committed_by_offset(col, row), lava_id)


func test_area_grid_counts_columns_offsets_and_clipped_partial_areas() -> void:
	assert_eq(_recorded_anchors(1, 50, 25, 1.0, 11).size(), 9)
	var staggered := _recorded_anchors(2, 50, 25, 1.0, 11)
	assert_eq(staggered.size(), 19)
	var first_column := staggered.filter(func(anchor: Vector2i) -> bool: return anchor.x < 50)
	var second_column := staggered.filter(func(anchor: Vector2i) -> bool: return anchor.x >= 50)
	assert_eq(first_column.size(), 9)
	assert_eq(second_column.size(), 10)
	assert_true(second_column.any(func(anchor: Vector2i) -> bool: return anchor.y <= 50))
	assert_true(second_column.any(func(anchor: Vector2i) -> bool: return anchor.y >= 451))
	assert_eq(_recorded_anchors(3, 50, 25, 1.0, 11).size(), 28)
	assert_eq(_recorded_anchors(2, 100, 0, 1.0, 11).size(), 10)


func test_area_chance_is_deterministic_and_independent_per_area() -> void:
	assert_true(_recorded_anchors(2, 50, 25, 0.0, 22).is_empty())
	var first := _recorded_anchors(2, 50, 25, 0.5, 22)
	var repeat := _recorded_anchors(2, 50, 25, 0.5, 22)
	var other_seed := _recorded_anchors(2, 50, 25, 0.5, 23)
	assert_eq(first, repeat)
	assert_ne(first, other_seed)
	assert_true(first.size() > 0 and first.size() < 19)


func test_close_anchors_are_allowed_and_exact_anchors_are_reserved() -> void:
	var profile := GenerationProfile.new()
	profile.width = 1
	profile.depth = 4
	var definition := RecordingItemDefinition.new()
	var item_pass = GeneratedItemPassScript.new()
	item_pass.item_definition = definition
	item_pass.pass_seed_key = "close-items"
	item_pass.area_columns = 1
	item_pass.area_height_rows = 1
	item_pass.column_vertical_offset_rows = 0
	item_pass.area_spawn_chance = 1.0
	item_pass.min_depth_ratio = 0.0
	item_pass.max_depth_ratio = 1.0
	var context := GenerationContext.new(
		profile,
		33,
		FixtureLoader.terrain_registry(),
		WorldGrid.new(profile.create_dimensions(), 0)
	)
	assert_true(item_pass.apply(context))
	assert_eq(definition.anchors, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)])
	for index in range(1, definition.anchors.size()):
		var previous := HexCoord.from_offset_odd_q(definition.anchors[index - 1].x, definition.anchors[index - 1].y)
		var current := HexCoord.from_offset_odd_q(definition.anchors[index].x, definition.anchors[index].y)
		assert_eq(previous.distance_to(current), 1)
	assert_eq(definition.prepare_count, 4)
	assert_true(item_pass.apply(context))
	assert_eq(definition.anchors.size(), 4, "A second identical pass cannot reuse the same four anchors.")


func _recorded_anchors(
	columns: int,
	height_rows: int,
	offset_rows: int,
	chance: float,
	seed: int
) -> Array[Vector2i]:
	var profile := GenerationProfile.new()
	profile.width = 100
	profile.depth = 512
	var definition := RecordingItemDefinition.new()
	var item_pass = GeneratedItemPassScript.new()
	item_pass.item_definition = definition
	item_pass.pass_seed_key = "recording-items"
	item_pass.area_columns = columns
	item_pass.area_height_rows = height_rows
	item_pass.column_vertical_offset_rows = offset_rows
	item_pass.area_spawn_chance = chance
	item_pass.min_depth_ratio = 0.05
	item_pass.max_depth_ratio = 0.9
	var context := GenerationContext.new(
		profile,
		seed,
		FixtureLoader.terrain_registry(),
		WorldGrid.new(profile.create_dimensions(), 0)
	)
	assert_true(item_pass.apply(context))
	assert_eq(definition.prepare_count, definition.anchors.size())
	return definition.anchors


func _spawn_signature(spawns: Array[GeneratedItemChestSpawn]) -> PackedStringArray:
	var result := PackedStringArray()
	for spawn in spawns:
		result.append("%d,%d:%d" % [spawn.anchor_offset.x, spawn.anchor_offset.y, spawn.choice_seed])
	return result


func _chamber_is_in_bounds(world: WorldGrid, anchor: Vector2i, radius: int) -> bool:
	var center := HexCoord.from_offset_odd_q(anchor.x, anchor.y)
	for delta_q in range(-radius, radius + 1):
		var min_delta_r := maxi(-radius, -delta_q - radius)
		var max_delta_r := mini(radius, -delta_q + radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var offset := center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q()
			if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
				return false
	return true


func _assert_chambers_only_carve_their_upper_halves(
	world: WorldGrid,
	baseline: WorldGrid,
	spawns: Array[GeneratedItemChestSpawn],
	radius: int,
	air_id: int
) -> void:
	var carved_offsets := {}
	for spawn in spawns:
		var center := HexCoord.from_offset_odd_q(spawn.anchor_offset.x, spawn.anchor_offset.y)
		var center_y := center.to_world_position(1.0).y
		for delta_q in range(-radius, radius + 1):
			var min_delta_r := maxi(-radius, -delta_q - radius)
			var max_delta_r := mini(radius, -delta_q + radius)
			for delta_r in range(min_delta_r, max_delta_r + 1):
				var cell := center.add(HexCoord.new(delta_q, delta_r))
				if cell.to_world_position(1.0).y <= center_y + 0.0001:
					carved_offsets[cell.to_offset_odd_q()] = true
	var mismatch_count := 0
	var first_mismatch := ""
	for row in range(world.dimensions.depth):
		for col in range(world.dimensions.width):
			var offset := Vector2i(col, row)
			var expected := air_id if carved_offsets.has(offset) else baseline.get_committed_by_offset(col, row)
			var actual := world.get_committed_by_offset(col, row)
			if actual != expected:
				mismatch_count += 1
				if first_mismatch.is_empty():
					first_mismatch = "%s expected %d but found %d" % [offset, expected, actual]
	assert_eq(mismatch_count, 0, first_mismatch)
