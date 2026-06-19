extends GutTest

const BaseNoisePassScript = preload("res://src/generation/base_noise_pass.gd")
const PocketNoisePassScript = preload("res://src/generation/pocket_noise_pass.gd")
const SpawnChamberPassScript = preload("res://src/generation/spawn_chamber_pass.gd")
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

	var spawn_pass = SpawnChamberPassScript.new()
	spawn_pass.pass_seed_key = "spawn"

	var boundary_pass = BoundarySealPassScript.new()
	boundary_pass.pass_seed_key = "boundary"
	boundary_pass.sealed_row_count = 2

	profile.passes = [base_pass, spawn_pass, boundary_pass]
	return profile


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
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var result := generator.generate(profile, registry, 999)
	assert_not_null(result)

	for cell_id in result.world.committed_cells:
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

	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Sand")), 500)
	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Water")), 500)
	assert_gt(result.world.count_committed(FixtureLoader.terrain_id("Lava")), 100)


func test_generated_world_shows_secondary_materials_in_upper_play_band() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
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


func test_generation_invariants_hold_across_fixed_seed_sample() -> void:
	var generator := WorldGenerator.new()
	var profile := _default_profile()
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var stone_id := FixtureLoader.terrain_id("Stone")
	var air_id := FixtureLoader.terrain_id("Air")
	var dirt_id := FixtureLoader.terrain_id("Dirt")
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

		for row in range(result.spawn_rect.position.y, result.spawn_rect.end.y - 1):
			for col in range(result.spawn_rect.position.x, result.spawn_rect.end.x):
				assert_eq(result.world.get_committed_by_offset(col, row), air_id)

		for col in range(result.spawn_rect.position.x + 1, result.spawn_rect.end.x - 1):
			assert_eq(result.world.get_committed_by_offset(col, result.spawn_rect.end.y - 1), dirt_id)

		var air_ratio := float(result.world.count_committed(air_id)) / float(result.world.dimensions.cell_count())
		assert_true(air_ratio >= 0.08, "Air ratio too low for seed %d: %f" % [run_seed, air_ratio])
		assert_true(air_ratio <= 0.42, "Air ratio too high for seed %d: %f" % [run_seed, air_ratio])


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
	var dirt_id := FixtureLoader.terrain_id("Dirt")

	var pocket_pass_a = PocketNoisePassScript.new()
	pocket_pass_a.pass_seed_key = "reorder_pocket"
	pocket_pass_a.allowed_target_ids = PackedInt32Array([dirt_id])
	pocket_pass_a.frequency_x = 0.04
	pocket_pass_a.frequency_y = 0.04
	pocket_pass_a.sand_threshold = 0.4
	pocket_pass_a.water_threshold = 0.99
	pocket_pass_a.lava_threshold = 0.99
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

	var first = PocketNoisePassScript.new()
	first.pass_seed_key = "pocket_one"
	first.allowed_target_ids = PackedInt32Array([dirt_id])
	first.frequency_x = 0.05
	first.frequency_y = 0.04
	first.sand_threshold = 0.4
	first.water_threshold = 0.95
	first.lava_threshold = 0.99

	var second = PocketNoisePassScript.new()
	second.pass_seed_key = "pocket_two"
	second.allowed_target_ids = PackedInt32Array([dirt_id])
	second.frequency_x = 0.03
	second.frequency_y = 0.03
	second.sand_threshold = 0.99
	second.water_threshold = 0.4
	second.lava_threshold = 0.99

	profile.passes.insert(1, first)
	profile.passes.insert(2, second)

	var result := generator.generate(profile, registry, 991)
	assert_not_null(result)
	assert_gt(result.world.count_committed(sand_id), 0)
	assert_gt(result.world.count_committed(water_id), 0)


func test_replacement_whitelist_prevents_unauthorized_replacement() -> void:
	var generator := WorldGenerator.new()
	var registry := FixtureLoader.terrain_registry()
	var baseline_profile := _base_profile_for_stack_tests()
	var profile := _base_profile_for_stack_tests()
	var stone_id := FixtureLoader.terrain_id("Stone")
	var dirt_id := FixtureLoader.terrain_id("Dirt")
	var sand_id := FixtureLoader.terrain_id("Sand")

	var pocket_pass = PocketNoisePassScript.new()
	pocket_pass.pass_seed_key = "only_stone"
	pocket_pass.allowed_target_ids = PackedInt32Array([stone_id])
	pocket_pass.frequency_x = 0.06
	pocket_pass.frequency_y = 0.06
	pocket_pass.sand_threshold = 0.1
	pocket_pass.water_threshold = 0.99
	pocket_pass.lava_threshold = 0.99
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

	var pocket_pass = PocketNoisePassScript.new()
	pocket_pass.pass_seed_key = "banded_water"
	pocket_pass.allowed_target_ids = PackedInt32Array([dirt_id])
	pocket_pass.frequency_x = 0.04
	pocket_pass.frequency_y = 0.04
	pocket_pass.sand_threshold = 0.99
	pocket_pass.water_threshold = 0.2
	pocket_pass.lava_threshold = 0.99
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
