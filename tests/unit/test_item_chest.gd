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


func test_chest_without_sleep_enabled_keeps_polling_its_support() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := _world_with_floor(9)
	var chest := await _configured_chest(world, registry, Vector2i(5, 2))
	for _step in 240:
		chest._physics_process(1.0 / 60.0)

	assert_true(chest.is_grounded())
	assert_false(chest.is_sleeping())
	assert_true(chest.is_physics_processing())


func test_sleep_enabled_chest_stops_physics_steps_after_settling() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := _world_with_floor(9)
	var chest := await _configured_chest(world, registry, Vector2i(5, 2))
	chest.set_sleep_enabled(true)
	assert_true(chest.is_physics_processing())
	chest._physics_process(1.0 / 60.0)
	assert_false(chest.is_sleeping(), "A falling chest must not sleep")

	_step_until_sleeping(chest)

	assert_true(chest.is_sleeping())
	assert_true(chest.is_grounded())
	assert_false(chest.is_physics_processing())
	assert_eq(chest.fall_velocity, 0.0)
	assert_true(chest.watched_cells().has_area())
	assert_false(chest.wake_if_terrain_changed())
	chest.set_active(false)
	chest.set_active(true)
	assert_false(chest.is_physics_processing(), "Resuming a run must not wake resting chests")
	chest.set_sleep_enabled(false)
	assert_false(chest.is_sleeping())
	assert_true(chest.is_physics_processing())


func test_sleeping_chest_wakes_when_support_is_removed_and_lands_where_a_polling_chest_does() -> void:
	var registry := FixtureLoader.terrain_registry()
	var sleeping_world := _world_with_floor(9)
	var polling_world := _world_with_floor(9)
	var sleeper := await _configured_chest(sleeping_world, registry, Vector2i(5, 2))
	var poller := await _configured_chest(polling_world, registry, Vector2i(5, 2))
	sleeper.set_sleep_enabled(true)
	_step_until_sleeping(sleeper)
	for _step in 240:
		poller._physics_process(1.0 / 60.0)
	var rest_position := sleeper.global_position
	assert_eq(poller.global_position, rest_position)

	sleeping_world.set_committed_light_by_offset(5, 9, 200)
	assert_false(sleeper.wake_if_terrain_changed(), "Light changes must not wake a resting chest")
	for world: WorldGrid in [sleeping_world, polling_world]:
		for col in range(12):
			world.set_committed_by_offset(col, 9, FixtureLoader.terrain_id("Air"))
			world.set_committed_by_offset(col, 13, FixtureLoader.terrain_id("Stone"))
	assert_true(sleeper.wake_if_terrain_changed())
	assert_false(sleeper.is_sleeping())
	assert_true(sleeper.is_physics_processing())
	_step_until_sleeping(sleeper)
	for _step in 240:
		poller._physics_process(1.0 / 60.0)

	assert_gt(sleeper.global_position.y, rest_position.y + 64.0)
	assert_almost_eq(sleeper.global_position.x, rest_position.x, 0.001)
	assert_almost_eq(sleeper.global_position.y, poller.global_position.y, 0.001)
	assert_almost_eq(sleeper.visual_root.rotation, poller.visual_root.rotation, 0.001)
	assert_false(sleeper._polygon_overlaps_at(sleeper.global_position, sleeper.visual_root.rotation))


func test_tilted_chest_sleeps_and_wakes_when_its_far_support_probe_changes() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(12, 16), FixtureLoader.terrain_id("Air"))
	var chest := await _configured_chest(world, registry, Vector2i(5, 5))
	var half_size := chest._body_half_size()
	var left_cell := HexMetrics.offset_for_world(chest.global_position + Vector2(-half_size.x * 0.72, half_size.y), 16.0)
	var right_sample := chest.global_position + Vector2(half_size.x * 0.72, half_size.y + 8.0)
	var right_cell := HexMetrics.offset_for_world(right_sample, 16.0)
	world.set_committed_by_offset(left_cell.x, left_cell.y, FixtureLoader.terrain_id("Stone"))
	chest.set_sleep_enabled(true)

	_step_until_sleeping(chest)
	assert_true(chest.is_sleeping())
	assert_almost_eq(chest.visual_root.rotation, deg_to_rad(45.0), 0.001)
	assert_true(chest.watched_cells().has_point(right_cell))

	world.set_committed_by_offset(right_cell.x, right_cell.y, FixtureLoader.terrain_id("Stone"))
	assert_true(chest.wake_if_terrain_changed())


