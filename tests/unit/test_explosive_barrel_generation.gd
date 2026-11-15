extends GutTest


const SEED_TEXT := "explosive-barrel-generation"


func _default_profile() -> GenerationProfile:
	return load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile


func _barrel_pass(profile: GenerationProfile) -> GenerationPassResource:
	for generation_pass in profile.passes:
		if generation_pass.get("item_definition") is ExplosiveBarrelDefinition:
			return generation_pass
	return null


func test_default_profile_places_deterministic_barrels_in_carved_chambers() -> void:
	var profile := _default_profile()
	var barrel_pass := _barrel_pass(profile)
	assert_not_null(barrel_pass)
	if barrel_pass == null:
		return
	var registry := FixtureLoader.terrain_registry()
	var seed := SeedUtils.seed_from_text(SEED_TEXT)
	var generator := WorldGenerator.new()
	var result := generator.generate(profile, registry, seed)
	var repeat := generator.generate(profile, registry, seed)
	assert_not_null(result)
	assert_not_null(repeat)
	assert_gt(result.explosive_barrel_spawns.size(), 0)
	assert_eq(_spawn_signature(result.explosive_barrel_spawns), _spawn_signature(repeat.explosive_barrel_spawns))
	assert_eq(result.world_hash, repeat.world_hash)

	var air_id := FixtureLoader.terrain_id("Air")
	var anchors := {}
	for spawn in result.explosive_barrel_spawns:
		var definition := spawn.definition
		assert_not_null(definition)
		var anchor := spawn.anchor_offset
		assert_false(anchors.has(anchor), "Barrel anchors are reserved")
		anchors[anchor] = true
		var depth_ratio := float(anchor.y) / float(profile.depth - 1)
		assert_true(depth_ratio >= barrel_pass.min_depth_ratio and depth_ratio <= barrel_pass.max_depth_ratio)
		var clearance := definition.required_edge_clearance()
		assert_true(anchor.x >= clearance and anchor.x <= profile.width - 1 - clearance)
		assert_true(anchor.y >= clearance and anchor.y <= profile.depth - 1 - clearance)
		for cell in _upper_chamber_cells(anchor, definition.chamber_radius):
			assert_eq(result.world.get_committed_by_offset(cell.x, cell.y), air_id, "%s must be carved for %s" % [cell, anchor])


func test_barrel_pass_leaves_chest_and_geode_spawns_unchanged() -> void:
	var profile := _default_profile()
	var registry := FixtureLoader.terrain_registry()
	var generator := WorldGenerator.new()
	var seed := SeedUtils.seed_from_text(SEED_TEXT)
	var with_barrels := generator.generate(profile, registry, seed)
	var without_profile := _default_profile()
	_barrel_pass(without_profile).enabled = false
	var without_barrels := generator.generate(without_profile, registry, seed)
	assert_not_null(with_barrels)
	assert_not_null(without_barrels)
	assert_eq(without_barrels.explosive_barrel_spawns.size(), 0)
	assert_gt(with_barrels.item_chest_spawns.size(), 0)
	assert_gt(with_barrels.perk_geode_spawns.size(), 0)
	assert_eq(_chest_signature(with_barrels.item_chest_spawns), _chest_signature(without_barrels.item_chest_spawns))
	assert_eq(_chest_signature(with_barrels.perk_geode_spawns), _chest_signature(without_barrels.perk_geode_spawns))


func test_barrel_rests_at_its_generated_anchor_without_overlapping_terrain() -> void:
	var profile := _default_profile()
	var registry := FixtureLoader.terrain_registry()
	var result := WorldGenerator.new().generate(profile, registry, SeedUtils.seed_from_text(SEED_TEXT))
	assert_not_null(result)
	var query := TerrainCollisionQuery.new()
	query.configure(result.world, CompiledTerrainData.compile(registry), 16.0)
	for spawn in result.explosive_barrel_spawns:
		var barrel := spawn.definition.barrel_scene.instantiate() as ExplosiveBarrel
		add_child_autofree(barrel)
		barrel.configure(spawn, 16.0, false)
		var anchor_center := HexMetrics.center_for_offset(spawn.anchor_offset.x, spawn.anchor_offset.y, 16.0)
		assert_eq(barrel.global_position.x, anchor_center.x)
		assert_eq(HexMetrics.offset_for_world(barrel.global_position, 16.0).x, spawn.anchor_offset.x)
		assert_false(
			query.circle_overlaps_solid(barrel.global_position, barrel.body_radius() - 0.01),
			"Barrel at %s must not start inside terrain" % spawn.anchor_offset
		)


