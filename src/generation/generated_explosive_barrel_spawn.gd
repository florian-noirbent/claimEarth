## Carries one generated explosive barrel anchor and its deterministic spawn seed.
class_name GeneratedExplosiveBarrelSpawn
extends RefCounted


var anchor_offset := Vector2i.ZERO
var definition: ExplosiveBarrelDefinition
var spawn_seed := 0


func _init(
	anchor_offset_value := Vector2i.ZERO,
	definition_value: ExplosiveBarrelDefinition = null,
	spawn_seed_value := 0
) -> void:
	anchor_offset = anchor_offset_value
	definition = definition_value
	spawn_seed = spawn_seed_value
