extends GutTest


func test_jelly_buoyancy_overcomes_gravity_while_immersed() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var water_cell := Vector2i(3, 3)
	world.set_committed_by_offset(water_cell.x, water_cell.y, FixtureLoader.terrain_id("Water"), 127)
	player.global_position = HexMetrics.center_for_offset(water_cell.x, water_cell.y, 16.0)
	player.configure_environment(world, registry, 16.0)
	player.set_perk_modifiers(_jelly_modifiers())
	player.velocity = Vector2.ZERO

	player._apply_fluid_drag(0.1)

	assert_lt(player.velocity.y, 0.0)


func test_jelly_ignores_fluid_drag_while_other_players_remain_damped() -> void:
	var jelly_player := _player_fully_immersed_in_water()
	jelly_player.set_perk_modifiers(_jelly_modifiers())
	var ordinary_player := _player_fully_immersed_in_water()
	var initial_horizontal_speed := 240.0
	jelly_player.velocity = Vector2(initial_horizontal_speed, 0.0)
	ordinary_player.velocity = Vector2(initial_horizontal_speed, 0.0)

	jelly_player._apply_fluid_drag(0.5)
	ordinary_player._apply_fluid_drag(0.5)

	assert_almost_eq(jelly_player.velocity.x, initial_horizontal_speed, 0.001)
	assert_almost_eq(ordinary_player.velocity.x, initial_horizontal_speed * exp(-0.8 * 0.5), 0.001)
	assert_lt(ordinary_player.velocity.x, jelly_player.velocity.x)


func test_jelly_liquid_jump_does_not_turn_the_surface_into_ground() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var water_cell := Vector2i(3, 3)
	world.set_committed_by_offset(water_cell.x, water_cell.y, FixtureLoader.terrain_id("Water"), 127)
	player.global_position = HexMetrics.center_for_offset(water_cell.x, water_cell.y, 16.0) + Vector2(0.0, -8.0)
	player.configure_environment(world, registry, 16.0)
	player.set_perk_modifiers(_jelly_modifiers())
	player.velocity = Vector2(0.0, -120.0)

	assert_false(player._is_grounded_for_movement())
	assert_true(player._has_jelly_liquid_jump_support())
	var jump := PlayerInputFrame.new()
	jump.jump_pressed = true
	player._movement_model.step(jump, false, 0.016, player._has_jelly_liquid_jump_support())
	assert_eq(player._movement_model.velocity.y, player.movement_config.jump_velocity)


func test_jelly_buoyancy_scales_with_submersion_depth() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var water_cell := Vector2i(3, 3)
	world.set_committed_by_offset(water_cell.x, water_cell.y, FixtureLoader.terrain_id("Water"), 127)
	player.global_position = HexMetrics.center_for_offset(water_cell.x, water_cell.y, 16.0) + Vector2(0.0, -12.0)
	player.configure_environment(world, registry, 16.0)
	player.set_perk_modifiers(_jelly_modifiers())

	var shallow_fraction := player._liquid_submersion_fraction()
	assert_lt(shallow_fraction, 1.0)
	var initial_downward_speed := player.movement_config.gravity * 0.1
	player.velocity = Vector2(0.0, initial_downward_speed)
	player._apply_fluid_drag(0.1)
	var shallow_velocity := player.velocity.y

	player.global_position = HexMetrics.center_for_offset(water_cell.x, water_cell.y, 16.0)
	assert_gt(player._liquid_submersion_fraction(), shallow_fraction)
	player.velocity = Vector2(0.0, initial_downward_speed)
	player._apply_fluid_drag(0.1)

	assert_gt(shallow_velocity, player.velocity.y)


func test_jelly_configures_surface_bounce_and_explosion_impulse() -> void:
	var modifiers := _jelly_modifiers()
	assert_true(bool(modifiers.player.value("liquid_drag_disabled", false)))
	assert_eq(modifiers.player.value("hard_surface_restitution", 0.0), 0.5)
	assert_eq(modifiers.player.value("bounce_settle_speed", 0.0), 60.0)
	assert_true(bool(modifiers.player.value("impact_disabled", false)))
	assert_true(bool(modifiers.explosions.value("player_explosion_impulse_enabled", false)))
	assert_false(modifiers.explosions.has("player_kill_radius_add"))


