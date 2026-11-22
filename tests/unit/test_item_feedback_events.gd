extends GutTest


const STEP := 1.0 / 60.0


func test_projectile_throw_reports_definition_origin_and_aim_direction() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"))
	var small_bomb := controller._inventory.definitions()[0]
	var origin := controller._player.global_position
	watch_signals(controller)

	assert_true(controller.throw_selected(origin + Vector2(100.0, 0.0), true))

	assert_signal_emit_count(controller, "item_thrown", 1)
	assert_eq(get_signal_parameters(controller, "item_thrown"), [small_bomb, origin, Vector2.RIGHT])
	assert_signal_not_emitted(controller, "tool_used")


func test_thrown_projectile_is_reported_with_its_definition() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"))
	var small_bomb := controller._inventory.definitions()[0]
	watch_signals(controller)

	assert_true(controller.throw_selected(controller._player.global_position + Vector2(100.0, 0.0), true))

	var projectiles := _projectiles(controller)
	assert_eq(projectiles.size(), 1)
	assert_signal_emit_count(controller, "projectile_spawned", 1)
	assert_eq(get_signal_parameters(controller, "projectile_spawned"), [projectiles[0], small_bomb])
	assert_true(projectiles[0].is_inside_tree(), "The projectile is in the world when it is reported")


func test_immediate_tool_reports_tool_use_only_when_it_changes_terrain() -> void:
	var idle := _throw_controller(FixtureLoader.terrain_id("Air"))
	var shovel := _definition_with_tag(idle._inventory.definitions(), &"shovel")
	var shovel_index := idle._inventory.definitions().find(shovel)
	idle.debug_grant_item(shovel_index)
	idle.select_index(shovel_index)
	watch_signals(idle)
	assert_false(idle.throw_selected(idle._player.global_position + Vector2(0.0, 64.0), true))
	assert_signal_not_emitted(idle, "tool_used")

	var digging := _throw_controller(FixtureLoader.terrain_id("Sand"))
	digging.debug_grant_item(shovel_index)
	digging.select_index(shovel_index)
	var origin := digging._player.global_position
	watch_signals(digging)
	assert_true(digging.throw_selected(origin + Vector2(0.0, 64.0), true))

	assert_eq(get_signal_parameters(digging, "tool_used"), [shovel, origin, Vector2.DOWN])
	assert_signal_not_emitted(digging, "projectile_spawned")
	assert_signal_not_emitted(digging, "item_thrown")


func test_item_selection_is_reported_only_when_it_changes() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"))
	var definitions := controller._inventory.definitions()
	watch_signals(controller)

	controller.select_index(0)
	assert_signal_not_emitted(controller, "item_selected")
	controller.select_index(1)
	controller.select_index(1)

	assert_signal_emit_count(controller, "item_selected", 1)
	assert_eq(get_signal_parameters(controller, "item_selected"), [definitions[1]])
	controller.cycle_selection(1)
	assert_signal_emit_count(controller, "item_selected", 2)
	assert_eq(get_signal_parameters(controller, "item_selected"), [definitions[2]])


func test_world_body_bounce_reports_the_speed_before_the_rebound() -> void:
	var body := WorldRigidBody2D.new()
	add_child_autofree(body)
	body.world = _world_with_floors([12])
	body.terrain_registry = FixtureLoader.terrain_registry()
	body.hex_radius = 16.0
	body.configure_body({"gravity": 0.0, "velocity": Vector2(0.0, 300.0), "bounce_on_impact": true})
	body.global_position = HexMetrics.center_for_offset(5, 11, 16.0)
	watch_signals(body)

	for _step in 60:
		body.advance_body(STEP)
		if get_signal_emit_count(body, "bounced") > 0:
			break

	assert_signal_emit_count(body, "bounced", 1)
	assert_almost_eq(float(get_signal_parameters(body, "bounced")[0]), 300.0, 0.001)
	assert_lt(body.velocity.y, 0.0)


