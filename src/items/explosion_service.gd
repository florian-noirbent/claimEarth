## Applies blast reactions to terrain and reports exact changed cells.
class_name ExplosionService
extends RefCounted


func explode(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	chunk_activity_index: ChunkActivityIndex,
	impact_position: Vector2,
	hex_radius: float,
	blast_radius: int,
	lethal_radius: int = 0
) -> Rect2i:
	return explode_with_changes(world, terrain_registry, chunk_activity_index, impact_position, hex_radius, blast_radius, lethal_radius).dirty_rect


func explode_with_changes(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	chunk_activity_index: ChunkActivityIndex,
	impact_position: Vector2,
	hex_radius: float,
	blast_radius: int,
	lethal_radius: int = 0
) -> TerrainChangeSet:
	var origin := HexMetrics.offset_for_world(impact_position, hex_radius)
	var air_id := _terrain_id(terrain_registry, "Air")
	var metadata := CompiledTerrainData.compile(terrain_registry)
	var change_set := TerrainChangeSet.new(world.dimensions, chunk_activity_index.chunk_width, chunk_activity_index.chunk_height)
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
			_enqueue_neighbors(queue, cell, strength - 1.0)
			continue

		var definition := terrain_registry.get_definition(world.get_committed_by_offset(cell.x, cell.y))
		if definition == null:
			continue
		var propagated_strength := strength - 1.0
		if _is_within_radius(origin, cell, lethal_radius):
			if definition.stable_id != air_id:
				var change := world.set_committed_by_offset(cell.x, cell.y, air_id)
				change_set.add_change(change.index, change.previous_id, change.next_id, metadata)
				changed_cells.append(cell)
		else:
			var effect = definition.blast_reaction.resolve()
			if effect.replacement_id >= 0 and effect.replacement_id != definition.stable_id:
				var change := world.set_committed_by_offset(cell.x, cell.y, effect.replacement_id)
				change_set.add_change(change.index, change.previous_id, change.next_id, metadata)
				changed_cells.append(cell)
			propagated_strength = (strength - 1.0) * float(effect.propagation_multiplier)

		if propagated_strength < 0.0:
			continue
		_enqueue_neighbors(queue, cell, propagated_strength)

	if changed_cells.is_empty():
		change_set.dirty_rect = Rect2i(origin, Vector2i.ONE)
		return change_set

	chunk_activity_index.mark_change_set(change_set)
	return change_set


func _enqueue_neighbors(queue: Array[Dictionary], cell: Vector2i, strength: float) -> void:
	if strength < 0.0:
		return
	for neighbor in HexCoord.from_offset_odd_q(cell.x, cell.y).neighbors():
		queue.append({
			"cell": neighbor.to_offset_odd_q(),
			"strength": strength,
		})


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


func _is_within_radius(origin: Vector2i, cell: Vector2i, radius: int) -> bool:
	if radius <= 0:
		return false
	return HexCoord.from_offset_odd_q(origin.x, origin.y).distance_to(HexCoord.from_offset_odd_q(cell.x, cell.y)) <= radius


func _terrain_id(registry: TerrainRegistry, name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == name:
			return definition.stable_id
	return -1
