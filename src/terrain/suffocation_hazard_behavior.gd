## Environmental hazard behavior for lack of breathable air.
class_name SuffocationHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")

func _init() -> void:
	behavior_name = "suffocation"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.SUFFOCATION
	configure_meter(effect)
	return effect
