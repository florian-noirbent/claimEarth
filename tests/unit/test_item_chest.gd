extends GutTest


func test_chest_uses_one_scaled_sprite_and_non_solid_touch_area() -> void:
	var chest_scene := load("res://scenes/objects/item_chest.tscn") as PackedScene
	var chest := chest_scene.instantiate() as ItemChest
	add_child_autofree(chest)
	await wait_process_frames(1)
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	chest.configure(GeneratedItemChestSpawn.new(Vector2i(4, 8), definition, 42), 16.0, false)

	assert_eq(chest.get_child_count(), 1)
	assert_not_null(chest.light_source)
	assert_true(chest.light_source is WorldLightSource2D)
	assert_true(chest.explosive is WorldExplosive2D)
	assert_almost_eq(chest.displayed_size().x, 56.0, 0.001)
	assert_almost_eq(chest.displayed_size().y, 56.0 * 177.0 / 256.0, 0.001)
	var rectangle := chest.collision_shape.shape as RectangleShape2D
	assert_eq(rectangle.size, Vector2(52.0, 32.0))
	assert_eq(chest.touch_area.collision_layer, 0)
	assert_eq(chest.touch_area.collision_mask, 1)


func test_chest_overlap_detects_player_once_without_solid_collision() -> void:
	var chest := (load("res://scenes/objects/item_chest.tscn") as PackedScene).instantiate() as ItemChest
	add_child_autofree(chest)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await wait_process_frames(1)
	watch_signals(chest)
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	chest.configure(GeneratedItemChestSpawn.new(Vector2i.ZERO, definition, 1), 16.0, true)
	player.set_physics_process(false)
	player.global_position = chest.global_position - Vector2(0.0, 16.0)
	await wait_physics_frames(2)
	assert_signal_emit_count(chest, "touched", 1)


func test_chest_falls_straight_without_bouncing_and_lands_flat() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 16), FixtureLoader.terrain_id("Air"))
	for col in range(12):
		world.set_committed_by_offset(col, 9, FixtureLoader.terrain_id("Stone"))
	var chest := await _configured_chest(world, registry, Vector2i(5, 2))
	var start_x := chest.global_position.x
	for _step in 180:
		chest._physics_process(1.0 / 60.0)
		if chest.is_grounded():
			break

	assert_true(chest.is_grounded())
	assert_almost_eq(chest.global_position.x, start_x, 0.001)
	assert_eq(chest.fall_velocity, 0.0)
	assert_almost_eq(chest.visual_root.rotation, 0.0, 0.001)
	chest._physics_process(1.0 / 60.0)
	assert_eq(chest.fall_velocity, 0.0)
	for col in range(12):
		world.set_committed_by_offset(col, 9, FixtureLoader.terrain_id("Air"))
	chest._physics_process(0.11)
	assert_gt(chest.fall_velocity, 0.0)


func test_chest_tilts_toward_the_unsupported_side_without_sliding() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 16), FixtureLoader.terrain_id("Air"))
	var chest := await _configured_chest(world, registry, Vector2i(5, 5))
	var half_size := chest._body_half_size()
	var start_position := chest.global_position
	var left_sample := chest.global_position + Vector2(-half_size.x * 0.72, half_size.y)
	var right_sample := chest.global_position + Vector2(half_size.x * 0.72, half_size.y)
	var left_cell := HexMetrics.offset_for_world(left_sample, 16.0)
	var right_cell := HexMetrics.offset_for_world(right_sample, 16.0)
	world.set_committed_by_offset(left_cell.x, left_cell.y, FixtureLoader.terrain_id("Stone"))
	var start_x := chest.global_position.x
	chest._apply_support_tilt()

	assert_almost_eq(chest.visual_root.rotation, deg_to_rad(45.0), 0.001)
	assert_almost_eq(chest.global_position.x, start_x, 0.001)
	for _step in 5:
		chest._grounded = true
		chest._grounded_check_remaining = 0.0
		chest._physics_process(0.11)
	assert_almost_eq(chest.visual_root.rotation, deg_to_rad(45.0), 0.001)
	assert_almost_eq(chest.global_position.x, start_x, 0.001)
	world.set_committed_by_offset(left_cell.x, left_cell.y, FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(right_cell.x, right_cell.y, FixtureLoader.terrain_id("Stone"))
	chest.global_position = start_position
	chest.visual_root.rotation = 0.0
	chest._apply_support_tilt()
	assert_almost_eq(chest.visual_root.rotation, deg_to_rad(-45.0), 0.001)


func test_chest_uses_shared_nearest_air_unstuck_behavior() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(20, 16), FixtureLoader.terrain_id("Stone"))
	var chamber_hex := HexCoord.from_offset_odd_q(10, 5)
	_set_air_hex_radius(world, chamber_hex, 3)
	var chest := await _configured_chest(world, registry, Vector2i(3, 5))
	var target_variant = chest._terrain_query.nearest_clear_polygon_air_center(
		chest.global_position,
		chest._body_polygon,
		chest.visual_root.rotation,
		chest.spawn_data.definition.terrain_unstuck_search_ring
	)
	assert_not_null(target_variant)
	var target := target_variant as Vector2
	assert_false(chest._polygon_overlaps_at(target, chest.visual_root.rotation))
	var before := chest.global_position.distance_to(target)
	chest._apply_terrain_unstuck(0.05)

	assert_lt(chest.global_position.distance_to(target), before)


func _configured_chest(world: WorldGrid, registry: TerrainRegistry, anchor: Vector2i) -> ItemChest:
	var chest := (load("res://scenes/objects/item_chest.tscn") as PackedScene).instantiate() as ItemChest
	add_child_autofree(chest)
	await wait_process_frames(1)
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	chest.configure(GeneratedItemChestSpawn.new(anchor, definition, 1), 16.0, true, null, world, registry)
	return chest


func _set_air_hex_radius(world: WorldGrid, center: HexCoord, radius: int) -> void:
	for delta_q in range(-radius, radius + 1):
		var min_delta_r := maxi(-radius, -delta_q - radius)
		var max_delta_r := mini(radius, -delta_q + radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var cell := center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q()
			if world.dimensions.is_in_bounds_offset(cell.x, cell.y):
				world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Air"))
