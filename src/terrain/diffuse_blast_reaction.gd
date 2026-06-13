class_name DiffuseBlastReaction
extends BlastReaction


@export_range(0.0, 1.0, 0.01) var attenuation_multiplier := 0.5


func _init() -> void:
	reaction_name = "diffuse"
