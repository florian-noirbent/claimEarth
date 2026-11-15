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


func test_item_chest_claim_reports_offered_items_pick_quantity_and_container_key() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var item_registry := _item_registry()
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	controller.configure_catalog(item_registry, 16.0)
	controller.configure_run(
		null,
		WorldGrid.new(WorldDimensions.new(16, 32), FixtureLoader.terrain_id("Air")),
		FixtureLoader.terrain_registry(),
		16.0,
		null,
		[GeneratedItemChestSpawn.new(Vector2i(5, 10), definition, 77)]
	)
	controller.set_active(true)
	var expected := definition.draw_choices(77, 2)
	watch_signals(controller)
	controller._on_item_chest_touched(_item_chests(controller)[0])

	assert_true(controller.apply_pending_reward(1))

	assert_signal_emit_count(controller, "reward_claimed", 1)
	var claim := get_signal_parameters(controller, "reward_claimed")[0] as RewardClaim
	assert_eq(claim.container_key, &"item_chest")
	assert_eq(claim.offered_items.size(), 2)
	for index in expected.size():
		assert_same(claim.offered_items[index], item_registry.get_definition(expected[index].item.stable_id))
	assert_same(claim.picked_item, claim.offered_items[1])
	assert_eq(claim.picked_quantity, expected[1].quantity)
	assert_true(claim.offered_perks.is_empty())
	assert_null(claim.picked_perk)


func test_perk_geode_claim_reports_offered_perks_pick_and_container_key() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var perks := RunPerkController.new()
	add_child_autofree(perks)
	assert_true(perks.configure(load("res://config/perks/catalog.tres") as PerkCatalog))
	var definition := load("res://config/items/perk_geode.tres") as PerkGeodeDefinition
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_perk_controller(perks)
	controller.configure_run(
		null,
		WorldGrid.new(WorldDimensions.new(16, 32), FixtureLoader.terrain_id("Air")),
		FixtureLoader.terrain_registry(),
		16.0,
		null,
		[],
		[GeneratedItemChestSpawn.new(Vector2i(5, 10), definition, 41)]
	)
	controller.set_active(true)
	watch_signals(controller)
	controller._on_item_chest_touched(_item_chests(controller)[0])
	var offered: Array = get_signal_parameters(controller, "reward_choices_requested")[1]

	assert_true(controller.apply_pending_reward(0))

	assert_signal_emit_count(controller, "reward_claimed", 1)
	var claim := get_signal_parameters(controller, "reward_claimed")[0] as RewardClaim
	assert_eq(claim.container_key, &"perk_geode")
	assert_eq(claim.offered_perks.size(), offered.size())
	for index in offered.size():
		assert_eq(claim.offered_perks[index].display_name, (offered[index] as RewardChoiceViewData).title)
	assert_same(claim.picked_perk, claim.offered_perks[0])
	assert_eq(perks.selected_perks().size(), 1)
	assert_same(perks.selected_perks()[0], claim.picked_perk)
	assert_true(claim.offered_items.is_empty())
	assert_null(claim.picked_item)


func test_reward_claimed_is_not_emitted_for_invalid_choice_or_cancel() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(
		null,
		WorldGrid.new(WorldDimensions.new(16, 32), FixtureLoader.terrain_id("Air")),
		FixtureLoader.terrain_registry(),
		16.0,
		null,
		[GeneratedItemChestSpawn.new(Vector2i(5, 10), load("res://config/items/item_chest.tres") as ItemChestDefinition, 77)]
	)
	controller.set_active(true)
	var chest := _item_chests(controller)[0]
	watch_signals(controller)

	controller._on_item_chest_touched(chest)
	assert_false(controller.apply_pending_reward(5))
	assert_false(controller.apply_pending_reward(-1))
	controller.cancel_pending_reward()
	assert_false(controller.apply_pending_reward(0))

	assert_signal_not_emitted(controller, "reward_claimed")


