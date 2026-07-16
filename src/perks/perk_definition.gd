@tool
## Player-facing identity and resource-authored behavior for a single perk.
class_name PerkDefinition
extends Resource


@export_range(1, 255, 1) var stable_id := 0
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var exclusion_group := ""
@export var effects: Array[PerkEffect] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if stable_id <= 0:
		errors.append("perk stable_id must be positive")
	if display_name.is_empty():
		errors.append("perk[%d] display_name is required" % stable_id)
	if description.is_empty():
		errors.append("perk[%d:%s] description is required" % [stable_id, display_name])
	if icon == null:
		errors.append("perk[%d:%s] icon is required" % [stable_id, display_name])
	for index in effects.size():
		var effect := effects[index]
		if effect == null:
			errors.append("perk[%d:%s] effect[%d] is null" % [stable_id, display_name, index])
			continue
		for error in effect.validate():
			errors.append("perk[%d:%s] effect[%d]: %s" % [stable_id, display_name, index, error])
	return errors
