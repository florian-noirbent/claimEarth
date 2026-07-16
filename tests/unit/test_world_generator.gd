extends GutTest

const BaseNoisePassScript = preload("res://src/generation/base_noise_pass.gd")
const PocketNoisePassScript = preload("res://src/generation/pocket_noise_pass.gd")
const SpawnShaftPassScript = preload("res://src/generation/spawn_shaft_pass.gd")
const BoundarySealPassScript = preload("res://src/generation/boundary_seal_pass.gd")


func _default_profile() -> GenerationProfile:
	return load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile


func _base_profile_for_stack_tests() -> GenerationProfile:
	var profile := GenerationProfile.new()
	profile.width = 24
	profile.depth = 32
	profile.spawn_width = 6
	profile.spawn_height = 4

	var base_pass = BaseNoisePassScript.new()
	base_pass.pass_seed_key = "base"
	base_pass.octaves = 3
	base_pass.frequency_x = 0.08
	base_pass.frequency_y = 0.05
	base_pass.gain = 0.52
	base_pass.cave_threshold = 0.12
	base_pass.dirt_threshold = 0.44

	var spawn_pass = SpawnShaftPassScript.new()
	spawn_pass.pass_seed_key = "spawn"

	var boundary_pass = BoundarySealPassScript.new()
	boundary_pass.pass_seed_key = "boundary"
	boundary_pass.sealed_row_count = 2

	profile.passes = [base_pass, spawn_pass, boundary_pass]
	return profile


func _hazard_pass(pass_seed_key: String, hazard_type: int, placement_threshold: float, allowed_target_ids := PackedInt32Array()) -> Resource:
	var pocket_pass = PocketNoisePassScript.new()
	pocket_pass.pass_seed_key = pass_seed_key
	pocket_pass.hazard_type = hazard_type
	pocket_pass.allowed_target_ids = allowed_target_ids
	pocket_pass.frequency_x = 0.04
	pocket_pass.frequency_y = 0.04
	pocket_pass.placement_threshold = placement_threshold
	return pocket_pass


func test_same_seed_and_profile_produce_same_world_hash() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))

	var first := generator.generate(profile, registry, 12345)
	var second := generator.generate(profile, registry, 12345)

	assert_not_null(first)
	assert_not_null(second)
	assert_eq(first.world_hash, second.world_hash)
	assert_eq(first.final_seed, 12345)
	assert_eq(first.attempts, 1)
	assert_eq(first.spawn_rect, second.spawn_rect)


func test_default_profile_persists_stable_pass_seed_keys() -> void:
	var profile := _default_profile()
	var keys := PackedStringArray()
	for generation_pass in profile.passes:
		keys.append(generation_pass.pass_seed_key)
	assert_eq(keys, PackedStringArray([
		"base_terrain_0",
		"sand_hazard_1",
		"water_hazard_2",
		"lava_hazard_3",
		"spawn_shaft_4",
		"item_chests_5",
		"bottom_seal_6",
	]))


func test_generated_world_has_sealed_bottom_and_spawn_air() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var stone_id := registry.get_definition(1).stable_id
	var air_id := registry.get_definition(0).stable_id

	var result := generator.generate(profile, registry, 222)
	assert_not_null(result)
	assert_eq(result.spawn_rect.position.y, 0)
	assert_eq(result.spawn_rect.size.y, _spawn_shaft_target_depth(profile) + 1)

	for row in range(profile.depth - 2, profile.depth):
		for col in range(profile.width):
			assert_eq(result.world.get_committed_by_offset(col, row), stone_id)

	var spawn_col := result.spawn_rect.position.x + int(result.spawn_rect.size.x / 2)
	assert_eq(result.world.get_committed_by_offset(spawn_col, 0), air_id)
	assert_eq(result.world.get_committed_quantity_by_offset(spawn_col, 0), WorldGrid.AIR_QUANTITY)
	assert_true(_row_has_air(result.world, air_id, 100))


