extends GutTest


const ExplosionRuntimeSpecScript = preload("res://src/items/explosion_runtime_spec.gd")


func test_explosion_applies_registered_blast_reactions_and_reports_changed_region() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), 0)
	var stone_id := registry.get_definition(1).stable_id
	var dirt_id := registry.get_definition(2).stable_id
	var sand_id := registry.get_definition(3).stable_id
	var water_id := registry.get_definition(4).stable_id
	world.set_committed_by_offset(3, 3, stone_id)
	world.set_committed_by_offset(4, 3, dirt_id)
	world.set_committed_by_offset(5, 3, sand_id)
	world.set_committed_by_offset(3, 4, water_id)
	var service := ExplosionService.new()

	var dirty_rect := service.explode(
		world,
		registry,
		HexMetrics.center_for_offset(3, 3, 16.0),
		16.0,
		2
	)

	assert_eq(world.get_committed_by_offset(3, 3), dirt_id)
	assert_eq(world.get_committed_by_offset(4, 3), sand_id)
	assert_eq(world.get_committed_by_offset(5, 3), 0)
	assert_eq(world.get_committed_by_offset(3, 4), water_id)
	assert_true(dirty_rect.has_point(Vector2i(3, 3)))


func test_explosion_vaporizes_terrain_within_lethal_radius_regardless_of_type() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(7, 7), 1)
	var service := ExplosionService.new()

	world.set_committed_by_offset(3, 3, FixtureLoader.terrain_id("Stone"))
	world.set_committed_by_offset(4, 3, FixtureLoader.terrain_id("Water"))
	world.set_committed_by_offset(3, 4, FixtureLoader.terrain_id("Lava"))
	world.set_committed_by_offset(2, 3, FixtureLoader.terrain_id("Sand"))

	service.explode(
		world,
		registry,
		HexMetrics.center_for_offset(3, 3, 16.0),
		16.0,
		3,
		1
	)

	assert_eq(world.get_committed_by_offset(3, 3), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(4, 3), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(3, 4), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(2, 3), FixtureLoader.terrain_id("Air"))


func test_explosion_above_top_row_propagates_into_world() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var stone_id := FixtureLoader.terrain_id("Stone")
	var air_id := FixtureLoader.terrain_id("Air")
	var world := WorldGrid.new(WorldDimensions.new(7, 7), stone_id)
	var service := ExplosionService.new()

	var change_set := service.explode_with_changes(
		world,
		registry,
		HexMetrics.center_for_offset(3, -1, 16.0),
		16.0,
		2,
		1
	)

	assert_eq(world.get_committed_by_offset(3, 0), air_id)
	assert_gt(change_set.changed_cell_count(), 0)


func test_explosion_result_reports_inclusive_lethal_core_cells() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 12), FixtureLoader.terrain_id("Air"))
	var service := ExplosionService.new()
	var origin := Vector2i(5, 5)

	var result := service.resolve(
		world,
		registry,
		HexMetrics.center_for_offset(origin.x, origin.y, 16.0),
		16.0,
		5,
		3
	)

	assert_eq(result.lethal_cells.size(), 37)
	assert_true(result.lethal_cells.has(origin))
	assert_true(result.lethal_cells.has(HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(3, 0)).to_offset_odd_q()))
	assert_false(result.lethal_cells.has(HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(4, 0)).to_offset_odd_q()))


func test_runtime_spec_separates_blast_vaporize_and_player_kill_radii() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 12), FixtureLoader.terrain_id("Stone"))
	var service := ExplosionService.new()
	var origin := Vector2i(5, 5)
	var spec = ExplosionRuntimeSpecScript.new()
	spec.blast_radius = 4
	spec.vaporize_radius = 1
	spec.player_kill_radius = 3

	var result := service.resolve_spec(
		world,
		registry,
		HexMetrics.center_for_offset(origin.x, origin.y, 16.0),
		16.0,
		spec
	)

	assert_eq(result.destructive_core_cells.size(), 7)
	assert_eq(result.lethal_cells, result.destructive_core_cells)
	assert_eq(world.get_committed_by_offset(origin.x, origin.y), FixtureLoader.terrain_id("Air"))
	var blast_only := HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(2, 0)).to_offset_odd_q()
	assert_eq(world.get_committed_by_offset(blast_only.x, blast_only.y), FixtureLoader.terrain_id("Dirt"))


