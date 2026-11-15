extends GutTest


func test_default_generated_item_pass_stays_below_thirty_milliseconds() -> void:
	var profile := load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile
	var item_pass: GenerationPassResource
	for generation_pass in profile.passes:
		if generation_pass.get_script() != null and String(generation_pass.get_script().resource_path).ends_with("generated_item_pass.gd"):
			item_pass = generation_pass
			break
	assert_not_null(item_pass)
	if item_pass == null:
		return
	var registry := FixtureLoader.terrain_registry()
	_apply_once(profile, item_pass, registry, 100)
	var samples := PackedInt64Array()
	for sample_index in range(7):
		var started := Time.get_ticks_usec()
		var spawn_count := _apply_once(profile, item_pass, registry, 200 + sample_index)
		samples.append(Time.get_ticks_usec() - started)
		assert_eq(spawn_count, 19)
	samples.sort()
	var median_usec := samples[int(samples.size() / 2)]
	assert_lt(median_usec, 30_000, "Generated item placement median was %d usec." % median_usec)


func _apply_once(
	profile: GenerationProfile,
	item_pass: GenerationPassResource,
	registry: TerrainRegistry,
	seed: int
) -> int:
	var world := WorldGrid.new(profile.create_dimensions(), 0)
	var context := GenerationContext.new(profile, seed, registry, world)
	assert_true(item_pass.apply(context))
	return context.item_chest_spawns.size()


func test_barrel_pass_on_generated_terrain_stays_below_thirty_milliseconds() -> void:
	var profile := load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile
	var barrel_pass: GenerationPassResource
	for generation_pass in profile.passes:
		if generation_pass.get("item_definition") is ExplosiveBarrelDefinition:
			barrel_pass = generation_pass
	assert_not_null(barrel_pass)
	if barrel_pass == null:
		return
	# Rejected anchors are probed in order, so time the pass on realistic generated terrain.
	barrel_pass.enabled = false
	var registry := FixtureLoader.terrain_registry()
	var generator := WorldGenerator.new()
	var samples := PackedInt64Array()
	for sample_index in range(5):
		var result := generator.generate(profile, registry, 300 + sample_index)
		var context := GenerationContext.new(profile, 300 + sample_index, registry, result.world)
		var started := Time.get_ticks_usec()
		assert_true(barrel_pass.apply(context))
		samples.append(Time.get_ticks_usec() - started)
		assert_gt(context.explosive_barrel_spawns.size(), 0)
	samples.sort()
	var median_usec := samples[int(samples.size() / 2)]
	assert_lt(median_usec, 30_000, "Barrel placement median was %d usec." % median_usec)
