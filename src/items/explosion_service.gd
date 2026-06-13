class_name ExplosionService
extends RefCounted


func explode(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	chunk_activity_index: ChunkActivityIndex,
	impact_position: Vector2,
	hex_radius: float,
	blast_radius: int
) -> Rect2i:
	var origin := HexMetrics.offset_for_world(impact_position, hex_radius)
	var queue: Array[Dictionary] = [{
		"cell": origin,
		"strength": float(blast_radius),
	}]
	var visited := {}
	var changed_cells: Array[Vector2i] = []

	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var cell := current["cell"] as Vector2i
		var strength := float(current["strength"])
		if strength < 0.0 or visited.has(cell):
			continue
		visited[cell] = true
		if not world.dimensions.is_in_bounds_offset(cell.x, cell.y):
			continue

		var definition := terrain_registry.get_definition(world.get_committed_by_offset(cell.x, cell.y))
		if definition == null:
			continue
		var effect = definition.blast_reaction.resolve()
		if effect.replacement_id >= 0 and effect.replacement_id != definition.stable_id:
			world.set_committed_by_offset(cell.x, cell.y, effect.replacement_id)
			changed_cells.append(cell)

		var propagated_strength: float = (strength - 1.0) * float(effect.propagation_multiplier)
		if propagated_strength < 0.0:
			continue
		for neighbor in HexCoord.from_offset_odd_q(cell.x, cell.y).neighbors():
			queue.append({
				"cell": neighbor.to_offset_odd_q(),
				"strength": propagated_strength,
			})

	if changed_cells.is_empty():
		return Rect2i(origin, Vector2i.ONE)

	var dirty_rect := _dirty_rect_from_cells(changed_cells)
	chunk_activity_index.mark_dirty_rect(dirty_rect)
	return dirty_rect


func _dirty_rect_from_cells(cells: Array[Vector2i]) -> Rect2i:
	var min_col := cells[0].x
	var max_col := cells[0].x
	var min_row := cells[0].y
	var max_row := cells[0].y
	for cell in cells:
		min_col = mini(min_col, cell.x)
		max_col = maxi(max_col, cell.x)
		min_row = mini(min_row, cell.y)
		max_row = maxi(max_row, cell.y)
	return Rect2i(min_col, min_row, max_col - min_col + 1, max_row - min_row + 1)
