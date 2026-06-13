class_name GenerationValidationPass
extends GenerationPass


func get_name() -> String:
	return "validation"


func apply(context: GenerationContext) -> bool:
	context.validation_errors = PackedStringArray()

	var stone_id := _terrain_id(context.terrain_registry, "Stone")
	var air_id := _terrain_id(context.terrain_registry, "Air")
	var width := context.profile.width
	var depth := context.profile.depth

	for row in range(depth):
		if context.world.get_committed_by_offset(0, row) != stone_id:
			context.validation_errors.append("left boundary is not sealed")
			break
		if context.world.get_committed_by_offset(width - 1, row) != stone_id:
			context.validation_errors.append("right boundary is not sealed")
			break

	for row in range(maxi(0, depth - 2), depth):
		for col in range(width):
			if context.world.get_committed_by_offset(col, row) != stone_id:
				context.validation_errors.append("bottom rows are not sealed")
				break

	for row in range(context.spawn_rect.position.y, context.spawn_rect.end.y):
		for col in range(context.spawn_rect.position.x, context.spawn_rect.end.x):
			if context.world.get_committed_by_offset(col, row) != air_id:
				context.validation_errors.append("spawn chamber contains non-air cells")
				break

	var air_total := context.world.count_committed(air_id)
	if air_total < int(width * depth * 0.08):
		context.validation_errors.append("world has too little air")

	return context.validation_errors.is_empty()


func _terrain_id(registry: TerrainRegistry, name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == name:
			return definition.stable_id
	return -1