func test_generated_world_uses_only_registered_ids() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 999)
	assert_not_null(result)

	for index in range(result.world.dimensions.cell_count()):
		var cell_id := result.world.get_committed_by_index(index)
		assert_true(registry.has_definition(cell_id), "Unknown terrain id %d" % cell_id)


func test_generated_world_air_ratio_stays_in_target_band() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 31415)
	assert_not_null(result)

	var air_ratio := float(result.world.count_committed(0)) / float(result.world.dimensions.cell_count())
	assert_true(air_ratio >= 0.14)
	assert_true(air_ratio <= 0.42)


func test_generated_world_includes_secondary_material_pockets() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 31415)
	assert_not_null(result)

	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Sand")), 100)
	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Water")), 100)
	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Lava")), 100)


func test_default_profile_uses_typed_hazard_pocket_instances_without_showcase_pass() -> void:
	var profile := _default_profile()
	var hazard_passes: Array = []
	for pass_resource in profile.passes:
		if pass_resource == null:
			continue
		assert_ne(pass_resource.get_pass_type_name(), "Showcase Pockets")
		if pass_resource.get_pass_type_name() == "Hazard Pocket":
			hazard_passes.append(pass_resource)

	assert_eq(hazard_passes.size(), 3)
	assert_eq(hazard_passes[0].label, "Sand Hazard")
	assert_eq(hazard_passes[1].label, "Water Hazard")
	assert_eq(hazard_passes[2].label, "Lava Hazard")
	assert_eq(hazard_passes[0].hazard_type, PocketNoisePassScript.HazardType.SAND)
	assert_eq(hazard_passes[1].hazard_type, PocketNoisePassScript.HazardType.WATER)
	assert_eq(hazard_passes[2].hazard_type, PocketNoisePassScript.HazardType.LAVA)


func test_generation_invariants_hold_across_fixed_seed_sample() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var stone_id := FixtureLoader.terrain_id("Stone")
	var air_id := FixtureLoader.terrain_id("Air")
	var sample_seeds := [
		SeedUtils.seed_from_text("generation-invariant-1"),
		SeedUtils.seed_from_text("generation-invariant-2"),
		SeedUtils.seed_from_text("generation-invariant-3"),
		SeedUtils.seed_from_text("generation-invariant-4"),
	]

	for run_seed in sample_seeds:
		var result := generator.generate(profile, registry, run_seed)
		assert_not_null(result, "Generation failed for seed %d" % run_seed)
		assert_eq(result.final_seed, run_seed)
		assert_eq(result.attempts, 1)

		for row in range(profile.depth - 2, profile.depth):
			for col in range(profile.width):
				assert_eq(result.world.get_committed_by_offset(col, row), stone_id)

		assert_eq(result.spawn_rect.position.y, 0)
		assert_eq(result.spawn_rect.size.y, _spawn_shaft_target_depth(profile) + 1)
		var spawn_col := result.spawn_rect.position.x + int(result.spawn_rect.size.x / 2)
		assert_eq(result.world.get_committed_by_offset(spawn_col, 0), air_id)
		assert_true(_row_has_air(result.world, air_id, 100))

		var air_ratio := float(result.world.count_committed(air_id)) / float(result.world.dimensions.cell_count())
		assert_true(air_ratio >= 0.08, "Air ratio too low for seed %d: %f" % [run_seed, air_ratio])
		assert_true(air_ratio <= 0.42, "Air ratio too high for seed %d: %f" % [run_seed, air_ratio])


func test_spawn_shaft_seed_changes_shape_deterministically() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var profile := _default_profile()
	var first := generator.generate(profile, registry, SeedUtils.seed_from_text("spawn-shaft-a"))
	var second := generator.generate(profile, registry, SeedUtils.seed_from_text("spawn-shaft-b"))
	var first_repeat := generator.generate(profile, registry, SeedUtils.seed_from_text("spawn-shaft-a"))
	assert_not_null(first)
	assert_not_null(second)
	assert_not_null(first_repeat)
	assert_eq(first.world_hash, first_repeat.world_hash)
	assert_ne(_air_cells_for_rows(first.world, FixtureLoader.terrain_id("Air"), 0, 100), _air_cells_for_rows(second.world, FixtureLoader.terrain_id("Air"), 0, 100))


