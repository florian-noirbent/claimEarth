class_name BoundarySealPass
extends GenerationPass


func get_name() -> String:
	return "boundary_seal"


func apply(context: GenerationContext) -> bool:
	var stone_id := _terrain_id(context.terrain_registry, "Stone")
	var depth := context.profile.depth

	for row in range(maxi(0, depth - 2), depth):
		for col in range(context.profile.width):
			context.world.set_committed_by_offset(col, row, stone_id)

	return true


func _terrain_id(registry: TerrainRegistry, name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == name:
			return definition.stable_id
	return -1
