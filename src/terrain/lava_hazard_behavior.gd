class_name LavaHazardBehavior
extends TerrainHazardBehavior

const DeathCauseScript = preload("res://src/player/death_cause.gd")

func _init() -> void:
	behavior_name = "lava"


func resolve():
	var effect = HazardEffectScript.new()
	effect.cause = DeathCauseScript.LAVA
	effect.lethal_on_touch = true
	return effect