func test_spawn_shaft_steepness_changes_shape_without_changing_target_depth() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var steep_profile := _default_profile()
	var winding_profile := _default_profile()
	var steep_pass: GenerationPassResource = _spawn_pass_for_profile(steep_profile)
	var winding_pass: GenerationPassResource = _spawn_pass_for_profile(winding_profile)
	assert_not_null(steep_pass)
	assert_not_null(winding_pass)
	steep_pass.set("shaft_steepness", 2.0)
	steep_pass.set("segment_erase_threshold", 0.0)
	winding_pass.set("shaft_steepness", 0.5)
	winding_pass.set("segment_erase_threshold", 0.0)

	var steep_result := generator.generate(steep_profile, registry, SeedUtils.seed_from_text("spawn-steepness"))
	var winding_result := generator.generate(winding_profile, registry, SeedUtils.seed_from_text("spawn-steepness"))
	assert_not_null(steep_result)
	assert_not_null(winding_result)
	assert_eq(steep_result.spawn_rect.size.y, _spawn_shaft_target_depth(steep_profile) + 1)
	assert_eq(winding_result.spawn_rect.size.y, _spawn_shaft_target_depth(winding_profile) + 1)
	assert_ne(_air_cells_for_rows(steep_result.world, FixtureLoader.terrain_id("Air"), 0, 100), _air_cells_for_rows(winding_result.world, FixtureLoader.terrain_id("Air"), 0, 100))


func test_spawn_shaft_segment_erase_threshold_leaves_gaps() -> void:
	var registry := FixtureLoader.terrain_registry()
	var profile := GenerationProfile.new()
	profile.width = 48
	profile.depth = 128
	var stone_id := FixtureLoader.terrain_id("Stone")
	var air_id := FixtureLoader.terrain_id("Air")
	var world := WorldGrid.new(profile.create_dimensions(), stone_id)
	var context := GenerationContext.new(profile, SeedUtils.seed_from_text("spawn-segment-erase"), registry, world)
	var spawn_pass: GenerationPassResource = SpawnShaftPassScript.new()
	spawn_pass.pass_seed_key = "spawn-segment-erase"
	spawn_pass.set("segment_erase_threshold", 0.48)
	spawn_pass.set("protected_surface_rows", 3)

	assert_true(spawn_pass.apply(context))
	assert_eq(context.spawn_rect.position.y, 0)
	assert_eq(context.spawn_rect.size.y, 101)
	assert_true(_row_has_air(world, air_id, 0))
	assert_true(_row_has_air(world, air_id, 100))
	assert_gt(_solid_rows_in_range(world, air_id, 3, 99), 0)


func test_disabling_a_pass_changes_output_deterministically() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := FixtureLoader.terrain_registry()

	var enabled_result := generator.generate(profile, registry, 5123)
	profile.passes[1].enabled = false
	var disabled_result_a := generator.generate(profile, registry, 5123)
	var disabled_result_b := generator.generate(profile, registry, 5123)

	assert_not_null(enabled_result)
	assert_not_null(disabled_result_a)
	assert_not_null(disabled_result_b)
	assert_ne(enabled_result.world_hash, disabled_result_a.world_hash)
	assert_eq(disabled_result_a.world_hash, disabled_result_b.world_hash)


func test_reordering_passes_changes_output_deterministically() -> void:
	var generator := WorldGenerator.new()
	var profile_a := _base_profile_for_stack_tests()
	var profile_b := _base_profile_for_stack_tests()
	var registry := FixtureLoader.terrain_registry()

	var pocket_pass_a = _hazard_pass("reorder_pocket", PocketNoisePassScript.HazardType.SAND, 0.1)
	pocket_pass_a.max_depth_ratio = 0.4
	var pocket_pass_b: Resource = pocket_pass_a.duplicate(true)

	profile_a.passes.insert(1, pocket_pass_a)
	profile_b.passes.insert(2, pocket_pass_b)
	var first := generator.generate(profile_a, registry, 811)
	var second_a := generator.generate(profile_b, registry, 811)
	var second_b := generator.generate(profile_b, registry, 811)

	assert_not_null(first)
	assert_not_null(second_a)
	assert_not_null(second_b)
	assert_ne(first.world_hash, second_a.world_hash)
	assert_eq(second_a.world_hash, second_b.world_hash)


