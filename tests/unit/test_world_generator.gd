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


func test_generated_world_has_sealed_boundaries_and_spawn_air() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var stone_id := registry.get_definition(1).stable_id
	var air_id := registry.get_definition(0).stable_id

	var result := generator.generate(profile, registry, 222)
	assert_not_null(result)

	for row in range(profile.depth):
		assert_eq(result.world.get_committed_by_offset(0, row), stone_id)
		assert_eq(result.world.get_committed_by_offset(profile.width - 1, row), stone_id)

	for row in range(profile.depth - 2, profile.depth):
		for col in range(profile.width):
			assert_eq(result.world.get_committed_by_offset(col, row), stone_id)

	for row in range(result.spawn_rect.position.y, result.spawn_rect.end.y):
		for col in range(result.spawn_rect.position.x, result.spawn_rect.end.x):
			assert_eq(result.world.get_committed_by_offset(col, row), air_id)


func test_generated_world_uses_only_registered_ids() -> void:
	var generator := WorldGenerator.new()
	var profile := load("res://config/generation/default_profile.tres") as GenerationProfile
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 999)
	assert_not_null(result)

	for cell_id in result.world.committed_cells:
		assert_true(registry.has_definition(cell_id), "Unknown terrain id %d" % cell_id)
