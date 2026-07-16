extends GutTest


func test_baseline_compilation_uses_existing_item_defaults() -> void:
	var tuning := RunItemRuntimeTuning.compile(null)

	assert_eq(tuning.small_bomb_preserve_chance, 0.0)
	assert_eq(tuning.excavator_tick_interval_multiplier, 1.0)
	assert_eq(tuning.reward_choice_count(2), 2)
	assert_false(tuning.container_indestructible)
	assert_false(tuning.flag_survives_hazards)


func test_shipped_item_perks_compile_to_typed_policy() -> void:
	var tuning := RunItemRuntimeTuning.compile(_modifiers([
		"res://config/perks/small_boom.tres",
		"res://config/perks/large_boom.tres",
		"res://config/perks/looter.tres",
		"res://config/perks/relentless.tres",
		"res://config/perks/vaporizer.tres",
		"res://config/perks/excavator.tres",
		"res://config/perks/cave_dweller.tres",
	]))

	assert_eq(tuning.small_bomb_preserve_chance, 0.5)
	assert_eq(tuning.large_bomb_preserve_chance, 0.33)
	assert_eq(tuning.shovel_pickaxe_preserve_chance, 0.5)
	assert_eq(tuning.excavator_tick_interval_multiplier, 0.5)
	assert_eq(tuning.reward_choice_count(2), 3)
	assert_true(tuning.container_indestructible)
	assert_eq(tuning.item_chest_light_add, 70)
	assert_true(tuning.flag_survives_hazards)
	assert_eq(tuning.dirt_vaporize_chance, 0.5)


func test_preservation_chance_uses_existing_tag_precedence() -> void:
	var tuning := RunItemRuntimeTuning.compile(_modifiers([
		"res://config/perks/small_boom.tres",
		"res://config/perks/large_boom.tres",
		"res://config/perks/cave_dweller.tres",
	]))
	var small_bomb := _item_with_tags(["small_bomb", "large_bomb"])
	var large_bomb := _item_with_tags(["large_bomb"])
	var tool := _item_with_tags(["pickaxe"])

	assert_eq(tuning.preserve_chance_for(small_bomb), 0.5)
	assert_eq(tuning.preserve_chance_for(large_bomb), 0.33)
	assert_eq(tuning.preserve_chance_for(tool), 0.5)
	assert_eq(tuning.preserve_chance_for(null), 0.0)


func test_explosion_modifiers_preserve_current_radius_and_terrain_policy() -> void:
	var tuning := RunItemRuntimeTuning.compile(_modifiers([
		"res://config/perks/large_boom.tres",
		"res://config/perks/vaporizer.tres",
	]))
	var spec := ExplosionRuntimeSpec.new()
	spec.blast_radius = 3
	spec.vaporize_radius = 1
	spec.player_kill_radius = 1
	var large_bomb := _item_with_tags(["large_bomb"])

	tuning.apply_to_explosion(spec, large_bomb)

	assert_eq(spec.blast_radius, 5)
	assert_eq(spec.vaporize_radius, 2)
	assert_eq(spec.player_kill_radius, 2)
	assert_eq(spec.vaporize_radius_for(_terrain_with_tags(["sand"])), 3)
	assert_eq(spec.vaporize_radius_for(_terrain_with_tags([])), 2)
	assert_eq(spec.blast_vaporize_chance_for(_terrain_with_tags(["dirt"]), Vector2i.ZERO), 0.5)
	assert_eq(spec.blast_vaporize_chance_for(_terrain_with_tags([]), Vector2i.ZERO), 0.0)


func test_tool_dirt_chance_clamps_at_use_boundary() -> void:
	var builder := PerkModifierBuilder.new()
	builder.apply_contribution(
		PerkModifierEffect.Domain.TERRAIN,
		"dirt_vaporize_chance",
		PerkModifierEffect.Operation.SET,
		2.0
	)

	var tuning := RunItemRuntimeTuning.compile(builder.build())
	assert_eq(tuning.dirt_vaporize_chance, 2.0)
	assert_eq(tuning.tool_dirt_vaporize_chance(), 1.0)


func _modifiers(resource_paths: Array[String]) -> PerkModifierSnapshot:
	var builder := PerkModifierBuilder.new()
	for resource_path in resource_paths:
		var definition := load(resource_path) as PerkDefinition
		for effect in definition.effects:
			effect.apply(builder)
	return builder.build()


func _item_with_tags(tags: PackedStringArray) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.perk_tags = tags
	return item


func _terrain_with_tags(tags: PackedStringArray) -> TerrainDefinition:
	var terrain := TerrainDefinition.new()
	terrain.perk_tags = tags
	return terrain
