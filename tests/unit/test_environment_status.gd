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