func test_thrown_bomb_bounce_is_reported_with_its_definition() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"), [14])
	var small_bomb := controller._inventory.definitions()[0]
	controller.set_active(true)
	assert_true(controller.throw_selected(controller._player.global_position + Vector2(0.0, 100.0), true))
	var projectile := _projectiles(controller)[0]
	watch_signals(controller)

	for _step in 120:
		projectile._physics_process(STEP)
		if get_signal_emit_count(controller, "projectile_bounced") > 0:
			break

	assert_signal_emitted(controller, "projectile_bounced")
	var parameters: Array = get_signal_parameters(controller, "projectile_bounced")
	assert_eq(parameters[0], projectile.global_position)
	assert_gt(float(parameters[1]), 0.0)
	assert_eq(parameters[2], small_bomb)


func test_fluid_bottle_impact_reports_projectile_end_and_burst_color() -> void:
	var controller := _throw_controller(FixtureLoader.terrain_id("Air"), [14])
	var bottle: ItemDefinition = load("res://config/items/water_bottle.tres")
	var registered := controller._item_registry.get_definition(bottle.stable_id)
	var bottle_index := controller._inventory.definitions().find(registered)
	controller.debug_grant_item(bottle_index)
	controller.select_index(bottle_index)
	controller.set_active(true)
	assert_true(controller.throw_selected(controller._player.global_position + Vector2(0.0, 100.0), true))
	var projectile := _projectiles(controller)[0]
	watch_signals(controller)

	for _step in 240:
		projectile._physics_process(STEP)
		if get_signal_emit_count(controller, "projectile_resolved") > 0:
			break

	assert_signal_emit_count(controller, "projectile_resolved", 1)
	var resolved: Array = get_signal_parameters(controller, "projectile_resolved")
	assert_eq(resolved[1], registered)
	assert_eq(resolved[2], &"impact")
	assert_signal_emit_count(controller, "fluid_bottle_burst", 1)
	assert_eq(
		get_signal_parameters(controller, "fluid_bottle_burst"),
		[resolved[0], FixtureLoader.terrain_definition_named("Water").debug_color]
	)


func test_chain_armed_barrel_reports_its_running_fuse_and_destruction_position() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	controller.configure_run(null, _world_with_floors([13, 14]), FixtureLoader.terrain_registry(), 16.0, null, [], [], [
		GeneratedExplosiveBarrelSpawn.new(Vector2i(6, 12), definition, 1),
		GeneratedExplosiveBarrelSpawn.new(Vector2i(13, 12), definition, 2),
	])
	controller.set_active(true)
	var barrels := _explosive_barrels(controller)
	var first_position := barrels[0].global_position
	watch_signals(controller)

	assert_true(barrels[0].explosive.request_immediate_detonation())

	assert_signal_emit_count(controller, "explosive_fuse_armed", 1)
	assert_eq(
		get_signal_parameters(controller, "explosive_fuse_armed"),
		[barrels[1].explosive.global_position, definition.explosion_definition.chain_fuse_seconds]
	)
	assert_eq(get_signal_parameters(controller, "world_object_destroyed"), [definition.statistics_key, first_position])


func test_falling_barrel_reports_its_terrain_rebound() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	var definition := load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition
	controller.configure_run(null, _world_with_floors([14]), FixtureLoader.terrain_registry(), 16.0, null, [], [], [
		GeneratedExplosiveBarrelSpawn.new(Vector2i(6, 8), definition, 1),
	])
	controller.set_active(true)
	var barrel := _explosive_barrels(controller)[0]
	watch_signals(controller)

	for _step in 240:
		barrel._physics_process(STEP)
		if get_signal_emit_count(controller, "barrel_bumped") > 0:
			break

	assert_signal_emitted(controller, "barrel_bumped")
	var parameters: Array = get_signal_parameters(controller, "barrel_bumped")
	assert_eq(parameters[0], barrel.global_position)
	assert_gt(float(parameters[1]), 0.0)
	assert_lt(float(parameters[1]), definition.impact_detonation_speed)