func test_fluid_vaporize_radius_can_expand_without_expanding_solid_vaporization() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 12), FixtureLoader.terrain_id("Stone"))
	var origin := Vector2i(5, 5)
	var water_cell := HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(3, 0)).to_offset_odd_q()
	var stone_cell := HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(2, 0)).to_offset_odd_q()
	world.set_committed_by_offset(water_cell.x, water_cell.y, FixtureLoader.terrain_id("Water"))
	var spec = ExplosionRuntimeSpecScript.new()
	spec.blast_radius = 3
	spec.vaporize_radius = 1
	spec.player_kill_radius = 1
	spec.fluid_vaporize_radius_bonus = func(definition: TerrainDefinition) -> int:
		return 2 if definition.perk_tags.has("liquid") else 0

	ExplosionService.new().resolve_spec(world, registry, HexMetrics.center_for_offset(origin.x, origin.y, 16.0), 16.0, spec)

	assert_eq(world.get_committed_by_offset(water_cell.x, water_cell.y), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(stone_cell.x, stone_cell.y), FixtureLoader.terrain_id("Dirt"))


func test_blast_vaporize_chance_can_replace_dirt_blast_reaction() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(9, 9), FixtureLoader.terrain_id("Air"))
	var origin := Vector2i(4, 4)
	var dirt_cell := HexCoord.from_offset_odd_q(origin.x, origin.y).add(HexCoord.new(2, 0)).to_offset_odd_q()
	world.set_committed_by_offset(dirt_cell.x, dirt_cell.y, FixtureLoader.terrain_id("Dirt"))
	var spec = ExplosionRuntimeSpecScript.new()
	spec.blast_radius = 2
	spec.vaporize_radius = 1
	spec.player_kill_radius = 1
	spec.blast_vaporize_chance = func(definition: TerrainDefinition, _cell: Vector2i) -> float:
		return 1.0 if definition.perk_tags.has("dirt") else 0.0

	ExplosionService.new().resolve_spec(world, registry, HexMetrics.center_for_offset(origin.x, origin.y, 16.0), 16.0, spec)

	assert_eq(world.get_committed_by_offset(dirt_cell.x, dirt_cell.y), FixtureLoader.terrain_id("Air"))


func test_destroyed_sulfur_emits_fifteen_bars_of_sulfur_dioxide() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(9, 9), FixtureLoader.terrain_id("Air"))
	var origin := Vector2i(4, 4)
	world.set_committed_by_offset(origin.x, origin.y, FixtureLoader.terrain_id("Sulfur"), 127)

	ExplosionService.new().resolve(
		world,
		registry,
		HexMetrics.center_for_offset(origin.x, origin.y, 16.0),
		16.0,
		2,
		1
	)

	assert_eq(world.get_committed_by_offset(origin.x, origin.y), FixtureLoader.terrain_id("Sulfur Dioxide"))
	assert_eq(_component_quantity(world, FixtureLoader.terrain_id("Sulfur Dioxide")), 9450)


func test_explosion_displaces_existing_sulfur_dioxide_outside_its_vaporize_core() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(11, 11), FixtureLoader.terrain_id("Air"))
	var origin := Vector2i(5, 5)
	var sulfur_dioxide_id := FixtureLoader.terrain_id("Sulfur Dioxide")
	world.set_committed_by_offset(origin.x, origin.y, sulfur_dioxide_id, 200)

	ExplosionService.new().resolve(
		world,
		registry,
		HexMetrics.center_for_offset(origin.x, origin.y, 16.0),
		16.0,
		3,
		1
	)

	assert_eq(_component_quantity(world, sulfur_dioxide_id), 200)
	for cell in _cells_within_radius(origin, 1):
		assert_ne(world.get_committed_by_offset(cell.x, cell.y), sulfur_dioxide_id)
		assert_ne(world.get_committed_secondary_by_offset(cell.x, cell.y), sulfur_dioxide_id)


func _cells_within_radius(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center := HexCoord.from_offset_odd_q(origin.x, origin.y)
	for delta_q in range(-radius, radius + 1):
		for delta_r in range(maxi(-radius, -delta_q - radius), mini(radius, -delta_q + radius) + 1):
			cells.append(center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q())
	return cells


func test_emission_uses_empty_secondary_slots_when_primary_capacity_is_unavailable() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Stone"))
	var product := registry.get_definition(FixtureLoader.terrain_id("Sulfur Dioxide"))
	var changes := TerrainChangeSet.new(world.dimensions)

	ExplosionService.new()._deposit_emission(
		world,
		registry,
		CompiledTerrainData.compile(registry),
		changes,
		Vector2i(2, 2),
		product,
		945
	)

	assert_eq(_component_quantity(world, product.stable_id), 945)
	assert_eq(world.get_committed_by_offset(2, 2), FixtureLoader.terrain_id("Stone"))
	assert_eq(world.get_committed_secondary_by_offset(2, 2), product.stable_id)
	assert_false(changes.is_empty())


func _component_quantity(world: WorldGrid, terrain_id: int) -> int:
	var total := 0
	for row in range(world.dimensions.depth):
		for col in range(world.dimensions.width):
			if world.get_committed_by_offset(col, row) == terrain_id:
				total += world.get_committed_quantity_by_offset(col, row)
			if world.get_committed_secondary_by_offset(col, row) == terrain_id:
				total += world.get_committed_secondary_quantity_by_offset(col, row)
	return total
