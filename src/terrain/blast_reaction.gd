@tool
class_name BlastReaction
extends Resource

const BlastEffectScript = preload("res://src/terrain/blast_effect.gd")

@export var reaction_name := ""


func resolve():
	return BlastEffectScript.new()
