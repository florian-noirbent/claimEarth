extends GutTest


func test_terrain_catalog_loads_all_required_definitions() -> void:
	var catalog := FixtureLoader.terrain_catalog()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	assert_eq(registry.count(), 6)
	assert_true(registry.has_definition(0))
	assert_true(registry.has_definition(5))

	for definition in registry.all_definitions():
		assert_eq(definition.validate().size(), 0, definition.display_name)
		assert_not_null(definition.motion_behavior)
		assert_not_null(definition.hazard_behavior)
		assert_not_null(definition.blast_reaction)

	var metadata := CompiledTerrainData.compile(registry)
	assert_almost_eq(metadata.viscosity(FixtureLoader.terrain_id("Water")), 0.8, 0.001)
	assert_almost_eq(metadata.viscosity(FixtureLoader.terrain_id("Lava")), 4.0, 0.001)
	assert_almost_eq(metadata.viscosity(FixtureLoader.terrain_id("Air")), 0.0, 0.001)
	assert_almost_eq(metadata.viscosity(FixtureLoader.terrain_id("Stone")), 0.0, 0.001)


func test_item_catalog_loads_all_required_definitions() -> void:
	var catalog := FixtureLoader.item_catalog()
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	assert_eq(registry.count(), 8)

	var small_bomb := registry.get_definition(1)
	assert_eq(small_bomb.starting_inventory, 10)

	var large_bomb := registry.get_definition(2)
	assert_eq(large_bomb.starting_inventory, 2)

	var flag := registry.get_definition(3)
	assert_eq(flag.starting_inventory, 1)

	for stable_id in [4, 5, 6, 7, 8]:
		assert_eq(registry.get_definition(stable_id).starting_inventory, 0.0)


func test_duplicate_stable_ids_fail_validation() -> void:
	var terrain_a := TerrainDefinition.new()
	terrain_a.stable_id = 1
	terrain_a.display_name = "A"
	terrain_a.is_solid = true
	terrain_a.is_passable = false
	terrain_a.motion_behavior = StableMotionBehavior.new()
	terrain_a.hazard_behavior = NoHazardBehavior.new()
	terrain_a.blast_reaction = NoBlastReaction.new()

	var terrain_b := TerrainDefinition.new()
	terrain_b.stable_id = 1
	terrain_b.display_name = "B"
	terrain_b.is_solid = false
	terrain_b.is_passable = true
	terrain_b.motion_behavior = StableMotionBehavior.new()
	terrain_b.hazard_behavior = NoHazardBehavior.new()
	terrain_b.blast_reaction = NoBlastReaction.new()

	var catalog := TerrainCatalog.new()
	catalog.definitions = [terrain_a, terrain_b]

	var registry := TerrainRegistry.new()
	assert_false(registry.try_configure(catalog))
	assert_true("\n".join(registry.validation_errors).contains("duplicate terrain stable_id 1"))


func test_terrain_definition_rejects_invalid_viscosity() -> void:
	var definition := TerrainDefinition.new()
	definition.stable_id = 7
	definition.display_name = "Invalid fluid"
	definition.is_passable = true
	definition.motion_behavior = LiquidMotionBehavior.new()
	definition.motion_behavior.viscosity = -1.0
	definition.hazard_behavior = NoHazardBehavior.new()
	definition.blast_reaction = NoBlastReaction.new()

	assert_true("\n".join(definition.validate()).contains("viscosity"))
