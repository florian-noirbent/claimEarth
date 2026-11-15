extends GutTest


const HEX_RADIUS := 16.0
const STEP := 1.0 / 60.0

var _air_id := 0
var _stone_id := 0


func before_all() -> void:
	_air_id = FixtureLoader.terrain_id("Air")
	_stone_id = FixtureLoader.terrain_id("Stone")


func test_tracked_chest_sleeps_and_is_woken_by_the_next_due_check() -> void:
	var world := _world_with_floors()
	var chest := await _resting_chest(world)
	var scheduler := ItemChestSleepScheduler.new()
	scheduler.track(chest)
	_step_until_sleeping(chest)
	var view := _view_around(chest)

	assert_eq(scheduler.tracked_count(), 1)
	assert_true(chest.is_sleeping())
	assert_false(chest.is_physics_processing())
	scheduler.advance(0.1, view)
	assert_true(chest.is_sleeping(), "Unchanged terrain must not wake the chest")

	_remove_upper_floor(world)
	scheduler.advance(0.01, view)
	assert_true(chest.is_sleeping(), "Checks run on the grounded check interval, not every frame")
	scheduler.advance(0.1, view)
	assert_false(chest.is_sleeping())
	assert_true(chest.is_physics_processing())


func test_offscreen_chest_wakes_later_and_rests_where_the_visible_chest_does() -> void:
	var visible_world := _world_with_floors()
	var hidden_world := _world_with_floors()
	var visible_chest := await _resting_chest(visible_world)
	var hidden_chest := await _resting_chest(hidden_world)
	var visible_scheduler := ItemChestSleepScheduler.new()
	var hidden_scheduler := ItemChestSleepScheduler.new()
	visible_scheduler.track(visible_chest)
	hidden_scheduler.track(hidden_chest)
	_step_until_sleeping(visible_chest)
	_step_until_sleeping(hidden_chest)
	var rest_position := visible_chest.global_position
	var visible_view := _view_around(visible_chest)
	var hidden_view := Rect2(rest_position + Vector2(4000.0, 4000.0), Vector2(640.0, 360.0))
	visible_scheduler.advance(0.1, visible_view)
	hidden_scheduler.advance(0.1, hidden_view)

	_remove_upper_floor(visible_world)
	_remove_upper_floor(hidden_world)
	var definition := hidden_chest.spawn_data.definition
	var offscreen_interval := definition.offscreen_check_interval_seconds
	var grounded_interval := definition.grounded_check_interval_seconds
	var visible_wake_time := -1.0
	var hidden_wake_time := -1.0
	var elapsed := 0.0
	for _frame in ceili((offscreen_interval + 3.0) / STEP):
		elapsed += STEP
		visible_scheduler.advance(STEP, visible_view)
		hidden_scheduler.advance(STEP, hidden_view)
		if visible_wake_time < 0.0 and not visible_chest.is_sleeping():
			visible_wake_time = elapsed
		if hidden_wake_time < 0.0 and not hidden_chest.is_sleeping():
			hidden_wake_time = elapsed
		for chest: ItemChest in [visible_chest, hidden_chest]:
			if chest.is_physics_processing():
				chest._physics_process(STEP)

	assert_between(visible_wake_time, 0.0, grounded_interval + 2.0 * STEP)
	assert_between(
		hidden_wake_time,
		offscreen_interval - grounded_interval - 2.0 * STEP,
		offscreen_interval + grounded_interval + 2.0 * STEP
	)
	assert_true(visible_chest.is_sleeping())
	assert_true(hidden_chest.is_sleeping())
	assert_gt(visible_chest.global_position.y, rest_position.y + 64.0)
	assert_almost_eq(hidden_chest.global_position.x, visible_chest.global_position.x, 0.001)
	assert_almost_eq(hidden_chest.global_position.y, visible_chest.global_position.y, 0.001)
	assert_false(hidden_chest._polygon_overlaps_at(hidden_chest.global_position, hidden_chest.visual_root.rotation))


