extends GutTest


var _base_movement: PlayerMovementConfig
var _base_grapple: GrappleConfig


func before_each() -> void:
	_base_movement = load(
		"res://config/player/default_movement.tres"
	) as PlayerMovementConfig
	_base_grapple = load(
		"res://config/player/default_grapple.tres"
	) as GrappleConfig


func test_baseline_compilation_duplicates_authored_resources() -> void:
	var tuning := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		null
	)

	assert_not_same(tuning.movement, _base_movement)
	assert_not_same(tuning.grapple, _base_grapple)
	assert_eq(tuning.movement.gravity, _base_movement.gravity)
	assert_eq(tuning.grapple.max_rope_length, _base_grapple.max_rope_length)
	tuning.movement.gravity = 1.0
	tuning.grapple.max_rope_length = 1.0
	assert_ne(_base_movement.gravity, 1.0)
	assert_ne(_base_grapple.max_rope_length, 1.0)


func test_acrobat_compiles_without_stacking_repeated_builds() -> void:
	var modifiers := _modifiers([
		"res://config/perks/acrobat.tres",
	])
	var first := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		modifiers
	)
	var second := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		modifiers
	)

	assert_eq(
		first.movement.max_ground_speed,
		_base_movement.max_ground_speed * 1.25
	)
	assert_eq(first.movement.extra_air_jumps, _base_movement.extra_air_jumps + 1)
	assert_eq(first.movement.gravity, _base_movement.gravity * 0.75)
	assert_eq(
		first.grapple.max_rope_length,
		_base_grapple.max_rope_length * 1.5
	)
	assert_eq(second.movement.gravity, first.movement.gravity)
	assert_eq(second.grapple.max_rope_length, first.grapple.max_rope_length)
	assert_eq(_base_movement.gravity, 1400.0)
	assert_eq(_base_grapple.max_rope_length, 220.0)


func test_jelly_compiles_typed_liquid_bounce_and_impact_policy() -> void:
	var tuning := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		_modifiers(["res://config/perks/jelly.tres"])
	)

	assert_true(tuning.liquid_gravity_cancelled)
	assert_true(tuning.liquid_drag_disabled)
	assert_eq(tuning.liquid_buoyancy_multiplier, 1.5)
	assert_eq(tuning.hard_surface_restitution, 0.5)
	assert_eq(tuning.bounce_settle_speed, 60.0)
	assert_eq(tuning.movement.impact_hazard_minimum_speed, INF)


func test_glass_sand_and_hazard_modifiers_compile_to_typed_policy() -> void:
	var tuning := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		_modifiers([
			"res://config/perks/glass_cannon.tres",
			"res://config/perks/sand_worm.tres",
			"res://config/perks/lava_resistance.tres",
			"res://config/perks/breath_resistance.tres",
		])
	)

	assert_true(tuning.free_air_control_disabled)
	assert_true(tuning.all_hazards_immune)
	assert_true(tuning.sand_passable)
	assert_true(tuning.sand_breathable)
	assert_eq(tuning.lava_duration_seconds_add, 1.0)
	assert_eq(tuning.suffocation_duration_seconds_add, 5.0)
	assert_eq(
		tuning.movement.lethal_impact_speed,
		_base_movement.medium_impact_speed
	)


func test_sulfur_resistance_compiles_to_typed_hazard_policy() -> void:
	var tuning := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		_modifiers(["res://config/perks/sulfur_resistance.tres"])
	)

	assert_true(tuning.sulfur_dioxide_breathable)
	assert_true(tuning.sulfur_dioxide_immune)
	assert_eq(tuning.acid_duration_seconds_add, 2.0)


func test_impact_modes_preserve_existing_threshold_transformations() -> void:
	var hard_skin := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		_single_player_value("impact_mode", 1.0)
	)
	var jelly := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		_single_player_value("impact_mode", 2.0)
	)
	var glass := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		_single_player_value("impact_mode", 3.0)
	)

	assert_eq(
		hard_skin.movement.impact_hazard_minimum_speed,
		_base_movement.medium_impact_speed
	)
	assert_eq(
		hard_skin.movement.medium_impact_speed,
		_base_movement.lethal_impact_speed
	)
	assert_eq(
		hard_skin.movement.lethal_impact_speed,
		_base_movement.lethal_impact_speed
			+ (_base_movement.lethal_impact_speed - _base_movement.medium_impact_speed)
	)
	assert_eq(jelly.movement.impact_hazard_minimum_speed, INF)
	assert_eq(
		glass.movement.lethal_impact_speed,
		_base_movement.medium_impact_speed
	)


func test_cancelled_shipped_perks_compile_to_baseline_rules() -> void:
	var glass_and_hard_skin := _shipped_pool_modifiers([15, 4])
	var glass_and_jelly := _shipped_pool_modifiers([15, 5])
	var acrobat_and_glass := PlayerRuntimeTuning.compile(
		_base_movement,
		_base_grapple,
		_shipped_pool_modifiers([7, 15])
	)

	for modifiers in [glass_and_hard_skin, glass_and_jelly]:
		var tuning := PlayerRuntimeTuning.compile(
			_base_movement,
			_base_grapple,
			modifiers
		)
		assert_eq(
			tuning.movement.impact_hazard_minimum_speed,
			_base_movement.impact_hazard_minimum_speed
		)
		assert_eq(
			tuning.movement.medium_impact_speed,
			_base_movement.medium_impact_speed
		)
		assert_eq(
			tuning.movement.lethal_impact_speed,
			_base_movement.lethal_impact_speed
		)

	assert_eq(acrobat_and_glass.movement.gravity, _base_movement.gravity)
	assert_eq(
		acrobat_and_glass.grapple.max_rope_length,
		_base_grapple.max_rope_length
	)
	assert_false(acrobat_and_glass.free_air_control_disabled)
	assert_eq(
		acrobat_and_glass.movement.max_ground_speed,
		_base_movement.max_ground_speed * 1.25
	)
	assert_eq(acrobat_and_glass.movement.extra_air_jumps, 1)


func _modifiers(resource_paths: Array[String]) -> PerkModifierSnapshot:
	var builder := PerkModifierBuilder.new()
	for resource_path in resource_paths:
		var definition := load(resource_path) as PerkDefinition
		for effect in definition.effects:
			effect.apply(builder)
	return builder.build()


func _single_player_value(key: String, value: float) -> PerkModifierSnapshot:
	var builder := PerkModifierBuilder.new()
	builder.apply_contribution(
		PerkModifierEffect.Domain.PLAYER,
		key,
		PerkModifierEffect.Operation.SET,
		value
	)
	return builder.build()


func _shipped_pool_modifiers(ids: Array[int]) -> PerkModifierSnapshot:
	var registry := PerkRegistry.new()
	var catalog := load("res://config/perks/catalog.tres") as PerkCatalog
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	var pool := PerkPool.new()
	pool.configure(registry)
	for id in ids:
		assert_true(pool.select(id))
	return pool.modifiers()
