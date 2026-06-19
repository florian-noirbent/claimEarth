extends GutTest

const BoundarySealPassScript = preload("res://src/generation/boundary_seal_pass.gd")


func test_boundary_pass_only_seals_last_two_rows() -> void:
	var profile := GenerationProfile.new()
	profile.width = 8
	profile.depth = 12
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var air_id := FixtureLoader.terrain_id("Air")
	var stone_id := FixtureLoader.terrain_id("Stone")
	var world := WorldGrid.new(profile.create_dimensions(), air_id)
	var context := GenerationContext.new(profile, 42, registry, world)

	assert_true(BoundarySealPassScript.new().apply(context))

	for row in range(profile.depth - 2):
		assert_eq(world.get_committed_by_offset(0, row), air_id)
		assert_eq(world.get_committed_by_offset(profile.width - 1, row), air_id)
	for row in range(profile.depth - 2, profile.depth):
		for col in range(profile.width):
			assert_eq(world.get_committed_by_offset(col, row), stone_id)
