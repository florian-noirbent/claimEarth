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
	var terrain_emissions: Array[Dictionary] = []
	var displaced_sulfur_dioxide_quantity := 0
	var sulfur_dioxide_displacement_radius := 0
	var sulfur_dioxide_id := _terrain_id(terrain_registry, "Sulfur Dioxide")
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

		var source_id := world.get_committed_by_offset(cell.x, cell.y)
		var source_quantity := world.get_committed_quantity_by_offset(cell.x, cell.y)
		var source_secondary_id := world.get_committed_secondary_by_offset(cell.x, cell.y)
		var source_secondary_quantity := world.get_committed_secondary_quantity_by_offset(cell.x, cell.y)
		var definition := terrain_registry.get_definition(source_id)
		if definition == null:
			continue
		var propagated_strength := strength - 1.0
		var effect = definition.blast_reaction.resolve()
		var destroyed := false
		var vaporize_radius_for_cell: int = spec.vaporize_radius_for(definition)
		if _is_within_radius(origin, cell, vaporize_radius_for_cell):
			if not destructive_core_cells.has(cell):
				destructive_core_cells.append(cell)
			if source_id == sulfur_dioxide_id:
				displaced_sulfur_dioxide_quantity += source_quantity
			if source_secondary_id == sulfur_dioxide_id:
				displaced_sulfur_dioxide_quantity += source_secondary_quantity
			if source_id == sulfur_dioxide_id or source_secondary_id == sulfur_dioxide_id:
				sulfur_dioxide_displacement_radius = maxi(sulfur_dioxide_displacement_radius, vaporize_radius_for_cell + 1)
			if definition.stable_id != air_id or source_secondary_quantity > 0:
				var change := world.set_committed_by_offset(cell.x, cell.y, air_id)
				change_set.add_cell_change(change, metadata)
				changed_cells.append(cell)
				destroyed = true
		else:
			var replacement_id: int = effect.replacement_id
			if _roll_blast_vaporize(spec, definition, cell, origin):
				replacement_id = air_id
			if replacement_id >= 0 and replacement_id != definition.stable_id:
				var change := world.set_committed_by_offset(cell.x, cell.y, replacement_id)
				change_set.add_cell_change(change, metadata)
				changed_cells.append(cell)
				destroyed = true
			propagated_strength = (strength - 1.0) * float(effect.propagation_multiplier)
		if destroyed and effect.destruction_emission != null:
			terrain_emissions.append({
				"cell": cell,
				"source": definition,
				"primary_quantity": source_quantity,
				"secondary_id": source_secondary_id,
				"secondary_quantity": source_secondary_quantity,
				"emission": effect.destruction_emission,
			})

		if propagated_strength < 0.0:
			continue
		_enqueue_neighbors(queue, cell, propagated_strength)

	_apply_terrain_emissions(
		world,
		terrain_registry,
		metadata,
		change_set,
		terrain_emissions,
		spec.perk_terrain_emissions,
		origin,
		sulfur_dioxide_id,
		displaced_sulfur_dioxide_quantity,
		sulfur_dioxide_displacement_radius
	)

	if changed_cells.is_empty() and change_set.is_empty():
		change_set.dirty_rect = Rect2i(origin, Vector2i.ONE)
		return ExplosionResult.new(change_set, destructive_core_cells)

	return ExplosionResult.new(change_set, destructive_core_cells)


func _apply_terrain_emissions(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	metadata: CompiledTerrainData,
	change_set: TerrainChangeSet,
	terrain_emissions: Array[Dictionary],
	perk_emissions: Array[TerrainEmissionDefinition],
	origin: Vector2i,
	sulfur_dioxide_id: int,
	displaced_sulfur_dioxide_quantity: int,
	sulfur_dioxide_displacement_radius: int
) -> void:
	if displaced_sulfur_dioxide_quantity > 0:
		var sulfur_dioxide := terrain_registry.get_definition(sulfur_dioxide_id)
		if sulfur_dioxide != null:
			_deposit_emission(
				world,
				terrain_registry,
				metadata,
				change_set,
				origin,
				sulfur_dioxide,
				displaced_sulfur_dioxide_quantity,
				sulfur_dioxide_displacement_radius
			)
	terrain_emissions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_cell := a["cell"] as Vector2i
		var b_cell := b["cell"] as Vector2i
		var a_distance := HexCoord.from_offset_odd_q(origin.x, origin.y).distance_to(HexCoord.from_offset_odd_q(a_cell.x, a_cell.y))
		var b_distance := HexCoord.from_offset_odd_q(origin.x, origin.y).distance_to(HexCoord.from_offset_odd_q(b_cell.x, b_cell.y))
		return a_cell.y < b_cell.y or (a_cell.y == b_cell.y and a_cell.x < b_cell.x) if a_distance == b_distance else a_distance < b_distance
	)
	for entry in terrain_emissions:
		var emission := entry["emission"] as TerrainEmissionDefinition
		var source := entry["source"] as TerrainDefinition
		if emission == null or source == null:
			continue
		var product_id := emission.product.stable_id
		var quantity := emission.quantity
		if emission.scale_by_source_quantity:
			quantity = roundi(float(quantity) * float(entry["primary_quantity"]) / float(maxi(1, source.maximum_quantity)))
		if int(entry["secondary_id"]) == product_id:
			quantity += int(entry["secondary_quantity"])
		_deposit_emission(world, terrain_registry, metadata, change_set, entry["cell"] as Vector2i, emission.product, quantity)
	for emission in perk_emissions:
		if emission != null:
			_deposit_emission(world, terrain_registry, metadata, change_set, origin, emission.product, emission.quantity)


