extends GutTest


func _definition(id: int, name: String) -> PerkDefinition:
	var definition := PerkDefinition.new()
	definition.stable_id = id
	definition.display_name = name
	definition.description = name
	definition.icon = load("res://assets/ui/help_icon.svg") as Texture2D
	return definition


func _registry(definitions: Array[PerkDefinition]) -> PerkRegistry:
	var catalog := PerkCatalog.new()
	catalog.definitions = definitions
	var registry := PerkRegistry.new()
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	return registry


func test_catalog_loads_all_perk_definitions() -> void:
	var catalog := load("res://config/perks/catalog.tres") as PerkCatalog
	var registry := PerkRegistry.new()
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	assert_eq(registry.all_definitions().size(), 15)
	var pool := PerkPool.new()
	pool.configure(registry)
	assert_true(pool.select(7))
	assert_eq(pool.modifiers().player.value("movement_speed_multiplier", 1.0), 1.25)


func test_draws_are_seeded_unique_and_selection_removes_exclusion_group() -> void:
	var hard_skin := _definition(1, "Hard Skin")
	hard_skin.exclusion_group = "body"
	var jelly := _definition(2, "Jelly")
	jelly.exclusion_group = "body"
	var acrobat := _definition(3, "Acrobat")
	var pool := PerkPool.new()
	pool.configure(_registry([hard_skin, jelly, acrobat]))
	var first_draw := pool.draw_choices(42, 3)
	var second_draw := pool.draw_choices(42, 3)
	assert_eq(first_draw.map(func(value: PerkDefinition) -> int: return value.stable_id), second_draw.map(func(value: PerkDefinition) -> int: return value.stable_id))
	var unique_ids := {}
	for definition in first_draw:
		unique_ids[definition.stable_id] = true
	assert_eq(unique_ids.size(), 3)
	assert_true(pool.select(1))
	assert_eq(pool.remaining_count(), 1)
	assert_false(pool.select(2))


func test_cancellation_is_order_independent() -> void:
	var protected := _definition(1, "Protected")
	var protection := PerkModifierEffect.new()
	protection.contribution_tag = "impact_protection"
	protection.domain = PerkModifierEffect.Domain.PLAYER
	protection.modifier_key = "impact_threshold"
	protection.operation = PerkModifierEffect.Operation.ADD
	protection.value = 220.0
	protected.effects = [protection]
	var glass := _definition(2, "Glass")
	var cancellation := PerkCancellationEffect.new()
	cancellation.cancelled_contribution_tags = PackedStringArray(["impact_protection"])
	glass.effects = [cancellation]
	var pool := PerkPool.new()
	pool.configure(_registry([protected, glass]))
	assert_true(pool.select(2))
	assert_true(pool.select(1))
	assert_false(pool.modifiers().player.has("impact_threshold"))


func test_glass_and_hard_skin_compile_to_baseline_impact_rules() -> void:
	var pool := _configured_shipped_pool()
	assert_true(pool.select(4))
	assert_true(pool.select(15))

	var player_modifiers := pool.modifiers().player
	assert_false(player_modifiers.has("impact_mode"))
	assert_false(player_modifiers.has("impact_threshold_add"))
	assert_false(player_modifiers.has("impact_death_disabled"))
	assert_false(player_modifiers.has("impact_disabled"))


func test_glass_and_jelly_compile_to_baseline_impact_rules() -> void:
	var pool := _configured_shipped_pool()
	assert_true(pool.select(15))
	assert_true(pool.select(5))

	var player_modifiers := pool.modifiers().player
	assert_false(player_modifiers.has("impact_mode"))
	assert_false(player_modifiers.has("impact_threshold_add"))
	assert_false(player_modifiers.has("impact_death_disabled"))
	assert_false(player_modifiers.has("impact_disabled"))


func test_acrobat_and_glass_cancel_movement_penalties_but_keep_acrobat_traits() -> void:
	var pool := _configured_shipped_pool()
	assert_true(pool.select(7))
	assert_true(pool.select(15))

	var player_modifiers := pool.modifiers().player
	assert_eq(player_modifiers.value("rope_length_multiplier_delta", INF), 0.0)
	assert_eq(player_modifiers.value("gravity_multiplier_delta", INF), 0.0)
	assert_eq(player_modifiers.value("movement_speed_multiplier", 1.0), 1.25)
	assert_eq(player_modifiers.value("extra_air_jumps_add", 0.0), 1.0)
	assert_false(bool(player_modifiers.value("free_air_control_disabled", false)))


func test_debug_grant_uses_the_unique_perk_pool() -> void:
	var first := _definition(1, "First")
	var second := _definition(2, "Second")
	var catalog := PerkCatalog.new()
	catalog.definitions = [first, second]
	var controller := RunPerkController.new()
	assert_true(controller.configure(catalog))
	assert_eq(controller.debug_perk_picker_data().size(), 2)
	assert_true(controller.debug_grant_perk(1))
	assert_false(controller.debug_grant_perk(1))
	assert_eq(controller.selected_perks().size(), 1)
	assert_eq(controller.debug_perk_picker_data().size(), 1)
	controller.free()


func _configured_shipped_pool() -> PerkPool:
	var catalog := load("res://config/perks/catalog.tres") as PerkCatalog
	var registry := PerkRegistry.new()
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	var pool := PerkPool.new()
	pool.configure(registry)
	return pool