func test_jelly_normal_landing_produces_a_visible_rebound() -> void:
	var player := _jelly_player()
	var landing := _floor_impact(180.0)

	assert_true(player._apply_jelly_surface_bounce(landing, TerrainBodyMotionResult.new()))
	assert_eq(player.velocity.y, -90.0)
	assert_false(player._grounded)


func test_jelly_harder_landing_rebounds_proportionally_higher() -> void:
	var player := _jelly_player()
	var normal_landing := _floor_impact(180.0)
	var hard_landing := _floor_impact(420.0)

	assert_true(player._apply_jelly_surface_bounce(normal_landing, TerrainBodyMotionResult.new()))
	var normal_rebound := player.velocity.y
	player._grounded = true
	assert_true(player._apply_jelly_surface_bounce(hard_landing, TerrainBodyMotionResult.new()))

	assert_eq(normal_rebound, -90.0)
	assert_eq(player.velocity.y, -210.0)


func test_jelly_small_floor_contact_settles_and_remains_grounded() -> void:
	var player := _jelly_player()
	player.velocity = Vector2(40.0, 0.0)
	player._grounded = true

	assert_false(player._apply_jelly_surface_bounce(_floor_impact(60.0), TerrainBodyMotionResult.new()))
	assert_eq(player.velocity, Vector2(40.0, 0.0))
	assert_true(player._is_grounded_for_movement())


func test_jelly_wall_and_ceiling_contacts_do_not_bounce() -> void:
	var player := _jelly_player()
	player.velocity = Vector2(25.0, 0.0)
	var wall := _contact_impact(Vector2.LEFT, Vector2(-240.0, 0.0))
	var ceiling := _contact_impact(Vector2.DOWN, Vector2(0.0, 240.0))

	assert_false(player._apply_jelly_surface_bounce(wall, TerrainBodyMotionResult.new()))
	assert_false(player._apply_jelly_surface_bounce(ceiling, TerrainBodyMotionResult.new()))
	assert_eq(player.velocity, Vector2(25.0, 0.0))


func test_jelly_does_not_surface_bounce_while_in_liquid() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var water_cell := Vector2i(3, 3)
	world.set_committed_by_offset(water_cell.x, water_cell.y, FixtureLoader.terrain_id("Water"), 127)
	var player := _jelly_player()
	player.global_position = HexMetrics.center_for_offset(water_cell.x, water_cell.y, 16.0)
	player.configure_environment(world, registry, 16.0)

	assert_false(player._apply_jelly_surface_bounce(_floor_impact(300.0), TerrainBodyMotionResult.new()))


func test_settled_jelly_can_walk_and_jump() -> void:
	var player := _jelly_player()
	player._grounded = true
	player.velocity = Vector2.ZERO
	var frame := PlayerInputFrame.new()
	frame.move_axis = 1.0
	frame.jump_pressed = true

	player._movement_model.step(frame, player._is_grounded_for_movement(), 0.016)

	assert_gt(player._movement_model.velocity.x, 0.0)
	assert_eq(player._movement_model.velocity.y, player.movement_config.jump_velocity)


