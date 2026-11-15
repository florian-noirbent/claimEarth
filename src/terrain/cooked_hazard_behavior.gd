@tool
## Terrain hazard behavior for accumulated environmental heat.
class_name CookedHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")


func _init() -> void:
	behavior_name = "cooked"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.COOKED
	configure_meter(effect)
	return effect