func test_item_used_reports_each_successful_projectile_throw_once() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"))
	var small_bomb := controller._inventory.definitions()[0]
	watch_signals(controller)

	assert_false(controller.throw_selected(controller._player.global_position + Vector2(100.0, 0.0)), "The run-start throw lock blocks this throw")
	assert_signal_not_emitted(controller, "item_used")
	assert_true(controller.throw_selected(controller._player.global_position + Vector2(100.0, 0.0), true))

	assert_signal_emit_count(controller, "item_used", 1)
	assert_signal_emitted_with_parameters(controller, "item_used", [small_bomb])
	assert_signal_emit_count(controller, "item_thrown", 1)


func test_item_used_reports_the_flag_throw_but_not_the_relentless_drop() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"))
	var flag := _definition_with_tag(controller._inventory.definitions(), &"flag")
	controller.select_index(controller._inventory.definitions().find(flag))
	watch_signals(controller)

	assert_true(controller.throw_selected(controller._player.global_position + Vector2(100.0, 0.0), true))
	assert_signal_emit_count(controller, "item_used", 1)
	assert_signal_emitted_with_parameters(controller, "item_used", [flag])

	var relentless := _throw_controller(FixtureLoader.terrain_id("Air"))
	var modifiers := PerkModifierSnapshot.new()
	modifiers.flags._set_value("survive_lava_acid_and_drop_on_death", true)
	relentless.set_perk_modifiers(modifiers)
	watch_signals(relentless)
	assert_true(relentless.drop_flag_on_player_death())
	assert_true(relentless.is_flag_in_flight())
	assert_signal_not_emitted(relentless, "item_used")


func test_item_used_reports_an_immediate_tool_only_when_it_spends_charge() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"))
	var shovel := _definition_with_tag(controller._inventory.definitions(), &"shovel")
	var shovel_index := controller._inventory.definitions().find(shovel)
	controller.debug_grant_item(shovel_index)
	controller.select_index(shovel_index)
	watch_signals(controller)

	assert_false(controller.throw_selected(controller._player.global_position + Vector2(0.0, 64.0), true), "A tool without Sand to clear spends no charge")
	assert_signal_not_emitted(controller, "item_used")

	var digging := _throw_controller(FixtureLoader.terrain_id("Sand"))
	digging.debug_grant_item(shovel_index)
	digging.select_index(shovel_index)
	watch_signals(digging)
	assert_true(digging.throw_selected(digging._player.global_position + Vector2(0.0, 64.0), true))

	assert_signal_emit_count(digging, "item_used", 1)
	assert_signal_emitted_with_parameters(digging, "item_used", [shovel])
	assert_signal_emit_count(digging, "item_thrown", 1)


func test_run_session_forwards_item_use_and_reward_claim_outcomes() -> void:
	var session := (load("res://scenes/app/run_session.tscn") as PackedScene).instantiate() as RunSession
	add_child_autofree(session)
	session.configure(
		load("res://config/generation/default_profile.tres") as GenerationProfile,
		load("res://scenes/player/player.tscn") as PackedScene
	)
	watch_signals(session)
	var definition := load("res://config/items/small_bomb.tres") as ItemDefinition
	var claim := RewardClaim.new()
	claim.container_key = &"item_chest"

	session.item_controller.item_used.emit(definition)
	session.item_controller.reward_claimed.emit(claim)

	assert_signal_emitted_with_parameters(session, "item_used", [definition])
	assert_signal_emitted_with_parameters(session, "reward_claimed", [claim])


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

	watch_signals(controller)
	first_bomb.explosive.request_immediate_detonation()
	assert_true(chest.explosive.is_chain_armed())
	assert_false(chest.touch_area.monitoring)
	assert_signal_not_emitted(controller, "reward_container_destroyed")
	chest.explosive._physics_process(0.31)

	assert_signal_emit_count(controller, "reward_container_destroyed", 1)
	assert_eq(get_signal_parameters(controller, "reward_container_destroyed"), [&"item_chest"])
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


