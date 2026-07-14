extends GutTest


const EnvironmentStatusScript = preload("res://src/player/environment_status.gd")
const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")
const DeathCauseScript = preload("res://src/player/death_cause.gd")


func _effect(cause: StringName, fill_seconds := 1.0, recovery_seconds := 1.0):
	var effect = HazardEffectScript.new()
	effect.cause = cause
	effect.fill_seconds = fill_seconds
	effect.recovery_seconds = recovery_seconds
	return effect


func test_lava_effect_kills_only_after_its_meter_is_full() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = _effect(DeathCauseScript.LAVA, 0.2, 1.0)

	assert_eq(status.evaluate([effect], 0.19), DeathCauseScript.NONE)
	assert_eq(status.evaluate([effect], 0.01), DeathCauseScript.LAVA)


func test_suffocation_requires_exposure_time() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = _effect(DeathCauseScript.SUFFOCATION)

	assert_eq(status.evaluate([effect], 0.4), DeathCauseScript.NONE)
	assert_eq(status.evaluate([effect], 0.4), DeathCauseScript.NONE)
	assert_eq(status.evaluate([effect], 0.3), DeathCauseScript.SUFFOCATION)


func test_missing_effect_recovers_timer_slowly() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = _effect(DeathCauseScript.SUFFOCATION, 1.0, 2.0)

	assert_eq(status.evaluate([effect], 0.8), DeathCauseScript.NONE)
	assert_almost_eq(status.statuses()[0].level, 0.8, 0.001)
	assert_eq(status.evaluate([], 0.8), DeathCauseScript.NONE)
	assert_almost_eq(status.statuses()[0].level, 0.4, 0.001)
	assert_eq(status.evaluate([effect], 0.3), DeathCauseScript.NONE)
	assert_almost_eq(status.statuses()[0].level, 0.7, 0.001)


func test_instant_hazard_accumulates_holds_for_its_impact_frame_and_recovers() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = _effect(DeathCauseScript.IMPACT, 1.0, 3.0)
	effect.secondary_threshold = 0.3
	effect.lethal_end = true

	assert_eq(status.add_instant(effect, 0.4), DeathCauseScript.NONE)
	assert_eq(status.add_instant(effect, 0.6), DeathCauseScript.IMPACT)
	assert_almost_eq(status.level_for(DeathCauseScript.IMPACT), 1.0, 0.001)
	assert_true(status.statuses()[0].is_active)
	assert_almost_eq(status.statuses()[0].secondary_threshold, 0.3, 0.001)
	assert_true(status.statuses()[0].lethal_end)

	status.evaluate([], 0.1)
	assert_almost_eq(status.level_for(DeathCauseScript.IMPACT), 1.0, 0.001)
	status.evaluate([], 1.5)
	assert_almost_eq(status.level_for(DeathCauseScript.IMPACT), 0.5, 0.001)
	assert_false(status.statuses()[0].is_active)
	status.evaluate([], 1.5)
	assert_almost_eq(status.level_for(DeathCauseScript.IMPACT), 0.0, 0.001)
	assert_true(status.statuses().is_empty())


func test_duplicate_body_samples_only_fill_one_meter_per_frame() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = _effect(DeathCauseScript.LAVA)

	status.evaluate([effect, effect, effect], 0.25)

	assert_eq(status.statuses().size(), 1)
	assert_almost_eq(status.statuses()[0].level, 0.25, 0.001)


func test_higher_terrain_fill_uses_the_fastest_same_hazard_rate() -> void:
	var status = EnvironmentStatusScript.new()
	var low_fill = _effect(DeathCauseScript.LAVA)
	low_fill.fill_rate_multiplier = 0.1
	var full_fill = _effect(DeathCauseScript.LAVA)

	status.evaluate([low_fill, full_fill], 0.25)

	assert_almost_eq(status.statuses()[0].level, 0.25, 0.001)


func test_simultaneous_hazards_keep_independent_meters() -> void:
	var status = EnvironmentStatusScript.new()
	var suffocation = _effect(DeathCauseScript.SUFFOCATION)
	var lava = _effect(DeathCauseScript.LAVA)

	status.evaluate([suffocation, lava], 0.5)

	assert_eq(status.statuses().size(), 2)
	assert_almost_eq(status.statuses()[0].level, 0.5, 0.001)
	assert_almost_eq(status.statuses()[1].level, 0.5, 0.001)


func test_hazard_behaviors_expose_fill_thresholds() -> void:
	assert_eq(FixtureLoader.terrain_definition_named("Water").hazard_behavior.resolve().cause, DeathCauseScript.NONE)
	assert_eq(FixtureLoader.terrain_definition_named("Sand").hazard_behavior.resolve().cause, DeathCauseScript.NONE)
	assert_eq(FixtureLoader.terrain_definition_named("Lava").hazard_behavior.resolve().minimum_fill, 26)
	assert_eq(FixtureLoader.terrain_definition_named("Lava").hazard_behavior.resolve().fill_seconds, 0.2)
	assert_eq(FixtureLoader.terrain_definition_named("Lava").hazard_behavior.resolve().recovery_seconds, 1.0)
	assert_almost_eq(FixtureLoader.terrain_definition_named("Lava").hazard_behavior.resolve_for_fill(26).fill_rate_multiplier, 0.1, 0.001)
	assert_almost_eq(FixtureLoader.terrain_definition_named("Lava").hazard_behavior.resolve_for_fill(255).fill_rate_multiplier, 1.0, 0.001)


func test_hazard_effect_checks_fill_threshold() -> void:
	var effect = HazardEffectScript.new()
	effect.minimum_fill = 128

	assert_false(effect.applies_at_fill(127))
	assert_true(effect.applies_at_fill(128))


func test_hazard_behavior_resolves_only_when_fill_applies() -> void:
	var lava_hazard = FixtureLoader.terrain_definition_named("Lava").hazard_behavior

	assert_null(lava_hazard.resolve_for_fill(25))
	assert_not_null(lava_hazard.resolve_for_fill(26))