func test_barrel_definition_records_typed_spawns_with_the_pass_seed() -> void:
	var profile := GenerationProfile.new()
	profile.width = 40
	profile.depth = 80
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	var context := GenerationContext.new(
		profile,
		91,
		FixtureLoader.terrain_registry(),
		WorldGrid.new(profile.create_dimensions(), FixtureLoader.terrain_id("Stone"))
	)
	var anchor := Vector2i(10, 20)
	assert_true(definition.prepare_terrain(context, anchor))
	assert_true(definition.record_spawn(context, anchor, 1234))
	assert_eq(context.explosive_barrel_spawns.size(), 1)
	assert_eq(context.item_chest_spawns.size(), 0)
	assert_eq(context.perk_geode_spawns.size(), 0)
	var spawn := context.explosive_barrel_spawns[0]
	assert_eq(spawn.anchor_offset, anchor)
	assert_same(spawn.definition, definition)
	assert_eq(spawn.spawn_seed, 1234)
	var air_id := FixtureLoader.terrain_id("Air")
	var stone_id := FixtureLoader.terrain_id("Stone")
	var carved := _upper_chamber_cells(anchor, definition.chamber_radius)
	for row in range(profile.depth):
		for col in range(profile.width):
			var expected := air_id if carved.has(Vector2i(col, row)) else stone_id
			assert_eq(context.world.get_committed_by_offset(col, row), expected)


## Regression: barrels were placed on lava-lined or unsupported anchors and detonated in the first frames of a run.
func test_default_generation_places_barrels_on_solid_ground_clear_of_detonating_terrain() -> void:
	var profile := _default_profile()
	var registry := FixtureLoader.terrain_registry()
	var generator := WorldGenerator.new()
	for seed_text in [SEED_TEXT, "barrel-placement-1", "barrel-placement-2", "barrel-placement-3"]:
		var result := generator.generate(profile, registry, SeedUtils.seed_from_text(seed_text))
		assert_not_null(result)
		assert_gt(result.explosive_barrel_spawns.size(), 0)
		for spawn in result.explosive_barrel_spawns:
			var definition := spawn.definition
			var anchor_hex := HexCoord.from_offset_odd_q(spawn.anchor_offset.x, spawn.anchor_offset.y)
			for floor_delta: HexCoord in [HexCoord.new(0, 1), HexCoord.new(-1, 1), HexCoord.new(1, 0)]:
				var floor_cell := anchor_hex.add(floor_delta).to_offset_odd_q()
				assert_true(
					registry.get_definition(result.world.get_committed_by_offset(floor_cell.x, floor_cell.y)).is_solid,
					"%s: barrel at %s needs solid ground at %s" % [seed_text, spawn.anchor_offset, floor_cell]
				)
			for cell in _cells_within(spawn.anchor_offset, definition.detonating_terrain_clearance):
				if not result.world.dimensions.is_in_bounds_offset(cell.x, cell.y):
					continue
				var terrain := registry.get_definition(result.world.get_committed_by_offset(cell.x, cell.y))
				for terrain_tag in definition.detonating_terrain_tags:
					assert_false(
						terrain.perk_tags.has(terrain_tag),
						"%s: barrel at %s starts beside %s at %s" % [seed_text, spawn.anchor_offset, terrain.display_name, cell]
					)


