extends GutTest
## Covers the refused-use fact and the cooldown share RunItemController reports.


func test_run_start_lock_refuses_and_reports_its_remaining_share() -> void:
	var controller := _controller(FixtureLoader.terrain_id("Air"))
	var aim := controller._player.global_position + Vector2(100.0, 0.0)
	watch_signals(controller)

	assert_almost_eq(controller.use_cooldown_fraction(), 1.0, 0.0001)
	assert_false(controller.throw_selected(aim))
	assert_signal_emit_count(controller, "use_refused", 1)
	assert_eq(get_signal_parameters(controller, "use_refused"), [ItemUseRefusal.START_LOCK, 0])

	controller.advance(RunItemController.RUN_START_LOCK_SECONDS * 0.25)
	assert_almost_eq(controller.use_cooldown_fraction(), 0.75, 0.0001)
	var items: Array = controller.inventory_status()["items"]
	assert_eq(items.size(), 3)
	for item: Dictionary in items:
		assert_almost_eq(float(item["cooldown_fraction"]), 0.75, 0.0001)
		assert_false(bool(item["locked"]))

	controller.advance(RunItemController.RUN_START_LOCK_SECONDS)
	assert_eq(controller.use_cooldown_fraction(), 0.0)
	for item: Dictionary in controller.inventory_status()["items"]:
		assert_eq(float(item["cooldown_fraction"]), 0.0)
	assert_true(controller.throw_selected(aim))
	assert_signal_emit_count(controller, "use_refused", 1, "A successful use is not refused.")


func test_empty_item_refuses_with_its_catalog_index() -> void:
	var controller := _controller(FixtureLoader.terrain_id("Air"))
	var aim := controller._player.global_position + Vector2(100.0, 0.0)
	controller.select_index(1)
	var count := int(controller._inventory.count_for(controller._inventory.definitions()[1]))
	for throw_index in count:
		assert_true(controller.throw_selected(aim, true))
	watch_signals(controller)

	assert_false(controller.throw_selected(aim, true))

	assert_signal_emit_count(controller, "use_refused", 1)
	assert_eq(get_signal_parameters(controller, "use_refused"), [ItemUseRefusal.EMPTY, 1])
	assert_signal_not_emitted(controller, "item_used")


func test_flag_in_flight_refuses_every_item_and_marks_the_slots_locked() -> void:
	var controller := _controller(FixtureLoader.terrain_id("Air"))
	var aim := controller._player.global_position + Vector2(100.0, 0.0)
	var definitions := controller._inventory.definitions()
	var flag_index := definitions.find(_definition_with_tag(definitions, &"flag"))
	controller.select_index(flag_index)
	assert_true(controller.throw_selected(aim, true))
	assert_true(controller.is_flag_in_flight())
	controller.select_index(0)
	var projectiles := controller.active_projectile_count()
	watch_signals(controller)

	assert_false(controller.throw_selected(aim, true), "Bypassing the start lock does not bypass the flag lock.")

	assert_eq(get_signal_parameters(controller, "use_refused"), [ItemUseRefusal.FLAG_IN_FLIGHT, 0])
	assert_eq(controller.active_projectile_count(), projectiles)
	for item: Dictionary in controller.inventory_status()["items"]:
		assert_true(bool(item["locked"]))


func test_tool_without_anything_to_change_refuses_with_no_effect() -> void:
	var controller := _controller(FixtureLoader.terrain_id("Air"))
	var definitions := controller._inventory.definitions()
	var shovel_index := definitions.find(_definition_with_tag(definitions, &"shovel"))
	controller.debug_grant_item(shovel_index)
	controller.select_index(shovel_index)
	watch_signals(controller)

	assert_false(controller.throw_selected(controller._player.global_position + Vector2(0.0, 64.0), true))

	assert_eq(get_signal_parameters(controller, "use_refused"), [ItemUseRefusal.NO_EFFECT, shovel_index])
	assert_signal_not_emitted(controller, "tool_used")


func test_selection_fact_is_player_initiated_only() -> void:
	var controller := _controller(FixtureLoader.terrain_id("Air"))
	var definitions := controller._inventory.definitions()
	var flare_index := -1
	for index in definitions.size():
		if definitions[index].feedback_key == &"flare":
			flare_index = index
	assert_gte(flare_index, 3, "The flare is a collected, dynamic item.")
	controller.debug_grant_item(flare_index)
	controller.select_index(flare_index)
	watch_signals(controller)

	assert_true(controller.throw_selected(controller._player.global_position + Vector2(100.0, 0.0), true))

	assert_ne(controller._inventory.selected_definition(), definitions[flare_index], "Depletion moved the selection.")
	assert_signal_not_emitted(controller, "item_selected", "The automatic switch is not a selection moment.")
	controller.select_index(1)
	assert_signal_emit_count(controller, "item_selected", 1)


func _controller(fill_terrain_id: int) -> RunItemController:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	player.set_physics_process(false)
	var world := WorldGrid.new(WorldDimensions.new(20, 30), fill_terrain_id)
	var player_cell := Vector2i(10, 10)
	world.set_committed_by_offset(player_cell.x, player_cell.y, FixtureLoader.terrain_id("Air"))
	player.global_position = HexMetrics.center_for_offset(player_cell.x, player_cell.y, 16.0)
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(load("res://config/items/catalog.tres")))
	controller.configure_catalog(registry, 16.0)
	controller.configure_run(player, world, FixtureLoader.terrain_registry(), 16.0)
	return controller


func _definition_with_tag(definitions: Array[ItemDefinition], tag: StringName) -> ItemDefinition:
	for definition in definitions:
		if definition.perk_tags.has(tag):
			return definition
	return null