func test_generated_chests_sleep_until_committed_terrain_changes_remove_their_support() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var air_id := FixtureLoader.terrain_id("Air")
	var world := _world_with_floors([10, 20])
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(null, world, FixtureLoader.terrain_registry(), 16.0, null, [
		GeneratedItemChestSpawn.new(Vector2i(5, 8), definition, 1),
		GeneratedItemChestSpawn.new(Vector2i(14, 8), definition, 2),
	])
	controller.set_active(true)
	var chests := _item_chests(controller)
	var first := chests[0]
	var second := chests[1]
	assert_same(first._terrain_query.metadata, second._terrain_query.metadata)
	_step_until_sleeping(chests)
	for chest in chests:
		assert_true(chest.is_sleeping())
		assert_false(chest.is_physics_processing())
	controller.advance(0.2)
	assert_true(first.is_sleeping())
	assert_true(second.is_sleeping())

	var change_set := TerrainChangeSet.new(world.dimensions)
	for col in range(0, 10):
		change_set.add_cell_change(world.set_committed_by_offset(col, 10, air_id))
	controller._commit_external_terrain_changes(change_set)
	assert_false(first.is_sleeping(), "Item-caused terrain edits must wake affected chests at once")
	assert_true(first.is_physics_processing())
	assert_true(second.is_sleeping())

	for col in range(10, 20):
		world.set_committed_by_offset(col, 10, air_id)
	for _tick in 40:
		controller.advance(0.1)
	assert_false(second.is_sleeping(), "Simulated terrain changes must wake chests through the scheduled checks")
	_step_until_sleeping(chests)
	for chest in chests:
		assert_true(chest.is_sleeping())
		assert_gt(chest.global_position.y, HexMetrics.center_for_offset(5, 17, 16.0).y)


func test_explosion_wakes_a_sleeping_chest_whose_floor_it_destroys() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var world := _world_with_floors([10, 20])
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(null, world, FixtureLoader.terrain_registry(), 16.0, null, [
		GeneratedItemChestSpawn.new(Vector2i(8, 8), definition, 1),
	])
	controller.set_active(true)
	var chests := _item_chests(controller)
	var chest := chests[0]
	chest.set_destructible(false)
	_step_until_sleeping(chests)
	assert_true(chest.is_sleeping())

	controller.resolve_explosion(
		load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition,
		HexMetrics.center_for_offset(8, 10, 16.0)
	)

	assert_false(world.get_committed_by_offset(8, 10) == FixtureLoader.terrain_id("Stone"))
	assert_false(chest.is_sleeping())
	assert_true(chest.is_physics_processing())


func test_generated_barrels_spawn_at_their_anchor_as_registered_world_explosives() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	var spawn := GeneratedExplosiveBarrelSpawn.new(Vector2i(6, 12), definition, 99)
	var registry := GrappleTargetRegistry.new()
	controller.configure_run(
		null,
		_world_with_floors([13, 14]),
		FixtureLoader.terrain_registry(),
		16.0,
		null,
		[],
		[],
		[spawn],
		registry
	)
	controller.set_active(true)

	var barrels := _explosive_barrels(controller)
	assert_eq(barrels.size(), 1)
	var barrel := barrels[0]
	assert_same(barrel.spawn_data, spawn)
	assert_eq(barrel.global_position, barrel.generated_center_position(spawn.anchor_offset))
	assert_eq(HexMetrics.offset_for_world(barrel.global_position, 16.0), spawn.anchor_offset)
	assert_true(barrel.is_active())
	assert_true(barrel.is_interactive())
	assert_same(barrel.explosive.definition, definition.explosion_definition)
	assert_same(barrel.explosive.host(), barrel)
	assert_true(controller._explosives.has(barrel.explosive))
	assert_same(controller.grapple_targets(), registry)
	assert_eq(controller.explosive_barrel_count(), 1)
	assert_eq(controller.active_projectile_count(), 0, "Generated barrels are not thrown items")
	assert_eq(registry.targets(), [barrel.grapple_target()] as Array[GrappleTarget])
	assert_true(barrel.sleep_state().is_enabled(), "The run schedules barrel sleep like chest sleep")

	controller.set_active(false)
	assert_false(barrel.is_active())
	controller.set_active(true)
	assert_true(barrel.is_active())

	controller.debug_clear_world_items()
	await wait_process_frames(1)
	assert_true(is_instance_valid(barrel), "Debug item clearing keeps generated barrels")
	assert_eq(controller.explosive_barrel_count(), 1)

	controller.clear_run()
	assert_false(is_instance_valid(barrel))
	assert_eq(_explosive_barrels(controller).size(), 0)
	assert_eq(controller.explosive_barrel_count(), 0)
	assert_null(controller.grapple_targets())
	assert_true(registry.targets().is_empty())
	assert_false(controller.is_physics_processing())


