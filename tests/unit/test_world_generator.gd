extends GutTest


func test_same_seed_and_profile_produce_same_world_hash() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))

	var first := generator.generate(profile, registry, 12345)
	var second := generator.generate(profile, registry, 12345)

	assert_not_null(first)
	assert_not_null(second)
	assert_eq(first.world_hash, second.world_hash)
	assert_eq(first.spawn_rect, second.spawn_rect)


func test_generated_world_has_sealed_bottom_and_spawn_air() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var stone_id := registry.get_definition(1).stable_id
	var air_id := registry.get_definition(0).stable_id

	var result := generator.generate(profile, registry, 222)
	assert_not_null(result)
	assert_eq(result.spawn_rect.position.y, 0)
	assert_eq(result.spawn_rect.size.y, 4)

	for row in range(profile.depth - 2, profile.depth):
		for col in range(profile.width):
			assert_eq(result.world.get_committed_by_offset(col, row), stone_id)

	for row in range(result.spawn_rect.position.y, result.spawn_rect.end.y):
		for col in range(result.spawn_rect.position.x, result.spawn_rect.end.x):
			if row == result.spawn_rect.end.y - 1 and col > result.spawn_rect.position.x and col < result.spawn_rect.end.x - 1:
				continue
			assert_eq(result.world.get_committed_by_offset(col, row), air_id)

	var dirt_id := registry.get_definition(2).stable_id
	for col in range(result.spawn_rect.position.x + 1, result.spawn_rect.end.x - 1):
		assert_eq(result.world.get_committed_by_offset(col, result.spawn_rect.end.y - 1), dirt_id)

	var spawn_col := result.spawn_rect.position.x + int(result.spawn_rect.size.x / 2)
	for row in range(0, result.spawn_rect.end.y - 1):
		assert_eq(result.world.get_committed_by_offset(spawn_col, row), air_id)


func test_generated_world_uses_only_registered_ids() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 999)
	assert_not_null(result)

	for cell_id in result.world.committed_cells:
		assert_true(registry.has_definition(cell_id), "Unknown terrain id %d" % cell_id)


func test_generated_world_air_ratio_stays_in_target_band() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 31415)
	assert_not_null(result)

	var air_ratio := float(result.world.count_committed(0)) / float(result.world.dimensions.cell_count())
	assert_true(air_ratio >= 0.14)
	assert_true(air_ratio <= 0.42)


func test_generated_world_includes_secondary_material_pockets() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 31415)
	assert_not_null(result)

	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Sand")), 500)
	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Water")), 500)
	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Lava")), 100)


func test_generated_world_shows_secondary_materials_in_upper_play_band() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, SeedUtils.seed_from_text("live-materials"))
	assert_not_null(result)

	var shallow_counts := {
		"Sand": 0,
		"Water": 0,
		"Lava": 0,
	}
	for row in range(0, 96):
		for col in range(profile.width):
			var definition := registry.get_definition(result.world.get_committed_by_offset(col, row))
			if shallow_counts.has(definition.display_name):
				shallow_counts[definition.display_name] += 1

	assert_gt(shallow_counts["Sand"], 0)
	assert_gt(shallow_counts["Water"], 0)
	assert_gt(shallow_counts["Lava"], 0)
