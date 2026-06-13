class_name TransformBlastReaction
extends BlastReaction


@export_range(0, 255) var target_terrain_id := 0


func _init() -> void:
	reaction_name = "transform"


func resolve():
	var effect = BlastEffectScript.new()
	effect.replacement_id = target_terrain_id
	return effect
