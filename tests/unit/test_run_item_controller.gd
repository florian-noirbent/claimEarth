extends GutTest


func test_inventory_status_tracks_selection_without_exposing_inventory() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)

	controller.select_index(1)
	var status := controller.inventory_status()
	assert_eq(status.selected_name, "Large Bomb")
	assert_eq(status.counts.size(), 3)


func test_flag_resolution_emits_depth_and_destructive_terrain_outcome() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	watch_signals(controller)

	var landing_position := HexMetrics.center_for_offset(4, 27, 16.0)
	controller.resolve_flag_landing(null, landing_position, null, &"impact")
	assert_signal_emitted_with_parameters(controller, "flag_planted", [27, landing_position])
	controller.resolve_flag_landing(null, landing_position, null, &"lava")
	assert_signal_emitted_with_parameters(controller, "flag_destroyed", [&"lava"])
	controller.resolve_flag_landing(null, landing_position, null, &"acid")
	assert_signal_emitted_with_parameters(controller, "flag_destroyed", [&"acid"])


func test_flag_landing_above_surface_clamps_depth_to_zero() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	watch_signals(controller)

	var landing_position := HexMetrics.center_for_offset(4, -1, 16.0)
	controller.resolve_flag_landing(null, landing_position, null, &"impact")

	assert_signal_emitted_with_parameters(controller, "flag_planted", [0, landing_position])


func test_generated_chest_requests_choices_and_applies_one_reward_once() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var item_registry := _item_registry()
	var terrain_registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(16, 32), FixtureLoader.terrain_id("Air"))
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	var spawn := GeneratedItemChestSpawn.new(Vector2i(5, 10), definition, 77)
	controller.configure_catalog(item_registry, 16.0)
	controller.configure_run(null, world, terrain_registry, 16.0, null, [spawn])
	controller.set_active(true)
	assert_eq(controller.item_chest_count(), 1)
	var chest := controller.get_children().filter(func(child: Node) -> bool: return child is ItemChest)[0] as ItemChest
	watch_signals(controller)
	controller._on_item_chest_touched(chest)
	assert_signal_emitted(controller, "reward_choices_requested")
	var request: Array = get_signal_parameters(controller, "reward_choices_requested")
	var choices: Array = request[1]
	assert_eq(choices.size(), 2)
	var selected_choice := choices[0] as RewardChoiceViewData
	var before_count := _status_count(controller.inventory_status(), selected_choice.title)
	var selected_quantity := int(selected_choice.quantity_text.trim_prefix("+"))

	assert_true(controller.apply_pending_reward(0))
	assert_false(controller.apply_pending_reward(0))
	assert_eq(
		_status_count(controller.inventory_status(), selected_choice.title),
		before_count + selected_quantity
	)
	await wait_process_frames(1)
	assert_eq(controller.item_chest_count(), 0)


func test_set_active_suspends_projectiles_and_chest_monitoring() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	var projectile := ItemProjectile.new()
	projectile.fuse_seconds = 100.0
	controller.add_child(projectile)
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	var chest := definition.chest_scene.instantiate() as ItemChest
	controller.add_child(chest)
	chest.configure(GeneratedItemChestSpawn.new(Vector2i.ZERO, definition, 1), 16.0, true)

	controller.set_active(false)
	await wait_process_frames(1)
	assert_false(projectile.is_physics_processing())
	assert_false(chest.touch_area.monitoring)
	controller.set_active(true)
	await wait_process_frames(1)
	assert_true(projectile.is_physics_processing())
	assert_true(chest.touch_area.monitoring)


func test_bomb_to_bomb_chain_uses_lethal_core_and_delayed_common_component() -> void:
	var controller := _configured_explosion_controller()
	watch_signals(controller)
	var origin := HexMetrics.center_for_offset(5, 5, 16.0)
	var first := _add_bomb(controller, origin)
	var second := _add_bomb(controller, HexMetrics.center_for_offset(7, 5, 16.0))

	assert_true(first.explosive.request_immediate_detonation())
	assert_true(second.explosive.is_chain_armed())
	var second_start := second.global_position
	second.global_position += Vector2(0.0, 12.0)
	second.explosive._physics_process(0.29)
	assert_eq(get_signal_emit_count(controller, "explosion_resolved"), 1)
	second.explosive._physics_process(0.02)

	assert_eq(get_signal_emit_count(controller, "explosion_resolved"), 2)
	assert_ne(second.global_position, second_start)


func test_wider_nonlethal_blast_does_not_arm_bomb() -> void:
	var controller := _configured_explosion_controller()
	var origin_cell := Vector2i(5, 5)
	var origin := HexMetrics.center_for_offset(origin_cell.x, origin_cell.y, 16.0)
	var outside_lethal := HexCoord.from_offset_odd_q(origin_cell.x, origin_cell.y).add(HexCoord.new(4, 0)).to_offset_odd_q()
	var bomb := _add_bomb(controller, HexMetrics.center_for_offset(outside_lethal.x, outside_lethal.y, 16.0))
	var definition := load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition

	controller.resolve_explosion(definition, origin)

	assert_false(bomb.explosive.is_chain_armed())


func test_explosion_pushes_active_projectile_bodies_including_future_item_actions() -> void:
	var controller := _configured_explosion_controller()
	var origin := Vector2(100.0, 100.0)
	var projectile := ItemProjectile.new()
	projectile.global_position = origin + Vector2(40.0, 0.0)
	controller.add_child(projectile)
	var definition := (load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition).duplicate(true) as ExplosionDefinition
	definition.blast_impulse = 800.0

	controller.resolve_explosion(definition, origin)

	assert_almost_eq(projectile.velocity.x, 400.0, 0.001)
	assert_almost_eq(projectile.velocity.y, 0.0, 0.001)