func test_stuck_chest_does_not_repeat_the_unstuck_search_until_surrounding_terrain_changes() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(40, 40), FixtureLoader.terrain_id("Stone"))
	var query := CountingCollisionQuery.new()
	var chest := await _configured_chest(world, registry, Vector2i(20, 20), query)
	chest.set_sleep_enabled(true)

	_step_until_sleeping(chest)
	var stuck_position := chest.global_position
	assert_true(chest.is_sleeping())
	assert_false(chest.is_physics_processing())
	assert_eq(query.search_count, 2, "One search finds no escape and one confirms the resting state")

	world.set_committed_light_by_offset(21, 20, 180)
	var outside := chest.watched_cells().end + Vector2i.ONE
	assert_true(world.dimensions.is_in_bounds_offset(outside.x, outside.y))
	world.set_committed_by_offset(outside.x, outside.y, FixtureLoader.terrain_id("Air"))
	assert_false(chest.wake_if_terrain_changed())
	assert_eq(query.search_count, 2)

	world.set_committed_by_offset(26, 20, FixtureLoader.terrain_id("Air"))
	assert_true(chest.wake_if_terrain_changed(), "A new Air center inside the search ring must be tried")
	_step_until_sleeping(chest)
	assert_eq(query.search_count, 3)
	assert_eq(chest.global_position, stuck_position, "One open cell cannot hold the chest body")
	assert_false(chest.wake_if_terrain_changed())

	_set_air_hex_radius(world, HexCoord.from_offset_odd_q(26, 20), 3)
	assert_true(chest.wake_if_terrain_changed())
	chest._physics_process(1.0 / 60.0)
	assert_eq(query.search_count, 4)
	assert_gt(chest.global_position.x, stuck_position.x)
	assert_false(chest.is_sleeping())


func _configured_chest(
	world: WorldGrid,
	registry: TerrainRegistry,
	anchor: Vector2i,
	terrain_query: TerrainCollisionQuery = null
) -> ItemChest:
	var chest := (load("res://scenes/objects/item_chest.tscn") as PackedScene).instantiate() as ItemChest
	add_child_autofree(chest)
	await wait_process_frames(1)
	if terrain_query != null:
		chest._terrain_query = terrain_query
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	chest.configure(GeneratedItemChestSpawn.new(anchor, definition, 1), 16.0, true, null, world, registry)
	return chest


func _world_with_floor(floor_row: int) -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(12, 16), FixtureLoader.terrain_id("Air"))
	for col in range(12):
		world.set_committed_by_offset(col, floor_row, FixtureLoader.terrain_id("Stone"))
	return world


func _step_until_sleeping(chest: ItemChest, maximum_steps: int = 600) -> void:
	for _step in maximum_steps:
		if chest.is_sleeping():
			return
		chest._physics_process(1.0 / 60.0)


func _set_air_hex_radius(world: WorldGrid, center: HexCoord, radius: int) -> void:
	for delta_q in range(-radius, radius + 1):
		var min_delta_r := maxi(-radius, -delta_q - radius)
		var max_delta_r := mini(radius, -delta_q + radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var cell := center.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q()
			if world.dimensions.is_in_bounds_offset(cell.x, cell.y):
				world.set_committed_by_offset(cell.x, cell.y, FixtureLoader.terrain_id("Air"))


class CountingCollisionQuery:
	extends TerrainCollisionQuery

	var search_count := 0

	func nearest_clear_polygon_air_center(
		position: Vector2,
		local_polygon: PackedVector2Array,
		rotation_value: float,
		max_ring: int
	):
		search_count += 1
		return super(position, local_polygon, rotation_value, max_ring)
