## Terrain hazard behavior for sulfur-dioxide exposure.
class_name PoisonHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")


func _init() -> void:
	behavior_name = "poison"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.POISON
	configure_meter(effect)
	return effect