func test_duplicate_pass_type_with_different_parameters_applies_both_instances() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var profile := _base_profile_for_stack_tests()
	var dirt_id := FixtureLoader.terrain_id("Dirt")
	var sand_id := FixtureLoader.terrain_id("Sand")
	var water_id := FixtureLoader.terrain_id("Water")

	var first = _hazard_pass("pocket_one", PocketNoisePassScript.HazardType.SAND, 0.4, PackedInt32Array([dirt_id]))
	first.frequency_x = 0.05
	first.frequency_y = 0.04

	var second = _hazard_pass("pocket_two", PocketNoisePassScript.HazardType.WATER, 0.4, PackedInt32Array([dirt_id]))
	second.frequency_x = 0.03
	second.frequency_y = 0.03

	profile.passes.insert(1, first)
	profile.passes.insert(2, second)

	var result := generator.generate(profile, registry, 991)
	assert_not_null(result)
	assert_gt(result.world.count_committed(sand_id), 0)
	assert_gt(result.world.count_committed(water_id), 0)


func test_hazard_pocket_pass_seed_key_changes_noise_layout_deterministically() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var profile_a := _base_profile_for_stack_tests()
	var profile_b := _base_profile_for_stack_tests()
	var dirt_id := FixtureLoader.terrain_id("Dirt")

	var first_pass = _hazard_pass("hazard_alpha", PocketNoisePassScript.HazardType.SAND, 0.35, PackedInt32Array([dirt_id]))
	var second_pass = _hazard_pass("hazard_beta", PocketNoisePassScript.HazardType.SAND, 0.35, PackedInt32Array([dirt_id]))
	profile_a.passes.insert(1, first_pass)
	profile_b.passes.insert(1, second_pass)

	var result_a := generator.generate(profile_a, registry, 1441)
	var result_b := generator.generate(profile_b, registry, 1441)
	var result_b_repeat := generator.generate(profile_b, registry, 1441)

	assert_not_null(result_a)
	assert_not_null(result_b)
	assert_not_null(result_b_repeat)
	assert_ne(result_a.world_hash, result_b.world_hash)
	assert_eq(result_b.world_hash, result_b_repeat.world_hash)


func test_replacement_whitelist_prevents_unauthorized_replacement() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var baseline_profile := _base_profile_for_stack_tests()
	var profile := _base_profile_for_stack_tests()
	var stone_id := FixtureLoader.terrain_id("Stone")
	var dirt_id := FixtureLoader.terrain_id("Dirt")
	var sand_id := FixtureLoader.terrain_id("Sand")

	var pocket_pass = _hazard_pass("only_stone", PocketNoisePassScript.HazardType.SAND, 0.1, PackedInt32Array([stone_id]))
	pocket_pass.frequency_x = 0.06
	pocket_pass.frequency_y = 0.06
	profile.passes.insert(1, pocket_pass)

	var baseline := generator.generate(baseline_profile, registry, 2026)
	var result := generator.generate(profile, registry, 2026)
	assert_not_null(baseline)
	assert_not_null(result)

	for row in range(result.spawn_rect.end.y, profile.depth - 2):
		for col in range(profile.width):
			if baseline.world.get_committed_by_offset(col, row) == dirt_id:
				assert_ne(result.world.get_committed_by_offset(col, row), sand_id)
			if result.world.get_committed_by_offset(col, row) == sand_id:
				assert_eq(baseline.world.get_committed_by_offset(col, row), stone_id)


