@tool
class_name TerrainHazardBehavior
extends Resource

const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")

@export var behavior_name := ""


func resolve():
	return HazardEffectScript.new()