func _deposit_emission(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	metadata: CompiledTerrainData,
	change_set: TerrainChangeSet,
	origin: Vector2i,
	product: TerrainDefinition,
	quantity: int,
	minimum_distance: int = 0
) -> void:
	if product == null or quantity <= 0:
		return
	var product_id := product.stable_id
	var remaining := quantity
	var frontier: Array[Vector2i] = [origin]
	var visited := {}
	var distance := 0
	while not frontier.is_empty() and remaining > 0:
		frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)
		var next_frontier: Array[Vector2i] = []
		if distance >= minimum_distance:
			for stage in range(4):
				for cell in frontier:
					if remaining <= 0 or not world.dimensions.is_in_bounds_offset(cell.x, cell.y):
						continue
					remaining -= _deposit_into_stage(world, terrain_registry, metadata, change_set, cell, product, product_id, remaining, stage)
		for cell in frontier:
			if visited.has(cell):
				continue
			visited[cell] = true
			for neighbor in HexCoord.from_offset_odd_q(cell.x, cell.y).neighbors():
				var offset := neighbor.to_offset_odd_q()
				if not visited.has(offset) and not next_frontier.has(offset):
					next_frontier.append(offset)
		frontier = next_frontier
		distance += 1


func _deposit_into_stage(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	metadata: CompiledTerrainData,
	change_set: TerrainChangeSet,
	cell: Vector2i,
	product: TerrainDefinition,
	product_id: int,
	remaining: int,
	stage: int
) -> int:
	var primary_id := world.get_committed_by_offset(cell.x, cell.y)
	var primary_quantity := world.get_committed_quantity_by_offset(cell.x, cell.y)
	var secondary_id := world.get_committed_secondary_by_offset(cell.x, cell.y)
	var secondary_quantity := world.get_committed_secondary_quantity_by_offset(cell.x, cell.y)
	var capacity := 0
	if stage == 0 and primary_id == product_id:
		capacity = maxi(0, product.storage_capacity - primary_quantity)
		if capacity > 0:
			var accepted := mini(remaining, capacity)
			_commit_components(world, metadata, change_set, cell, primary_id, primary_quantity + accepted, secondary_id, secondary_quantity)
			return accepted
	if stage == 1:
		var primary: TerrainDefinition = terrain_registry.get_definition(primary_id)
		if primary != null and primary.is_empty_space and secondary_quantity <= 0:
			var accepted := mini(remaining, product.storage_capacity)
			_commit_components(world, metadata, change_set, cell, product_id, accepted)
			return accepted
	if stage == 2 and secondary_id == product_id and secondary_quantity > 0:
		capacity = maxi(0, product.storage_capacity - secondary_quantity)
		if capacity > 0:
			var accepted := mini(remaining, capacity)
			_commit_components(world, metadata, change_set, cell, primary_id, primary_quantity, secondary_id, secondary_quantity + accepted)
			return accepted
	if stage == 3 and secondary_quantity <= 0 and primary_id != product_id:
		## A matching marker in an otherwise unburning static terrain starts its
		## persistent reaction, so do not create one as overflow storage.
		if metadata.persistent_burn_product_by_id[primary_id] == product_id:
			return 0
		var accepted := mini(remaining, product.storage_capacity)
		_commit_components(world, metadata, change_set, cell, primary_id, primary_quantity, product_id, accepted)
		return accepted
	return 0


func _commit_components(
	world: WorldGrid,
	metadata: CompiledTerrainData,
	change_set: TerrainChangeSet,
	cell: Vector2i,
	primary_id: int,
	primary_quantity: int,
	secondary_id: int = 0,
	secondary_quantity: int = 0
) -> void:
	var change := world.set_committed_components_by_offset(cell.x, cell.y, primary_id, primary_quantity, secondary_id, secondary_quantity)
	change_set.add_cell_change(change, metadata)


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
