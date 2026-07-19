## Terrain hazard behavior for sulfuric-acid exposure.
class_name AcidHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")


func _init() -> void:
	behavior_name = "acid"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.ACID
	configure_meter(effect)
	return effect
