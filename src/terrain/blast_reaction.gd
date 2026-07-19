@tool
## Base resource contract for terrain behavior under explosions.
class_name BlastReaction
extends Resource

const BlastEffectScript = preload("res://src/terrain/blast_effect.gd")

@export var reaction_name := ""
## Optional product released only when this terrain is actually destroyed.
@export var destruction_emission: TerrainEmissionDefinition


func resolve():
	var effect := BlastEffectScript.new()
	effect.destruction_emission = destruction_emission
	return effect
