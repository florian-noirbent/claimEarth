class_name SuffocationHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")

func _init() -> void:
	behavior_name = "suffocation"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.SUFFOCATION
	effect.exposure_seconds = 1.25
	return effect
