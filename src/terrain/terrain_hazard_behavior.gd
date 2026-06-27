@tool
class_name TerrainHazardBehavior
extends Resource

const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")

@export var behavior_name := ""


func resolve():
	return HazardEffectScript.new()


func resolve_for_fill(fill: int):
	var effect = resolve()
	if effect == null or not effect.applies_at_fill(fill):
		return null
	return effect