func test_depth_range_and_blend_only_affect_targeted_band() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var profile := _base_profile_for_stack_tests()
	var dirt_id := FixtureLoader.terrain_id("Dirt")
	var water_id := FixtureLoader.terrain_id("Water")

	var pocket_pass = _hazard_pass("banded_water", PocketNoisePassScript.HazardType.WATER, 0.2, PackedInt32Array([dirt_id]))
	pocket_pass.min_depth_ratio = 0.25
	pocket_pass.max_depth_ratio = 0.5
	pocket_pass.blend_distance_ratio = 0.1
	profile.passes.insert(1, pocket_pass)

	var result := generator.generate(profile, registry, 44)
	assert_not_null(result)

	for row in range(profile.depth):
		for col in range(profile.width):
			if result.world.get_committed_by_offset(col, row) != water_id:
				continue
			var ratio := float(row) / float(max(1, profile.depth - 1))
			assert_true(ratio >= 0.25 and ratio <= 0.5)


func test_whitelist_all_allows_hazard_pockets_to_replace_air() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var profile := _base_profile_for_stack_tests()
	var baseline_profile := _base_profile_for_stack_tests()
	var sand_id := FixtureLoader.terrain_id("Sand")
	var air_id := FixtureLoader.terrain_id("Air")

	var pocket_pass = _hazard_pass("air_fill", PocketNoisePassScript.HazardType.SAND, 0.1)
	pocket_pass.min_depth_ratio = 0.0
	pocket_pass.max_depth_ratio = 0.18
	profile.passes.insert(1, pocket_pass)

	var baseline := generator.generate(baseline_profile, registry, 909)
	var result := generator.generate(profile, registry, 909)
	assert_not_null(baseline)
	assert_not_null(result)

	var replaced_air_cells := 0
	for row in range(profile.depth):
		for col in range(profile.width):
			if baseline.world.get_committed_by_offset(col, row) == air_id and result.world.get_committed_by_offset(col, row) == sand_id:
				replaced_air_cells += 1
	assert_gt(replaced_air_cells, 0)


func test_whitelist_without_air_still_blocks_air_replacement() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var profile := _base_profile_for_stack_tests()
	var baseline_profile := _base_profile_for_stack_tests()
	var dirt_id := FixtureLoader.terrain_id("Dirt")
	var sand_id := FixtureLoader.terrain_id("Sand")
	var air_id := FixtureLoader.terrain_id("Air")

	var pocket_pass = _hazard_pass("no_air_fill", PocketNoisePassScript.HazardType.SAND, 0.1, PackedInt32Array([dirt_id]))
	pocket_pass.min_depth_ratio = 0.0
	pocket_pass.max_depth_ratio = 0.18
	profile.passes.insert(1, pocket_pass)

	var baseline := generator.generate(baseline_profile, registry, 910)
	var result := generator.generate(profile, registry, 910)
	assert_not_null(baseline)
	assert_not_null(result)

	for row in range(profile.depth):
		for col in range(profile.width):
			if baseline.world.get_committed_by_offset(col, row) == air_id:
				assert_ne(result.world.get_committed_by_offset(col, row), sand_id)


func _row_has_air(world: WorldGrid, air_id: int, row: int) -> bool:
	for col in range(world.dimensions.width):
		if world.get_committed_by_offset(col, row) == air_id:
			return true
	return false


func _solid_rows_in_range(world: WorldGrid, air_id: int, start_row: int, end_row: int) -> int:
	var result := 0
	for row in range(start_row, end_row + 1):
		if not _row_has_air(world, air_id, row):
			result += 1
	return result


func _air_cells_for_rows(world: WorldGrid, air_id: int, start_row: int, end_row: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for row in range(start_row, end_row + 1):
		for col in range(world.dimensions.width):
			if world.get_committed_by_offset(col, row) == air_id:
				result.append(Vector2(float(col), float(row)))
	return result


func _spawn_pass_for_profile(profile: GenerationProfile) -> GenerationPassResource:
	for pass_resource in profile.passes:
		if pass_resource != null and pass_resource.get_pass_type_name() == "Spawn Shaft":
			return pass_resource
	return null


func _spawn_shaft_target_depth(profile: GenerationProfile) -> int:
	var spawn_pass := _spawn_pass_for_profile(profile)
	return mini(int(spawn_pass.get("shaft_target_depth")), profile.depth - 3) if spawn_pass != null else 0