func test_jelly_settles_on_a_hex_floor_then_accepts_buffered_jump() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var floor_cell := Vector2i(3, 3)
	world.set_committed_by_offset(floor_cell.x, floor_cell.y, FixtureLoader.terrain_id("Stone"), 127)
	var player := _jelly_player()
	player.configure_environment(world, registry, 16.0)
	var floor_center := HexMetrics.center_for_offset(floor_cell.x, floor_cell.y, 16.0)
	var start := floor_center + Vector2(5.0, -(16.0 * sqrt(3.0) * 0.5 + 16.0))
	var landing: TerrainBodyMotionResult = player._terrain_motion_solver.move_circle(
		start,
		Vector2(0.0, 50.0),
		0.1,
		player.horizontal_collision_radius,
		player.step_up_height,
		player.support_probe_distance
	)
	player.global_position = landing.position
	player.velocity = landing.velocity
	player._grounded = landing.grounded
	player._handle_physics_impacts(
		landing,
		TerrainBodyMotionResult.new(),
		TerrainBodyUnstuckResult.new(player.global_position, player.velocity)
	)

	assert_true(player._grounded)
	assert_eq(player.velocity.y, 0.0)
	var buffered_jump := PlayerInputFrame.new()
	buffered_jump.jump_pressed = true
	player._movement_model.step(buffered_jump, false, 0.016)
	player._movement_model.step(PlayerInputFrame.new(), player._is_grounded_for_movement(), 0.016)
	assert_eq(player._movement_model.velocity.y, player.movement_config.jump_velocity)


func test_sand_worm_outline_only_shows_while_inside_sand() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Air"))
	var sand_cell := Vector2i(3, 3)
	world.set_committed_by_offset(sand_cell.x, sand_cell.y, FixtureLoader.terrain_id("Sand"), 127)
	player.global_position = HexMetrics.center_for_offset(sand_cell.x, sand_cell.y, 16.0)
	player.configure_environment(world, registry, 16.0)
	var builder := PerkModifierBuilder.new()
	var effect := PerkModifierEffect.new()
	effect.domain = PerkModifierEffect.Domain.TERRAIN
	effect.modifier_key = "player_sand_passable"
	effect.operation = PerkModifierEffect.Operation.SET
	effect.value = 1.0
	effect.apply(builder)
	player.set_perk_modifiers(builder.build())

	player._update_sand_presentation()

	assert_true(player.presentation.sand_outline.visible)
	world.set_committed_by_offset(sand_cell.x, sand_cell.y, FixtureLoader.terrain_id("Air"), WorldGrid.AIR_QUANTITY)
	player._update_sand_presentation()
	assert_false(player.presentation.sand_outline.visible)


func test_sand_worm_collision_policy_survives_pre_tree_configuration_order() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	var builder := PerkModifierBuilder.new()
	var sand_worm := load("res://config/perks/sand_worm.tres") as PerkDefinition
	for effect in sand_worm.effects:
		effect.apply(builder)
	player.set_perk_modifiers(builder.build())
	add_child_autofree(player)
	var sand_cell := Vector2i(3, 3)
	var world := WorldGrid.new(
		WorldDimensions.new(7, 7),
		FixtureLoader.terrain_id("Air")
	)
	world.set_committed_by_offset(
		sand_cell.x,
		sand_cell.y,
		FixtureLoader.terrain_id("Sand"),
		127
	)

	player.configure_environment(
		world,
		FixtureLoader.terrain_registry(),
		16.0
	)

	assert_false(player._terrain_query.is_solid_cell(sand_cell.x, sand_cell.y))
	assert_eq(player.movement_config.gravity, 1400.0)


func _jelly_modifiers() -> PerkModifierSnapshot:
	var builder := PerkModifierBuilder.new()
	var jelly := load("res://config/perks/jelly.tres") as PerkDefinition
	for effect in jelly.effects:
		effect.apply(builder)
	return builder.build()


func _jelly_player() -> PlayerController:
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	player.set_perk_modifiers(_jelly_modifiers())
	return player


func _player_fully_immersed_in_water() -> PlayerController:
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(7, 7), FixtureLoader.terrain_id("Water"))
	player.global_position = HexMetrics.center_for_offset(3, 3, 16.0)
	player.configure_environment(world, registry, 16.0)
	return player


func _floor_impact(downward_speed: float) -> TerrainBodyMotionResult:
	return _contact_impact(Vector2.UP, Vector2(0.0, -downward_speed))


func _contact_impact(normal: Vector2, velocity_change: Vector2) -> TerrainBodyMotionResult:
	var result := TerrainBodyMotionResult.new()
	result.collided = true
	result.hit_normals.append(normal)
	result.velocity_change = velocity_change
	return result
