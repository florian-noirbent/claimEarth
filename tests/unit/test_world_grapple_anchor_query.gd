extends GutTest


const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")


func test_round_trip_world_to_offset_conversion_stays_on_same_hex_center() -> void:
	for col in range(0, 6):
		for row in range(0, 6):
			var center := HexMetrics.center_for_offset(col, row, 16.0)
			assert_eq(HexMetrics.offset_for_world(center, 16.0), Vector2i(col, row))


func test_query_returns_first_hookable_cell_on_probe_line() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(6, 6), 0)
	world.set_committed_by_offset(3, 2, 1)
	var query = WorldGrappleAnchorQueryScript.new()
	query.configure(world, registry, 16.0, 8.0)

	var anchor := query.find_anchor(Vector2.ZERO, HexMetrics.center_for_offset(3, 2, 16.0))

	assert_not_null(anchor)
	assert_eq(anchor.cell, Vector2i(3, 2))
	assert_ne(anchor.position, HexMetrics.center_for_offset(3, 2, 16.0) + Vector2(0.0, -12.0))
	assert_true(query.is_anchor_valid(anchor))


func test_query_does_not_scan_beyond_supplied_target() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(12, 2), 0)
	world.set_committed_by_offset(8, 0, 1)
	var query = WorldGrappleAnchorQueryScript.new()
	query.configure(world, registry, 16.0, 8.0)

	var anchor := query.find_anchor(Vector2.ZERO, Vector2.RIGHT * 120.0)

	assert_null(anchor)


func test_query_anchors_at_ray_contact_point_on_hex_edge() -> void:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(6, 2), 0)
	world.set_committed_by_offset(3, 0, 1)
	var query = WorldGrappleAnchorQueryScript.new()
	query.configure(world, registry, 16.0, 8.0)
	var center := HexMetrics.center_for_offset(3, 0, 16.0)

	var anchor := query.find_anchor(Vector2(0.0, center.y), center)

	assert_not_null(anchor)
	assert_eq(anchor.cell, Vector2i(3, 0))
	assert_almost_eq(anchor.position.x, center.x - 16.0, 0.001)
	assert_almost_eq(anchor.position.y, center.y, 0.001)


func test_runtime_perk_ranges_control_world_query_attachment() -> void:
	var base_movement := load(
		"res://config/player/default_movement.tres"
	) as PlayerMovementConfig
	var base_grapple := load(
		"res://config/player/default_grapple.tres"
	) as GrappleConfig

	assert_true(_can_attach_after_tuning(
		base_movement,
		base_grapple,
		_shipped_pool_modifiers([7]),
		12
	), "Acrobat should reach beyond the normal hook range")
	assert_false(_can_attach_after_tuning(
		base_movement,
		base_grapple,
		_shipped_pool_modifiers([15]),
		6
	), "Glass Cannon should reject anchors beyond its reduced hook range")
	assert_true(_can_attach_after_tuning(
		base_movement,
		base_grapple,
		_shipped_pool_modifiers([7, 15]),
		10
	), "Acrobat and Glass Cannon should retain the baseline hook range")
	assert_false(_can_attach_after_tuning(
		base_movement,
		base_grapple,
		_shipped_pool_modifiers([7, 15]),
		12
	), "Cancelled range modifiers should not retain Acrobat's extended range")


func _can_attach_after_tuning(
	base_movement: PlayerMovementConfig,
	base_grapple: GrappleConfig,
	modifiers: PerkModifierSnapshot,
	anchor_col: int
) -> bool:
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(16, 2), 0)
	world.set_committed_by_offset(anchor_col, 0, 1)
	var query = WorldGrappleAnchorQueryScript.new()
	query.configure(world, registry, 16.0, base_grapple.probe_step)

	var model := GrappleModel.new(base_grapple, query)
	model.config = PlayerRuntimeTuning.compile(
		base_movement,
		base_grapple,
		modifiers
	).grapple
	var input_frame := GrappleInputFrame.new()
	input_frame.hook_pressed = true
	input_frame.aim_position = HexMetrics.center_for_offset(anchor_col, 0, 16.0)
	model.update(input_frame, Vector2.ZERO, Vector2.ZERO, 0.016)
	return model.state.is_attached


func _shipped_pool_modifiers(ids: Array[int]) -> PerkModifierSnapshot:
	var registry := PerkRegistry.new()
	var catalog := load("res://config/perks/catalog.tres") as PerkCatalog
	assert_true(registry.try_configure(catalog), "\n".join(registry.validation_errors))
	var pool := PerkPool.new()
	pool.configure(registry)
	for id in ids:
		assert_true(pool.select(id))
	return pool.modifiers()