func test_lethal_explosion_core_arms_a_generated_barrel() -> void:
	var controller := _configured_explosion_controller()
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	controller._spawn_explosive_barrels([GeneratedExplosiveBarrelSpawn.new(Vector2i(7, 5), definition, 1)])
	var barrel := _explosive_barrels(controller)[0]
	var bomb := _add_bomb(controller, HexMetrics.center_for_offset(5, 5, 16.0))

	assert_true(bomb.explosive.request_immediate_detonation())

	assert_true(barrel.explosive.is_chain_armed())


func test_blast_radius_arms_opted_in_barrels_and_leaves_default_explosives_unchanged() -> void:
	var controller := _configured_explosion_controller()
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	var opted_out_definition := definition.duplicate() as ExplosiveBarrelDefinition
	opted_out_definition.detonates_in_blast_radius = false
	var origin_cell := Vector2i(5, 5)
	var origin := HexMetrics.center_for_offset(origin_cell.x, origin_cell.y, 16.0)
	var origin_hex := HexCoord.from_offset_odd_q(origin_cell.x, origin_cell.y)
	var inside_blast := origin_hex.add(HexCoord.new(5, 0)).to_offset_odd_q()
	var beyond_blast := origin_hex.add(HexCoord.new(7, 0)).to_offset_odd_q()
	var below_blast := origin_hex.add(HexCoord.new(0, 5)).to_offset_odd_q()
	controller._spawn_explosive_barrels([
		GeneratedExplosiveBarrelSpawn.new(inside_blast, definition, 1),
		GeneratedExplosiveBarrelSpawn.new(beyond_blast, definition, 2),
		GeneratedExplosiveBarrelSpawn.new(below_blast, opted_out_definition, 3),
	])
	var barrels := _explosive_barrels(controller)
	for index in barrels.size():
		barrels[index].global_position = HexMetrics.center_for_offset(
			[inside_blast, beyond_blast, below_blast][index].x,
			[inside_blast, beyond_blast, below_blast][index].y,
			16.0
		)
	var bomb := _add_bomb(controller, HexMetrics.center_for_offset(inside_blast.x, inside_blast.y + 1, 16.0))
	var chest_definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	controller._spawn_item_chests([GeneratedItemChestSpawn.new(origin_hex.add(HexCoord.new(-5, 0)).to_offset_odd_q(), chest_definition, 4)])
	var chest := _item_chests(controller)[0]

	controller.resolve_explosion(load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition, origin)

	assert_true(barrels[0].explosive.is_chain_armed(), "A barrel inside the blast radius arms its chain fuse")
	assert_false(barrels[1].explosive.is_chain_armed())
	assert_false(barrels[2].explosive.is_chain_armed(), "A barrel that opts out arms only from the lethal core")
	assert_false(bomb.explosive.is_chain_armed(), "Bombs keep lethal-core arming")
	assert_false(chest.explosive.is_chain_armed(), "Chests keep lethal-core arming")


func test_detonating_barrel_explodes_through_its_explosive_and_leaves_the_grapple_registry() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	var registry := GrappleTargetRegistry.new()
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	controller.configure_run(null, _world_with_floors([13, 14]), FixtureLoader.terrain_registry(), 16.0, null, [], [], [
		GeneratedExplosiveBarrelSpawn.new(Vector2i(6, 12), definition, 1),
		GeneratedExplosiveBarrelSpawn.new(Vector2i(13, 12), definition, 2),
	], registry)
	controller.set_active(true)
	watch_signals(controller)
	var barrels := _explosive_barrels(controller)
	var first := barrels[0]
	var second := barrels[1]
	var first_target := first.grapple_target()
	assert_eq(registry.targets().size(), 2)

	assert_true(first.explosive.request_immediate_detonation())

	assert_signal_emit_count(controller, "explosion_resolved", 1)
	assert_false(first_target.is_valid())
	assert_true(second.explosive.is_chain_armed(), "A barrel blast chains into barrels inside its radius")
	await wait_process_frames(1)
	assert_false(is_instance_valid(first))
	assert_eq(registry.targets(), [second.grapple_target()] as Array[GrappleTarget])
	assert_eq(controller.explosive_barrel_count(), 1)
	second.explosive._physics_process(definition.explosion_definition.chain_fuse_seconds + 0.01)
	assert_signal_emit_count(controller, "explosion_resolved", 2)
	await wait_process_frames(1)
	assert_true(registry.targets().is_empty())
	assert_false(controller.is_physics_processing(), "Without barrels no push checks run")