func test_barrel_rejects_anchors_without_a_solid_cradle_or_near_detonating_terrain() -> void:
	var profile := GenerationProfile.new()
	profile.width = 40
	profile.depth = 40
	var definition := (load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition).duplicate() as ExplosiveBarrelDefinition
	var air_id := FixtureLoader.terrain_id("Air")
	var stone_id := FixtureLoader.terrain_id("Stone")
	var context := GenerationContext.new(
		profile,
		7,
		FixtureLoader.terrain_registry(),
		WorldGrid.new(profile.create_dimensions(), stone_id)
	)
	var anchor := Vector2i(20, 20)
	var anchor_hex := HexCoord.from_offset_odd_q(anchor.x, anchor.y)
	assert_true(definition.accepts_anchor(context, anchor), "Solid surroundings accept the anchor")

	for floor_delta: HexCoord in [HexCoord.new(0, 1), HexCoord.new(-1, 1), HexCoord.new(1, 0)]:
		var floor_cell := anchor_hex.add(floor_delta).to_offset_odd_q()
		context.world.set_committed_by_offset(floor_cell.x, floor_cell.y, air_id)
		assert_false(definition.accepts_anchor(context, anchor), "Missing support at %s rejects the anchor" % floor_cell)
		definition.requires_floor_support = false
		assert_true(definition.accepts_anchor(context, anchor))
		definition.requires_floor_support = true
		context.world.set_committed_by_offset(floor_cell.x, floor_cell.y, stone_id)

	for terrain_name in ["Lava", "Sulfuric Acid"]:
		var terrain_id := FixtureLoader.terrain_id(terrain_name)
		var near := anchor_hex.add(HexCoord.new(definition.detonating_terrain_clearance, 0)).to_offset_odd_q()
		var far := anchor_hex.add(HexCoord.new(definition.detonating_terrain_clearance + 1, 0)).to_offset_odd_q()
		context.world.set_committed_by_offset(far.x, far.y, terrain_id)
		assert_true(definition.accepts_anchor(context, anchor), "%s beyond the clearance is allowed" % terrain_name)
		context.world.set_committed_by_offset(near.x, near.y, terrain_id)
		assert_false(definition.accepts_anchor(context, anchor), "%s within the clearance rejects the anchor" % terrain_name)
		context.world.set_committed_by_offset(near.x, near.y, stone_id)
		context.world.set_committed_by_offset(far.x, far.y, stone_id)


func test_generated_item_pass_probes_past_rejected_anchors_deterministically() -> void:
	var profile := GenerationProfile.new()
	profile.width = 12
	profile.depth = 40
	var stone_id := FixtureLoader.terrain_id("Stone")
	var lava_id := FixtureLoader.terrain_id("Lava")
	var generation_pass := _barrel_pass(_default_profile())
	generation_pass.set("area_columns", 1)
	generation_pass.set("area_height_rows", 40)
	generation_pass.set("area_spawn_chance", 1.0)
	generation_pass.set("column_vertical_offset_rows", 0)
	generation_pass.min_depth_ratio = 0.0
	generation_pass.max_depth_ratio = 1.0
	var definition := generation_pass.get("item_definition") as ExplosiveBarrelDefinition
	var anchors: Array[Vector2i] = []
	for _attempt in 2:
		var world := WorldGrid.new(profile.create_dimensions(), stone_id)
		# Only the rows beyond the clearance below this lava band can hold a barrel.
		for row in range(0, 30):
			for col in range(profile.width):
				world.set_committed_by_offset(col, row, lava_id)
		var context := GenerationContext.new(profile, 3, FixtureLoader.terrain_registry(), world)
		assert_true(generation_pass.apply(context))
		assert_eq(context.explosive_barrel_spawns.size(), 1)
		if context.explosive_barrel_spawns.is_empty():
			return
		anchors.append(context.explosive_barrel_spawns[0].anchor_offset)
	assert_eq(anchors[0], anchors[1], "Skipping rejected candidates stays deterministic")
	assert_gt(anchors[0].y, 29 + definition.detonating_terrain_clearance, "The pass skipped every lava-adjacent candidate")


func _cells_within(anchor: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center := HexCoord.from_offset_odd_q(anchor.x, anchor.y)
	for delta_q in range(-radius, radius + 1):
		for delta_r in range(maxi(-radius, -delta_q - radius), mini(radius, -delta_q + radius) + 1):
			cells.append(center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q())
	return cells


func _upper_chamber_cells(anchor: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center := HexCoord.from_offset_odd_q(anchor.x, anchor.y)
	var center_y := center.to_world_position(1.0).y
	for delta_q in range(-radius, radius + 1):
		for delta_r in range(maxi(-radius, -delta_q - radius), mini(radius, -delta_q + radius) + 1):
			var cell := center.add(HexCoord.new(delta_q, delta_r))
			if cell.to_world_position(1.0).y <= center_y + 0.0001:
				cells.append(cell.to_offset_odd_q())
	return cells


func _spawn_signature(spawns: Array[GeneratedExplosiveBarrelSpawn]) -> PackedStringArray:
	var result := PackedStringArray()
	for spawn in spawns:
		result.append("%d,%d:%d" % [spawn.anchor_offset.x, spawn.anchor_offset.y, spawn.spawn_seed])
	return result


func _chest_signature(spawns: Array[GeneratedItemChestSpawn]) -> PackedStringArray:
	var result := PackedStringArray()
	for spawn in spawns:
		result.append("%d,%d:%d" % [spawn.anchor_offset.x, spawn.anchor_offset.y, spawn.choice_seed])
	return result
