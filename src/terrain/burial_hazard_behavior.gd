class_name BurialHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")

func _init() -> void:
	behavior_name = "burial"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.BURIAL
	effect.exposure_seconds = 0.6
	effect.minimum_fill = 255
	return effect
