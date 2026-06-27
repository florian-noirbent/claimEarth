extends GutTest


const EnvironmentStatusScript = preload("res://src/player/environment_status.gd")
const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")
const DeathCauseScript = preload("res://src/player/death_cause.gd")


func test_immediate_lava_effect_returns_lava_cause() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.LAVA
	effect.lethal_on_touch = true

	assert_eq(status.evaluate([effect], 0.016), DeathCauseScript.LAVA)


func test_suffocation_requires_exposure_time() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.SUFFOCATION
	effect.exposure_seconds = 1.0

	assert_eq(status.evaluate([effect], 0.4), DeathCauseScript.NONE)
	assert_eq(status.evaluate([effect], 0.4), DeathCauseScript.NONE)
	assert_eq(status.evaluate([effect], 0.3), DeathCauseScript.SUFFOCATION)


func test_missing_effect_resets_timer() -> void:
	var status = EnvironmentStatusScript.new()
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.BURIAL
	effect.exposure_seconds = 1.0

	assert_eq(status.evaluate([effect], 0.8), DeathCauseScript.NONE)
	assert_eq(status.evaluate([], 0.8), DeathCauseScript.NONE)
	assert_eq(status.evaluate([effect], 0.3), DeathCauseScript.NONE)


func test_hazard_behaviors_expose_fill_thresholds() -> void:
	assert_eq(FixtureLoader.terrain_definition_named("Water").hazard_behavior.resolve().minimum_fill, 255)
	assert_eq(FixtureLoader.terrain_definition_named("Sand").hazard_behavior.resolve().minimum_fill, 255)
	assert_eq(FixtureLoader.terrain_definition_named("Lava").hazard_behavior.resolve().minimum_fill, 26)


func test_hazard_effect_checks_fill_threshold() -> void:
	var effect = HazardEffectScript.new()
	effect.minimum_fill = 128

	assert_false(effect.applies_at_fill(127))
	assert_true(effect.applies_at_fill(128))


func test_hazard_behavior_resolves_only_when_fill_applies() -> void:
	var lava_hazard = FixtureLoader.terrain_definition_named("Lava").hazard_behavior

	assert_null(lava_hazard.resolve_for_fill(25))
	assert_not_null(lava_hazard.resolve_for_fill(26))
