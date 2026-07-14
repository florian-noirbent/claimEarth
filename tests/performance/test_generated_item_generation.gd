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
