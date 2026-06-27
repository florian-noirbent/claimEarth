@tool
## Carves the initial safe spawn area from generated terrain.
extends GenerationPassResource


func get_pass_type_name() -> String:
	return "Spawn Chamber"


func get_progress_label() -> String:
	return "Carving spawn chamber"


func _default_seed_key() -> String:
	return "spawn_chamber_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	var air_id := terrain_id(context.terrain_registry, "Air")
	var dirt_id := terrain_id(context.terrain_registry, "Dirt")
	var center_col := int(context.profile.width >> 1)
	var start_col := maxi(1, center_col - int(context.profile.spawn_width >> 1))
	var start_row := context.profile.spawn_margin_top
	context.spawn_rect = Rect2i(start_col, start_row, context.profile.spawn_width, context.profile.spawn_height)

	for row in range(context.spawn_rect.position.y, context.spawn_rect.end.y):
		for col in range(context.spawn_rect.position.x, context.spawn_rect.end.x):
			context.world.set_committed_by_offset(col, row, air_id)

	var floor_row := context.spawn_rect.end.y - 1
	for col in range(context.spawn_rect.position.x + 1, context.spawn_rect.end.x - 1):
		context.world.set_committed_by_offset(col, floor_row, dirt_id)

	return true
