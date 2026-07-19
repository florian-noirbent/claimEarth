extends GutTest


func test_perk_geode_is_brighter_than_an_item_chest_and_configures_a_five_by_twenty_pulse() -> void:
	var geode := load("res://config/items/perk_geode.tres") as PerkGeodeDefinition
	var chest := load("res://config/items/item_chest.tres") as ItemChestDefinition
	assert_not_null(geode)
	assert_not_null(chest)
	assert_true(geode.validate().is_empty())
	assert_true(geode.emits_light)
	assert_gt(geode.emitted_light_level_override, 90)
	assert_not_null(geode.destruction_pulse)
	assert_eq(geode.destruction_pulse.width, 5)
	assert_eq(geode.destruction_pulse.step_count, 20)
	assert_eq(geode.destruction_pulse.pulse_tick_count, 16)
	assert_almost_eq(geode.destruction_pulse.step_interval_seconds, 0.1, 0.0001)
	assert_almost_eq(geode.destruction_pulse.front_load_decay, 2.65, 0.0001)


func test_geode_pulse_clears_a_five_by_twenty_downward_block() -> void:
	var definition := load("res://config/items/perk_geode.tres") as PerkGeodeDefinition
	var world := WorldGrid.new(WorldDimensions.new(16, 30), FixtureLoader.terrain_id("Dirt"))
	var pulse := DirectionalTerrainPulse.new(definition.destruction_pulse, Vector2i(8, 3))
	for _step in range(20):
		pulse.advance(0.1, world, FixtureLoader.terrain_id("Air"))
	assert_true(pulse.is_complete())
	for row in range(4, 24):
		for column in range(6, 11):
			assert_eq(world.get_committed_by_offset(column, row), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(5, 4), FixtureLoader.terrain_id("Dirt"))


func test_geode_pulse_uses_the_configured_front_loaded_sixteen_beat_distribution() -> void:
	var definition := load("res://config/items/perk_geode.tres") as PerkGeodeDefinition
	var world := WorldGrid.new(WorldDimensions.new(16, 30), FixtureLoader.terrain_id("Dirt"))
	var pulse := DirectionalTerrainPulse.new(definition.destruction_pulse, Vector2i(8, 3))
	var cleared_rows_per_beat: Array[int] = []
	var previous_depth := 0

	for _beat in range(definition.destruction_pulse.pulse_tick_count):
		pulse.advance(definition.destruction_pulse.step_interval_seconds, world, FixtureLoader.terrain_id("Air"))
		var cleared_depth := _cleared_depth(world, Vector2i(8, 3), definition.destruction_pulse)
		cleared_rows_per_beat.append(cleared_depth - previous_depth)
		previous_depth = cleared_depth

	assert_eq(cleared_rows_per_beat, [3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1])
	assert_eq(previous_depth, definition.destruction_pulse.step_count)
	assert_true(pulse.is_complete())


func test_geode_pulse_catches_up_all_due_beats_without_skipping_its_final_depth() -> void:
	var definition := load("res://config/items/perk_geode.tres") as PerkGeodeDefinition
	var world := WorldGrid.new(WorldDimensions.new(16, 30), FixtureLoader.terrain_id("Dirt"))
	var pulse := DirectionalTerrainPulse.new(definition.destruction_pulse, Vector2i(8, 3))
	var duration: float = float(definition.destruction_pulse.pulse_tick_count) * definition.destruction_pulse.step_interval_seconds

	pulse.advance(duration * 0.5, world, FixtureLoader.terrain_id("Air"))
	assert_eq(_cleared_depth(world, Vector2i(8, 3), definition.destruction_pulse), 15)
	assert_false(pulse.is_complete())
	pulse.advance(duration * 2.0, world, FixtureLoader.terrain_id("Air"))

	assert_true(pulse.is_complete())
	assert_eq(_cleared_depth(world, Vector2i(8, 3), definition.destruction_pulse), 20)
	assert_eq(world.get_committed_by_offset(8, 23), FixtureLoader.terrain_id("Air"))
	assert_eq(world.get_committed_by_offset(8, 24), FixtureLoader.terrain_id("Dirt"))


func test_directional_pulse_rejects_a_non_positive_front_load_decay() -> void:
	var definition := DirectionalTerrainPulseDefinition.new()
	definition.front_load_decay = 0.0

	assert_true("\n".join(definition.validate()).contains("front-load decay"))


func test_directional_pulse_visual_progress_follows_the_same_front_loaded_curve() -> void:
	var definition := load("res://config/items/perk_geode.tres") as PerkGeodeDefinition
	var pulse_definition := definition.destruction_pulse
	var effect := DirectionalPulseEffect.new()
	effect.duration_seconds = float(pulse_definition.pulse_tick_count) * pulse_definition.step_interval_seconds
	effect.front_load_decay = pulse_definition.front_load_decay

	for tick in range(1, pulse_definition.pulse_tick_count + 1):
		effect._elapsed = float(tick) * pulse_definition.step_interval_seconds
		var visual_depth := effect.distance_progress() * pulse_definition.step_count
		var terrain_depth := float(pulse_definition.steps_after_tick(tick))
		assert_gte(visual_depth, terrain_depth)
		assert_lte(visual_depth - terrain_depth, 1.0)

	assert_almost_eq(effect.distance_progress(), 1.0, 0.0001)
	effect.free()


func _cleared_depth(world: WorldGrid, origin: Vector2i, definition: DirectionalTerrainPulseDefinition) -> int:
	var air_id := FixtureLoader.terrain_id("Air")
	var depth := 0
	for row in range(origin.y + 1, origin.y + definition.step_count + 1):
		if world.get_committed_by_offset(origin.x, row) != air_id:
			break
		depth += 1
	return depth


func test_relentless_drops_a_lava_proof_flag_through_the_common_projectile_path() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(load("res://config/items/catalog.tres")))
	var world := WorldGrid.new(WorldDimensions.new(20, 30), FixtureLoader.terrain_id("Air"))
	controller.configure_catalog(registry, 16.0)
	controller.configure_run(player, world, FixtureLoader.terrain_registry(), 16.0)
	var modifiers := PerkModifierSnapshot.new()
	modifiers.flags._set_value("survive_lava_acid_and_drop_on_death", true)
	controller.set_perk_modifiers(modifiers)

	assert_true(controller.drop_flag_on_player_death())
	assert_true(controller.is_flag_in_flight())
	assert_true(controller._active_flag_projectile.destructive_terrain_tags.is_empty())
	assert_eq(_count_for(controller.inventory_status(), "Flag"), 0)


func _count_for(status: Dictionary, item_name: String) -> int:
	for item in status.items:
		if item.name == item_name:
			return int(item.count)
	return -1