func test_player_overlap_pushes_barrels_every_physics_step_without_slowing_the_player() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	var player := PlayerController.new()
	autofree(player)
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	controller.configure_run(player, _world_with_floors([13, 14]), FixtureLoader.terrain_registry(), 16.0, null, [], [], [
		GeneratedExplosiveBarrelSpawn.new(Vector2i(6, 12), definition, 1),
		GeneratedExplosiveBarrelSpawn.new(Vector2i(14, 12), definition, 2),
	])
	assert_false(controller.is_physics_processing(), "An inactive run runs no push checks")
	controller.set_active(true)
	assert_true(controller.is_physics_processing())
	var barrels := _explosive_barrels(controller)
	var near := barrels[0]
	var far := barrels[1]
	for barrel in barrels:
		for _step in 600:
			if barrel.is_sleeping():
				break
			barrel._physics_process(1.0 / 60.0)
		assert_true(barrel.is_sleeping())
	var near_rest := near.global_position
	var far_rest := far.global_position
	player.global_position = near_rest + Vector2(-20.0, 0.0)
	player.velocity = Vector2(200.0, -30.0)

	controller._physics_process(1.0 / 60.0)

	assert_eq(player.velocity, Vector2(200.0, -30.0), "Pushing a barrel never slows the player")
	assert_false(near.is_sleeping())
	assert_gt(near.global_position.x, near_rest.x)
	assert_almost_eq(near.velocity.x, 200.0 * definition.push_velocity_ratio, 0.001)
	assert_true(far.is_sleeping(), "Distant barrels are rejected without waking")
	assert_eq(far.global_position, far_rest)

	controller.set_active(false)
	assert_false(controller.is_physics_processing())
	assert_false(near.is_physics_processing())


func _explosive_barrels(controller: RunItemController) -> Array[ExplosiveBarrel]:
	var barrels: Array[ExplosiveBarrel] = []
	for child in controller.get_children():
		if child is ExplosiveBarrel and not child.is_queued_for_deletion():
			barrels.append(child as ExplosiveBarrel)
	return barrels


func _world_with_floors(floor_rows: Array[int]) -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	var stone_id := FixtureLoader.terrain_id("Stone")
	for row in floor_rows:
		for col in range(20):
			world.set_committed_by_offset(col, row, stone_id)
	return world


func _item_chests(controller: RunItemController) -> Array[ItemChest]:
	var chests: Array[ItemChest] = []
	for child in controller.get_children():
		if child is ItemChest:
			chests.append(child as ItemChest)
	return chests


func _step_until_sleeping(chests: Array[ItemChest]) -> void:
	for _step in 600:
		var all_sleeping := true
		for chest in chests:
			if not chest.is_sleeping():
				all_sleeping = false
				chest._physics_process(1.0 / 60.0)
		if all_sleeping:
			return


func _throw_controller(fill_terrain_id: int) -> RunItemController:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	player.set_physics_process(false)
	var world := WorldGrid.new(WorldDimensions.new(20, 30), fill_terrain_id)
	var player_cell := Vector2i(10, 10)
	world.set_committed_by_offset(player_cell.x, player_cell.y, FixtureLoader.terrain_id("Air"))
	player.global_position = HexMetrics.center_for_offset(player_cell.x, player_cell.y, 16.0)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(player, world, FixtureLoader.terrain_registry(), 16.0)
	return controller


func _definition_with_tag(definitions: Array[ItemDefinition], tag: StringName) -> ItemDefinition:
	for definition in definitions:
		if definition.perk_tags.has(tag):
			return definition
	return null


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
