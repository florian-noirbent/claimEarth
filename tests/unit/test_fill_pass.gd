extends GutTest

const FillPassScript = preload("res://src/generation/fill_pass.gd")


func test_fill_pass_only_visits_and_overrides_its_depth_band() -> void:
	var profile := GenerationProfile.new()
	profile.width = 8
	profile.depth = 1000
	var registry := FixtureLoader.terrain_registry()
	var air_id := FixtureLoader.terrain_id("Air")
	var lava := FixtureLoader.terrain_definition_named("Lava")
	var world := WorldGrid.new(profile.create_dimensions(), air_id)
	var context := GenerationContext.new(profile, 42, registry, world)
	var fill_pass = FillPassScript.new()
	fill_pass.fill_terrain = lava
	fill_pass.min_depth_ratio = 0.99
	fill_pass.max_depth_ratio = 1.0

	assert_eq(fill_pass.target_row_range(profile.depth), Vector2i(990, 1000))
	assert_true(fill_pass.apply(context))

	for row in range(990):
		assert_eq(world.get_committed_by_offset(0, row), air_id)
		assert_eq(world.get_committed_by_offset(profile.width - 1, row), air_id)
	for row in range(990, profile.depth):
		for col in range(profile.width):
			assert_eq(world.get_committed_by_offset(col, row), lava.stable_id)


func test_fill_pass_requires_a_registered_fill_terrain() -> void:
	var profile := GenerationProfile.new()
	profile.width = 4
	profile.depth = 4
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(profile.create_dimensions(), FixtureLoader.terrain_id("Air"))
	var context := GenerationContext.new(profile, 42, registry, world)
	var fill_pass = FillPassScript.new()

	assert_false(fill_pass.apply(context))

	var unregistered_terrain := TerrainDefinition.new()
	unregistered_terrain.stable_id = 255
	fill_pass.fill_terrain = unregistered_terrain
	assert_false(fill_pass.apply(context))


func test_top_and_bottom_blend_distances_are_independent() -> void:
	var profile := GenerationProfile.new()
	profile.width = 1
	profile.depth = 101
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(profile.create_dimensions(), FixtureLoader.terrain_id("Air"))
	var context := GenerationContext.new(profile, 42, registry, world)
	var fill_pass = FillPassScript.new()
	fill_pass.min_depth_ratio = 0.4
	fill_pass.max_depth_ratio = 0.8
	fill_pass.top_blend_distance_ratio = 0.1
	fill_pass.bottom_blend_distance_ratio = 0.0

	assert_eq(context.depth_blend_weight(fill_pass, 40), 0.0)
	assert_almost_eq(context.depth_blend_weight(fill_pass, 45), 0.5, 0.001)
	assert_almost_eq(context.depth_blend_weight(fill_pass, 50), 1.0, 0.001)
	assert_almost_eq(context.depth_blend_weight(fill_pass, 80), 1.0, 0.001)

	fill_pass.top_blend_distance_ratio = 0.0
	fill_pass.bottom_blend_distance_ratio = 0.1
	assert_almost_eq(context.depth_blend_weight(fill_pass, 40), 1.0, 0.001)
	assert_almost_eq(context.depth_blend_weight(fill_pass, 75), 0.5, 0.001)
	assert_eq(context.depth_blend_weight(fill_pass, 80), 0.0)