func test_opened_container_and_claim_report_where_the_container_stood() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var world := WorldGrid.new(WorldDimensions.new(16, 32), FixtureLoader.terrain_id("Air"))
	var definition := load("res://config/items/item_chest.tres") as ItemChestDefinition
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(null, world, FixtureLoader.terrain_registry(), 16.0, null, [
		GeneratedItemChestSpawn.new(Vector2i(5, 10), definition, 77),
	])
	controller.set_active(true)
	var chest := controller.get_children().filter(func(child: Node) -> bool: return child is ItemChest)[0] as ItemChest
	var chest_position := chest.global_position
	watch_signals(controller)

	controller._on_item_chest_touched(chest)

	assert_eq(get_signal_parameters(controller, "reward_container_opened"), [chest_position, definition.statistics_key])
	assert_true(controller.apply_pending_reward(0))
	var claim := get_signal_parameters(controller, "reward_claimed")[0] as RewardClaim
	assert_eq(claim.world_position, chest_position)


func test_excavator_reports_deployment_and_each_drill_tick() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(null, _world_with_floors([6]), FixtureLoader.terrain_registry(), 16.0)
	controller.set_active(true)
	var factory := load("res://config/items/factory/excavator_factory.tres") as ExcavatorItemActionFactory
	var landing := HexMetrics.center_for_offset(5, 5, 16.0)
	watch_signals(controller)

	controller.spawn_excavator(landing, factory)

	assert_eq(get_signal_parameters(controller, "excavator_deployed"), [landing])
	var robot := controller.get_children().filter(func(child: Node) -> bool: return child is ExcavatorRobot)[0] as ExcavatorRobot
	controller.excavator_tick(robot, factory)
	assert_signal_emit_count(controller, "excavator_drilled", 1)
	assert_eq(get_signal_parameters(controller, "excavator_drilled"), [landing, 3])


func test_every_catalog_item_declares_a_feedback_key() -> void:
	for definition in _item_registry().all_definitions():
		assert_ne(definition.feedback_key, &"", "%s needs a feedback_key" % definition.display_name)


func _throw_controller(fill_terrain_id: int, floor_rows: Array[int] = []) -> RunItemController:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	player.set_physics_process(false)
	var world := WorldGrid.new(WorldDimensions.new(20, 30), fill_terrain_id)
	var stone_id := FixtureLoader.terrain_id("Stone")
	for row in floor_rows:
		for col in range(20):
			world.set_committed_by_offset(col, row, stone_id)
	var player_cell := Vector2i(10, 10)
	world.set_committed_by_offset(player_cell.x, player_cell.y, FixtureLoader.terrain_id("Air"))
	player.global_position = HexMetrics.center_for_offset(player_cell.x, player_cell.y, 16.0)
	controller.configure_catalog(_item_registry(), 16.0)
	controller.configure_run(player, world, FixtureLoader.terrain_registry(), 16.0)
	return controller


func _world_with_floors(floor_rows: Array[int]) -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(20, 32), FixtureLoader.terrain_id("Air"))
	var stone_id := FixtureLoader.terrain_id("Stone")
	for row in floor_rows:
		for col in range(20):
			world.set_committed_by_offset(col, row, stone_id)
	return world


func _projectiles(controller: RunItemController) -> Array[ItemProjectile]:
	var projectiles: Array[ItemProjectile] = []
	for child in controller.get_children():
		if child is ItemProjectile:
			projectiles.append(child as ItemProjectile)
	return projectiles


func _explosive_barrels(controller: RunItemController) -> Array[ExplosiveBarrel]:
	var barrels: Array[ExplosiveBarrel] = []
	for child in controller.get_children():
		if child is ExplosiveBarrel:
			barrels.append(child as ExplosiveBarrel)
	return barrels


func _definition_with_tag(definitions: Array[ItemDefinition], tag: StringName) -> ItemDefinition:
	for definition in definitions:
		if definition.perk_tags.has(tag):
			return definition
	return null


func _item_registry() -> ItemRegistry:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(load("res://config/items/catalog.tres")))
	return registry
