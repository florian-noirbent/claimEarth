## Carries one generated item chest anchor and deterministic reward seed.
class_name GeneratedItemChestSpawn
extends RefCounted


var anchor_offset := Vector2i.ZERO
var definition: ItemChestDefinition
var choice_seed := 0


func _init(
	anchor_offset_value := Vector2i.ZERO,
	definition_value: ItemChestDefinition = null,
	choice_seed_value := 0
) -> void:
	anchor_offset = anchor_offset_value
	definition = definition_value
	choice_seed = choice_seed_value
