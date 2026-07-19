extends GutTest


func test_terrain_catalog_loads_all_required_definitions() -> void:
	var catalog := FixtureLoader.terrain_catalog()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	assert_eq(registry.count(), 9)
	assert_true(registry.has_definition(0))
	assert_true(registry.has_definition(5))
	assert_true(registry.has_definition(8))
	assert_eq(registry.contact_reactions().size(), 5)

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
	assert_eq(metadata.normal_quantity(FixtureLoader.terrain_id("Sulfur Dioxide")), 63)
	assert_eq(metadata.storage_capacity(FixtureLoader.terrain_id("Sulfur Dioxide")), 254)
	assert_eq(metadata.motion(FixtureLoader.terrain_id("Sulfur Dioxide")), CompiledTerrainData.MOTION_DENSE_GAS)
	for terrain_name in ["Air", "Water", "Sand", "Lava"]:
		assert_eq(
			metadata.persistent_burn_product_by_id[FixtureLoader.terrain_id(terrain_name)],
			CompiledTerrainData.NO_BURN_PRODUCT_ID,
			"%s must not compile a persistent burn product." % terrain_name
		)
	assert_eq(
		metadata.persistent_burn_product_by_id[FixtureLoader.terrain_id("Sulfur")],
		FixtureLoader.terrain_id("Sulfur Dioxide")
	)
	var sulfur_id := FixtureLoader.terrain_id("Sulfur")
	assert_eq(metadata.persistent_burn_ignition_quantity_by_id[sulfur_id], 1)
	assert_eq(metadata.persistent_burn_base_consumption_by_id[sulfur_id], 1)
	assert_eq(metadata.persistent_burn_bonus_consumption_by_id[sulfur_id], 1)
	assert_eq(metadata.persistent_burn_bonus_frequency_numerator_by_id[sulfur_id], 27)
	assert_eq(metadata.persistent_burn_bonus_frequency_period_by_id[sulfur_id], 100)
	assert_eq(metadata.persistent_burn_product_per_consumed_by_id[sulfur_id], 70)
	assert_eq(metadata.persistent_burn_bonus_product_by_id[sulfur_id], 10)

	_assert_reaction_bytes(metadata, "Sulfur", "Water", 1, [0, FixtureLoader.terrain_id("Sulfuric Acid")], [10, 0, 0, 0])
	_assert_reaction_bytes(metadata, "Sulfur", "Lava", 2, [0, 0], [0, 0, 0, 0])
	_assert_reaction_bytes(metadata, "Sulfuric Acid", "Sand", 3, [FixtureLoader.terrain_id("Water"), FixtureLoader.terrain_id("Air")], [2, 1, 2, 0])
	_assert_reaction_bytes(metadata, "Sulfur Dioxide", "Water", 4, [0, FixtureLoader.terrain_id("Sulfuric Acid")], [3, 63, 189, 127])
	_assert_reaction_bytes(metadata, "Water", "Lava", 5, [FixtureLoader.terrain_id("Air"), FixtureLoader.terrain_id("Stone")], [64, 127, 0, 0])

	var removed_properties := ["kind", "duration_seconds", "input_a_units", "input_b_units", "output_units", "persistent_ignition"]
	var base_property_names := (TerrainContactReaction.new().get_property_list() as Array).map(
		func(property: Dictionary) -> String: return property.name
	)
	for property_name in removed_properties:
		assert_false(base_property_names.has(property_name), "Legacy reaction property %s must be removed." % property_name)
	for path in [
		"res://config/terrain/sulfur_water_reaction.tres",
		"res://config/terrain/sulfur_lava_reaction.tres",
		"res://config/terrain/acid_sand_reaction.tres",
		"res://config/terrain/gas_water_reaction.tres",
		"res://config/terrain/water_lava_reaction.tres",
	]:
		var serialized := FileAccess.get_file_as_string(path)
		for property_name in removed_properties:
			assert_false(serialized.contains("%s =" % property_name), "%s still serializes %s." % [path, property_name])


func test_item_catalog_loads_all_required_definitions() -> void:
	var catalog := FixtureLoader.item_catalog()
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	assert_eq(registry.count(), 9)

	var small_bomb := registry.get_definition(1)
	assert_eq(small_bomb.starting_inventory, 10)

	var large_bomb := registry.get_definition(2)
	assert_eq(large_bomb.starting_inventory, 2)

	var flag := registry.get_definition(3)
	assert_eq(flag.starting_inventory, 1)

	for stable_id in [4, 5, 6, 7, 8, 9]:
		assert_eq(registry.get_definition(stable_id).starting_inventory, 0.0)
	assert_eq(registry.get_definition(9).display_name, "Acid Bottle")


func _assert_reaction_bytes(
	metadata: CompiledTerrainData,
	reactant_a_name: String,
	reactant_b_name: String,
	opcode: int,
	products: Array,
	parameters: Array
) -> void:
	var a := FixtureLoader.terrain_id(reactant_a_name)
	var b := FixtureLoader.terrain_id(reactant_b_name)
	var index := (a & 15) * 16 + (b & 15)
	assert_eq(metadata.reaction_opcode_by_pair[index], opcode)
	assert_eq(metadata.reaction_product_a_by_pair[index], products[0])
	assert_eq(metadata.reaction_product_b_by_pair[index], products[1])
	assert_eq(metadata.reaction_parameter_0_by_pair[index], parameters[0])
	assert_eq(metadata.reaction_parameter_1_by_pair[index], parameters[1])
	assert_eq(metadata.reaction_parameter_2_by_pair[index], parameters[2])
	assert_eq(metadata.reaction_parameter_3_by_pair[index], parameters[3])


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


func test_terrain_definition_rejects_ids_outside_packed_nibble() -> void:
	var definition := TerrainDefinition.new()
	definition.stable_id = 16
	definition.display_name = "Too many terrain types"
	definition.is_solid = true
	definition.is_passable = false
	definition.motion_behavior = StableMotionBehavior.new()
	definition.hazard_behavior = NoHazardBehavior.new()
	definition.blast_reaction = NoBlastReaction.new()

	assert_true("\n".join(definition.validate()).contains("four bits"))
