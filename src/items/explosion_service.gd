## Applies blast reactions to terrain and reports exact changed cells.
class_name ExplosionService
extends RefCounted

const ExplosionRuntimeSpecScript = preload("res://src/items/explosion_runtime_spec.gd")

func explode(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	impact_position: Vector2,
	hex_radius: float,
	blast_radius: int,
	vaporize_radius: int = 0
) -> Rect2i:
	return resolve(world, terrain_registry, impact_position, hex_radius, blast_radius, vaporize_radius).terrain_changes.dirty_rect


func explode_with_changes(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	impact_position: Vector2,
	hex_radius: float,
	blast_radius: int,
	vaporize_radius: int = 0
) -> TerrainChangeSet:
	return resolve(world, terrain_registry, impact_position, hex_radius, blast_radius, vaporize_radius).terrain_changes


func resolve(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	impact_position: Vector2,
	hex_radius: float,
	blast_radius: int,
	vaporize_radius: int = 0
) -> ExplosionResult:
	var spec = ExplosionRuntimeSpecScript.new()
	spec.blast_radius = blast_radius
	spec.vaporize_radius = vaporize_radius
	spec.player_kill_radius = vaporize_radius
	return resolve_spec(world, terrain_registry, impact_position, hex_radius, spec)


func resolve_spec(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	impact_position: Vector2,
	hex_radius: float,
	spec
) -> ExplosionResult:
	if spec == null or not spec.validate().is_empty():
		return ExplosionResult.new(TerrainChangeSet.new(world.dimensions))
	var origin := HexMetrics.offset_for_world(impact_position, hex_radius)
	var air_id := _terrain_id(terrain_registry, "Air")
	var metadata := CompiledTerrainData.compile(terrain_registry)
	var change_set := TerrainChangeSet.new(world.dimensions)
	var queue: Array[Dictionary] = [{
		"cell": origin,
		"strength": float(spec.blast_radius),
	}]
	var visited := {}
	var changed_cells: Array[Vector2i] = []
	## Start with the inclusive base core, preserving old chain behavior even when
	## those cells contain Air. Terrain-specific extensions can add to it below.
	var destructive_core_cells := _cells_within_radius(origin, spec.vaporize_radius)

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
		if _is_within_radius(origin, cell, spec.vaporize_radius_for(definition)):
			if not destructive_core_cells.has(cell):
				destructive_core_cells.append(cell)
			if definition.stable_id != air_id:
				var change := world.set_committed_by_offset(cell.x, cell.y, air_id)
				change_set.add_cell_change(change, metadata)
				changed_cells.append(cell)
		else:
			var effect = definition.blast_reaction.resolve()
			var replacement_id: int = effect.replacement_id
			if _roll_blast_vaporize(spec, definition, cell, origin):
				replacement_id = air_id
			if replacement_id >= 0 and replacement_id != definition.stable_id:
				var change := world.set_committed_by_offset(cell.x, cell.y, replacement_id)
				change_set.add_cell_change(change, metadata)
				changed_cells.append(cell)
			propagated_strength = (strength - 1.0) * float(effect.propagation_multiplier)

		if propagated_strength < 0.0:
			continue
		_enqueue_neighbors(queue, cell, propagated_strength)

	if changed_cells.is_empty():
		change_set.dirty_rect = Rect2i(origin, Vector2i.ONE)
		return ExplosionResult.new(change_set, destructive_core_cells)

	return ExplosionResult.new(change_set, destructive_core_cells)


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


func _cells_within_radius(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius <= 0:
		return result
	var center := HexCoord.from_offset_odd_q(origin.x, origin.y)
	for delta_q in range(-radius, radius + 1):
		var min_delta_r := maxi(-radius, -delta_q - radius)
		var max_delta_r := mini(radius, -delta_q + radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			result.append(center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q())
	return result


func _roll_blast_vaporize(spec: ExplosionRuntimeSpec, definition: TerrainDefinition, cell: Vector2i, origin: Vector2i) -> bool:
	var chance: float = spec.blast_vaporize_chance_for(definition, cell)
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	var seed := SeedUtils.derive_seed(
		origin.x * 73856093 + origin.y * 19349663,
		"%d:%d:%d" % [cell.x, cell.y, definition.stable_id]
	)
	return float(posmod(seed, 1000000)) / 1000000.0 < chance


func _terrain_id(registry: TerrainRegistry, name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == name:
			return definition.stable_id
	return -1
