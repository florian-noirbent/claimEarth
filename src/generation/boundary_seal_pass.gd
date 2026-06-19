@tool
extends GenerationPassResource


@export_range(1, 16, 1) var sealed_row_count := 2

func get_pass_type_name() -> String:
	return "Boundary Seal"


func get_progress_label() -> String:
	return "Finalizing map"


func _default_seed_key() -> String:
	return "boundary_seal_%d" % Time.get_ticks_usec()


func apply(context: GenerationContext) -> bool:
	var stone_id := terrain_id(context.terrain_registry, "Stone")
	var depth := context.profile.depth

	for row in range(maxi(0, depth - sealed_row_count), depth):
		for col in range(context.profile.width):
			context.world.set_committed_by_offset(col, row, stone_id)

	return true
