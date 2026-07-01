## Terrain hazard behavior for full-fill water suffocation exposure.
class_name SuffocationHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")

func _init() -> void:
	behavior_name = "suffocation"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.SUFFOCATION
	effect.exposure_seconds = 3
	effect.minimum_fill = 255
	return effect