func test_check_interval_follows_view_margin_and_stuck_state() -> void:
	var chest := await _resting_chest(_world_with_floors())
	chest.set_sleep_enabled(true)
	_step_until_sleeping(chest)
	var definition := chest.spawn_data.definition
	var margin := definition.screen_margin_radii * HEX_RADIUS
	var position := chest.global_position

	assert_eq(chest.sleep_check_interval(_view_around(chest)), definition.grounded_check_interval_seconds)
	assert_eq(
		chest.sleep_check_interval(Rect2(position + Vector2(margin - 1.0, 0.0), Vector2(320.0, 180.0))),
		definition.grounded_check_interval_seconds,
		"The margin around the view still counts as on screen"
	)
	assert_eq(
		chest.sleep_check_interval(Rect2(position + Vector2(margin + 1.0, 0.0), Vector2(320.0, 180.0))),
		definition.offscreen_check_interval_seconds
	)

	var stuck_chest := await _configured_chest(WorldGrid.new(WorldDimensions.new(40, 40), _stone_id), Vector2i(20, 20))
	stuck_chest.set_sleep_enabled(true)
	_step_until_sleeping(stuck_chest)
	assert_true(stuck_chest.is_sleeping())
	assert_eq(stuck_chest.sleep_check_interval(_view_around(stuck_chest)), definition.stuck_check_interval_seconds)


func test_terrain_change_notification_checks_watching_chests_at_once() -> void:
	var world := _world_with_floors()
	var chest := await _resting_chest(world)
	var scheduler := ItemChestSleepScheduler.new()
	scheduler.track(chest)
	_step_until_sleeping(chest)
	var hidden_view := Rect2(chest.global_position + Vector2(4000.0, 4000.0), Vector2(640.0, 360.0))
	scheduler.advance(0.1, hidden_view)
	_remove_upper_floor(world)
	var watched := chest.watched_cells()

	scheduler.notify_terrain_changed(Rect2i())
	scheduler.notify_terrain_changed(Rect2i(watched.end + Vector2i.ONE, Vector2i.ONE))
	assert_true(chest.is_sleeping(), "Changes outside the watched cells must not trigger a check")
	scheduler.notify_terrain_changed(Rect2i(watched.position, Vector2i.ONE))
	assert_false(chest.is_sleeping())
	assert_true(chest.is_physics_processing())


func test_removed_chests_are_dropped_from_the_schedule() -> void:
	var world := _world_with_floors()
	var freed_chest := await _resting_chest(world)
	var queued_chest := await _resting_chest(world)
	var scheduler := ItemChestSleepScheduler.new()
	scheduler.track(freed_chest)
	scheduler.track(queued_chest)
	scheduler.track(queued_chest)
	assert_eq(scheduler.tracked_count(), 2)

	freed_chest.free()
	queued_chest.queue_free()
	scheduler.notify_terrain_changed(Rect2i(0, 0, 12, 20))
	scheduler.advance(0.1, Rect2())
	assert_eq(scheduler.tracked_count(), 0)

	scheduler.track(null)
	assert_eq(scheduler.tracked_count(), 0)


func _resting_chest(world: WorldGrid) -> ItemChest:
	return await _configured_chest(world, Vector2i(5, 2))


func _configured_chest(world: WorldGrid, anchor: Vector2i) -> ItemChest:
	var chest := (load("res://scenes/objects/item_chest.tscn") as PackedScene).instantiate() as ItemChest
	add_child_autofree(chest)
	await wait_process_frames(1)
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	chest.configure(
		GeneratedItemChestSpawn.new(anchor, definition, 1),
		HEX_RADIUS,
		true,
		null,
		world,
		FixtureLoader.terrain_registry()
	)
	return chest


func _world_with_floors() -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(12, 20), _air_id)
	for col in range(12):
		world.set_committed_by_offset(col, 9, _stone_id)
		world.set_committed_by_offset(col, 15, _stone_id)
	return world


func _remove_upper_floor(world: WorldGrid) -> void:
	for col in range(12):
		world.set_committed_by_offset(col, 9, _air_id)


func _view_around(chest: ItemChest) -> Rect2:
	return Rect2(chest.global_position - Vector2(320.0, 180.0), Vector2(640.0, 360.0))


func _step_until_sleeping(chest: ItemChest) -> void:
	for _step in 600:
		if chest.is_sleeping():
			return
		chest._physics_process(STEP)
