class_name DetonateBlastReaction
extends BlastReaction


func _init() -> void:
	reaction_name = "detonate"


func resolve():
	var effect = BlastEffectScript.new()
	effect.detonate_immediately = true
	return effect