func test_explosion_pushes_excavator_through_the_shared_rigidbody_contract() -> void:
	var controller := _configured_explosion_controller()
	var factory := load("res://config/items/factory/excavator_factory.tres") as ExcavatorItemActionFactory
	var origin := Vector2(100.0, 100.0)
	controller.spawn_excavator(origin + Vector2(40.0, 0.0), factory)
	var robot := controller.get_children().filter(func(child: Node) -> bool: return child is ExcavatorRobot)[0] as ExcavatorRobot
	var definition := (load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition).duplicate(true) as ExplosionDefinition
	definition.blast_impulse = 800.0

	controller.resolve_explosion(definition, origin)

	assert_true(robot is WorldRigidBody2D)
	assert_almost_eq(robot.velocity.x, 400.0, 0.001)


func test_excavator_factory_doubles_its_original_lifetime_and_drill_cadence() -> void:
	var factory := load("res://config/items/factory/excavator_factory.tres") as ExcavatorItemActionFactory

	assert_almost_eq(factory.duration_seconds, 20.0, 0.001)
	assert_almost_eq(factory.tick_seconds, 0.5, 0.001)


func test_excavator_chain_detonation_uses_the_common_explosive_component() -> void:
	var controller := _configured_explosion_controller()
	watch_signals(controller)
	var factory := load("res://config/items/factory/excavator_factory.tres") as ExcavatorItemActionFactory
	controller.spawn_excavator(HexMetrics.center_for_offset(5, 5, 16.0), factory)
	var robot := controller.get_children().filter(func(child: Node) -> bool: return child is ExcavatorRobot)[0] as ExcavatorRobot

	assert_true(robot.explosive.try_arm_from_lethal_cells([Vector2i(5, 5)], 16.0))
	robot.explosive._physics_process(0.31)

	assert_signal_emitted(controller, "explosion_resolved")
	assert_true(robot.is_queued_for_deletion())


func test_bomb_arms_chest_and_chest_detonation_can_arm_bomb() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var world := WorldGrid.new(WorldDimensions.new(20, 24), FixtureLoader.terrain_id("Air"))
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	var spawn := GeneratedItemChestSpawn.new(Vector2i(8, 8), definition, 17)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(null, world, FixtureLoader.terrain_registry(), 16.0, null, [spawn])
	controller.set_active(true)
	var chest := controller.get_children().filter(func(child: Node) -> bool: return child is ItemChest)[0] as ItemChest
	var first_bomb := _add_bomb(controller, chest.global_position)
	var second_bomb := _add_bomb(controller, chest.global_position + Vector2(24.0, 0.0))

	first_bomb.explosive.request_immediate_detonation()
	assert_true(chest.explosive.is_chain_armed())
	assert_false(chest.touch_area.monitoring)
	chest.explosive._physics_process(0.31)

	assert_true(second_bomb.explosive.is_chain_armed())
	assert_true(chest.is_queued_for_deletion())


func test_natural_fuse_beats_longer_chain_fuse() -> void:
	var controller := _configured_explosion_controller()
	watch_signals(controller)
	var bomb := _add_bomb(controller, HexMetrics.center_for_offset(5, 5, 16.0))
	bomb.remaining_fuse = 0.05
	assert_true(bomb.explosive.try_arm_from_lethal_cells([Vector2i(5, 5)], 16.0))

	bomb._physics_process(0.06)

	assert_eq(get_signal_emit_count(controller, "explosion_resolved"), 1)
	assert_true(bomb.explosive.is_consumed())


func test_chest_to_chest_chain_is_component_driven() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(
		null,
		WorldGrid.new(WorldDimensions.new(20, 24), FixtureLoader.terrain_id("Air")),
		FixtureLoader.terrain_registry(),
		16.0,
		null,
		[
			GeneratedItemChestSpawn.new(Vector2i(7, 8), definition, 1),
			GeneratedItemChestSpawn.new(Vector2i(10, 8), definition, 2),
		]
	)
	controller.set_active(true)
	var chests := controller.get_children().filter(func(child: Node) -> bool: return child is ItemChest)
	var first := chests[0] as ItemChest
	var second := chests[1] as ItemChest
	second.global_position = first.global_position + Vector2(24.0, 0.0)
	var first_cell := HexMetrics.offset_for_world(first.global_position, 16.0)
	assert_true(first.explosive.try_arm_from_lethal_cells([first_cell], 16.0))

	first.explosive._physics_process(0.31)

	assert_true(second.explosive.is_chain_armed())


func _item_registry() -> ItemRegistry:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(load("res://config/items/catalog.tres")))
	return registry


func _status_count(status: Dictionary, item_name: String) -> int:
	for item in status.items:
		if item.name == item_name:
			return int(item.count)
	return -1


func _configured_explosion_controller() -> RunItemController:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(
		null,
		WorldGrid.new(WorldDimensions.new(20, 24), FixtureLoader.terrain_id("Air")),
		FixtureLoader.terrain_registry(),
		16.0
	)
	controller.set_active(true)
	return controller


func _add_bomb(controller: RunItemController, position: Vector2) -> ItemProjectile:
	var projectile := ItemProjectile.new()
	projectile.world = controller._world
	projectile.terrain_registry = controller._terrain_registry
	projectile.hex_radius = 16.0
	projectile.global_position = position
	projectile.configure({
		"fuse_seconds": 100.0,
		"gravity": 0.0,
		"velocity": Vector2.ZERO,
		"polygon": PackedVector2Array([-7, -7, 7, -7, 7, 7, -7, 7]),
		"explosion_definition": load("res://config/items/explosions/small_bomb_explosion.tres"),
	})
	controller.add_child(projectile)
	controller._register_explosive(projectile.explosive)
	return projectile
