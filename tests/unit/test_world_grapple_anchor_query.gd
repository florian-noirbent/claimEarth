extends GutTest


const WorldGrappleAnchorQueryScript = preload("res://src/player/world_grapple_anchor_query.gd")


class FakeGrappleTarget:
	extends GrappleTarget

	var valid := true
	var center := Vector2.ZERO
	var circle_radius := 8.0

	func _init(center_value: Vector2 = Vector2.ZERO, radius_value: float = 8.0) -> void:
		center = center_value
		circle_radius = radius_value

	func is_valid() -> bool:
		return valid

	func anchor_position() -> Vector2:
		return center

	func radius() -> float:
		return circle_radius


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


func test_ray_hits_target_before_farther_terrain() -> void:
	var targets := GrappleTargetRegistry.new()
	var target := FakeGrappleTarget.new(Vector2(96.0, _lane_y()))
	targets.register(target)
	var query = _lane_query([8], targets)

	var anchor: GrappleAnchor = query.find_anchor(Vector2(0.0, _lane_y()), Vector2(300.0, _lane_y()))

	assert_not_null(anchor)
	assert_eq(anchor.target, target)
	assert_true(anchor.is_target())
	assert_almost_eq(anchor.position.x, 88.0, 0.001, "Anchor contact is where the ray enters the circle")
	assert_almost_eq(anchor.position.y, _lane_y(), 0.001)
	assert_true(query.is_anchor_valid(anchor))


func test_terrain_between_player_and_target_blocks_it() -> void:
	var targets := GrappleTargetRegistry.new()
	targets.register(FakeGrappleTarget.new(Vector2(160.0, _lane_y())))
	var query = _lane_query([4], targets)

	var anchor: GrappleAnchor = query.find_anchor(Vector2(0.0, _lane_y()), Vector2(300.0, _lane_y()))

	assert_not_null(anchor)
	assert_false(anchor.is_target())
	assert_eq(anchor.cell, Vector2i(4, 1))


func test_ray_returns_nearest_valid_target() -> void:
	var targets := GrappleTargetRegistry.new()
	var far_target := FakeGrappleTarget.new(Vector2(200.0, _lane_y()))
	var near_target := FakeGrappleTarget.new(Vector2(120.0, _lane_y()))
	var invalid_target := FakeGrappleTarget.new(Vector2(60.0, _lane_y()))
	invalid_target.valid = false
	targets.register(far_target)
	targets.register(invalid_target)
	targets.register(near_target)
	var query = _lane_query([], targets)

	var anchor: GrappleAnchor = query.find_anchor(Vector2(0.0, _lane_y()), Vector2(300.0, _lane_y()))

	assert_not_null(anchor)
	assert_eq(anchor.target, near_target)
	assert_almost_eq(anchor.position.x, 112.0, 0.001)


func test_ray_ignores_targets_off_line_behind_or_out_of_range() -> void:
	var targets := GrappleTargetRegistry.new()
	targets.register(FakeGrappleTarget.new(Vector2(100.0, _lane_y() + 20.0)))
	targets.register(FakeGrappleTarget.new(Vector2(-60.0, _lane_y())))
	targets.register(FakeGrappleTarget.new(Vector2(260.0, _lane_y())))
	targets.register(FakeGrappleTarget.new(Vector2(140.0, _lane_y()), 0.0))
	var query = _lane_query([], targets)

	assert_null(query.find_anchor(Vector2(0.0, _lane_y()), Vector2(240.0, _lane_y())))


func test_ray_starting_inside_target_hits_it_only_toward_its_center() -> void:
	var targets := GrappleTargetRegistry.new()
	var target := FakeGrappleTarget.new(Vector2(100.0, _lane_y()), 12.0)
	targets.register(target)
	var query = _lane_query([], targets)
	var origin := Vector2(95.0, _lane_y())

	var toward: GrappleAnchor = query.find_anchor(origin, origin + Vector2.RIGHT * 100.0)
	var away: GrappleAnchor = query.find_anchor(origin, origin + Vector2.LEFT * 50.0)

	assert_not_null(toward)
	assert_eq(toward.target, target)
	assert_eq(toward.position, origin)
	assert_null(away)


func test_target_anchor_validity_follows_target_and_detaches_model() -> void:
	var targets := GrappleTargetRegistry.new()
	var target := FakeGrappleTarget.new(Vector2(96.0, _lane_y()))
	targets.register(target)
	var query = _lane_query([], targets)
	var model := GrappleModel.new(GrappleConfig.new(), query)
	var input_frame := GrappleInputFrame.new()
	input_frame.hook_pressed = true
	input_frame.aim_position = target.center
	model.update(input_frame, Vector2(0.0, _lane_y()), Vector2.ZERO, 0.016)
	assert_true(model.is_target_attached())

	target.valid = false

	assert_false(query.is_anchor_valid(model.state.anchor))
	model.update(GrappleInputFrame.new(), Vector2(0.0, _lane_y()), Vector2.ZERO, 0.016)
	assert_false(model.state.is_attached)


func test_unregistered_or_cleared_targets_are_not_hit() -> void:
	var targets := GrappleTargetRegistry.new()
	var target := FakeGrappleTarget.new(Vector2(96.0, _lane_y()))
	targets.register(target)
	var query = _lane_query([], targets)
	targets.unregister(target)

	assert_null(query.find_anchor(Vector2(0.0, _lane_y()), Vector2(300.0, _lane_y())))

	targets.register(target)
	query.configure_targets(null)

	assert_null(query.find_anchor(Vector2(0.0, _lane_y()), Vector2(300.0, _lane_y())))


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


## Even columns of row 1 share this centre line, so a horizontal ray crosses them through their centres.
func _lane_y() -> float:
	return HexMetrics.center_for_offset(0, 1, 16.0).y


func _lane_query(terrain_columns: Array[int], targets: GrappleTargetRegistry):
	var registry := TerrainRegistry.new()
	assert_true(registry.try_configure(FixtureLoader.terrain_catalog()))
	var world := WorldGrid.new(WorldDimensions.new(16, 4), 0)
	for col in terrain_columns:
		world.set_committed_by_offset(col, 1, 1)
	var query = WorldGrappleAnchorQueryScript.new()
	query.configure(world, registry, 16.0, 8.0)
	query.configure_targets(targets)
	return query
