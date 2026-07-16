@tool
## A reward container that draws a unique perk choice instead of item inventory.
class_name PerkGeodeDefinition
extends ItemChestDefinition


@export var perk_catalog: PerkCatalog


func requires_item_options() -> bool:
	return false


func record_spawn(context: GenerationContext, anchor: Vector2i, spawn_seed: int) -> bool:
	context.perk_geode_spawns.append(GeneratedItemChestSpawn.new(anchor, self, spawn_seed))
	return true


func validate() -> PackedStringArray:
	var errors := super.validate()
	if perk_catalog == null:
		errors.append("perk geode definition requires a perk catalog")
	elif not perk_catalog.validate().is_empty():
		for error in perk_catalog.validate():
			errors.append("perk catalog: %s" % error)
	return errors
