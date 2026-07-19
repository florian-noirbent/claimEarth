extends GutTest

const GameplayAssertionsScript = preload("res://tests/helpers/gameplay_assertions.gd")

func test_configure_before_entering_tree_builds_visuals_without_nil_polygon_access() -> void:
	var projectile := ItemProjectile.new()
	projectile.configure({
		"polygon": PackedVector2Array([-4, -8, 4, -8, 4, 8, -4, 8]),
		"color": Color(1, 0.8, 0.2, 1),
		"fuse_seconds": 5.0,
	})
	add_child_autofree(projectile)
	await wait_process_frames(1)

	GameplayAssertionsScript.assert_projectile_visual_configured(self, projectile, 8)


func test_projectile_can_render_an_optional_world_sprite() -> void:
	var projectile := ItemProjectile.new()
	projectile.configure({"visual_texture": load("res://assets/objects/flare.svg") as Texture2D, "fuse_seconds": 5.0})
	add_child_autofree(projectile)
	await wait_process_frames(1)

	assert_not_null(projectile.sprite)
	assert_not_null(projectile.sprite.texture)
	assert_gt(projectile.sprite.scale.x, 0.0)


func test_water_bottle_action_uses_its_icon_as_a_projectile_sprite() -> void:
	var definition := load("res://config/items/water_bottle.tres") as ItemDefinition
	var action := definition.action_factory.create_action(definition) as FluidBottleItemAction
	var projectile_data := action.create_projectile(Vector2.ZERO, Vector2.RIGHT, ItemTrajectoryService.new(), Vector2.ZERO)

	assert_eq(projectile_data.get("visual_texture"), definition.icon)


func test_projectile_can_sample_world_terrain_after_pre_tree_configuration() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))

	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	var sample_position := HexMetrics.center_for_offset(2, 2, projectile.hex_radius)
	projectile.global_position = sample_position
	projectile.configure({"fuse_seconds": 5.0})
	add_child_autofree(projectile)

	var definition := projectile._sample_terrain(sample_position)

	assert_not_null(definition)
	assert_eq(definition.display_name, "Stone")


func test_blast_impulse_uses_direction_and_linear_distance_falloff() -> void:
	var projectile := ItemProjectile.new()
	add_child_autofree(projectile)
	projectile.global_position = Vector2(50.0, 0.0)

	projectile.apply_blast_impulse(Vector2.ZERO, 800.0, 100.0)

	assert_eq(projectile.velocity, Vector2(400.0, 0.0))


func test_blast_impulse_does_not_affect_projectile_outside_radius() -> void:
	var projectile := ItemProjectile.new()
	add_child_autofree(projectile)
	projectile.global_position = Vector2(101.0, 0.0)
	projectile.velocity = Vector2(12.0, -4.0)

	projectile.apply_blast_impulse(Vector2.ZERO, 800.0, 100.0)

	assert_eq(projectile.velocity, Vector2(12.0, -4.0))


func test_bomb_projectile_bounces_on_solid_terrain_until_fuse_expires() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))

	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	projectile.hex_radius = 16.0
	projectile.global_position = HexMetrics.center_for_offset(2, 1, projectile.hex_radius)
	projectile.configure({
		"fuse_seconds": 5.0,
		"bounce_on_impact": true,
		"gravity": 0.0,
		"velocity": Vector2(0.0, 120.0),
	})
	add_child_autofree(projectile)
	await wait_until(func() -> bool:
		return is_instance_valid(projectile) and projectile.velocity.y < 0.0
	, 0.5)

	assert_true(is_instance_valid(projectile))
	assert_true(projectile.velocity.y < 0.0)


func test_bomb_projectile_bounces_from_the_virtual_map_side() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	projectile.hex_radius = 16.0
	projectile.configure({
		"fuse_seconds": 5.0,
		"bounce_on_impact": true,
		"gravity": 0.0,
		"horizontal_bounce_damping": 0.5,
		"velocity": Vector2(-120.0, 0.0),
		"polygon": PackedVector2Array([-4, -4, 4, -4, 4, 4, -4, 4]),
	})
	projectile.global_position = HexMetrics.center_for_offset(0, 2, projectile.hex_radius)

	projectile.advance_body(0.2)

	assert_eq(projectile.global_position, HexMetrics.center_for_offset(0, 2, projectile.hex_radius))
	assert_eq(projectile.velocity.x, 60.0)


func test_flag_resolves_when_falling_outside_the_bottom_map_edge() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	projectile.hex_radius = 16.0
	projectile.global_position = HexMetrics.center_for_offset(2, 4, projectile.hex_radius)
	projectile.configure({
		"fuse_seconds": 5.0,
		"gravity": 0.0,
		"velocity": Vector2(0.0, 240.0),
	})
	var resolved_kinds: Array[StringName] = []
	projectile.resolved.connect(func(_projectile: ItemProjectile, _impact_position: Vector2, resolution_kind: StringName) -> void:
		resolved_kinds.append(resolution_kind)
	)

	projectile._physics_process(0.2)

	assert_eq(resolved_kinds, [&"impact"])
	assert_true(projectile.is_queued_for_deletion())


func test_buried_bouncing_projectile_resolves_when_fuse_expires() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Stone"))

	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	projectile.hex_radius = 16.0
	projectile.global_position = HexMetrics.center_for_offset(2, 2, projectile.hex_radius)
	projectile.configure({
		"fuse_seconds": 0.01,
		"bounce_on_impact": true,
		"gravity": 0.0,
		"velocity": Vector2.ZERO,
	})
	add_child_autofree(projectile)
	var resolved_kinds: Array[StringName] = []
	projectile.resolved.connect(func(_projectile: ItemProjectile, _impact_position: Vector2, resolution_kind: StringName) -> void:
		resolved_kinds.append(resolution_kind)
	)

	projectile._physics_process(0.02)

	assert_eq(resolved_kinds, [&"fuse"])
	assert_true(projectile.is_queued_for_deletion())


func test_lava_sensitive_projectile_ignores_lava_below_hazard_fill_threshold() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Lava"), 25)

	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	projectile.hex_radius = 16.0
	projectile.global_position = HexMetrics.center_for_offset(2, 2, projectile.hex_radius)
	projectile.configure({
		"fuse_seconds": 5.0,
		"gravity": 0.0,
		"velocity": Vector2.ZERO,
		"destroyed_by_lava": true,
	})
	add_child_autofree(projectile)
	projectile._physics_process(0.016)

	assert_true(is_instance_valid(projectile))


func test_lava_sensitive_projectile_resolves_on_lava_at_hazard_fill_threshold() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Lava"), 13)

	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	projectile.hex_radius = 16.0
	projectile.global_position = HexMetrics.center_for_offset(2, 2, projectile.hex_radius)
	projectile.configure({
		"fuse_seconds": 5.0,
		"gravity": 0.0,
		"velocity": Vector2.ZERO,
		"destroyed_by_lava": true,
	})
	add_child_autofree(projectile)
	var resolved_kinds: Array[StringName] = []
	projectile.resolved.connect(func(_projectile: ItemProjectile, _impact_position: Vector2, resolution_kind: StringName) -> void:
		resolved_kinds.append(resolution_kind)
	)
	var definition := projectile._sample_terrain(projectile.global_position)
	assert_not_null(definition)
	assert_eq(definition.display_name, "Lava")
	assert_eq(projectile._sample_quantity(projectile.global_position), 13)
	assert_true(definition.blast_reaction.resolve().detonate_immediately)
	assert_not_null(definition.hazard_behavior.resolve_for_quantity(13))
	projectile._physics_process(0.016)

	assert_eq(resolved_kinds, [&"lava"])
	assert_true(projectile.is_queued_for_deletion())


func test_destructive_terrain_tags_match_acid_without_requiring_lava_reaction() -> void:
	var acid := TerrainDefinition.new()
	acid.perk_tags = PackedStringArray(["acid"])
	acid.hazard_behavior = FixtureLoader.terrain_definition_named("Lava").hazard_behavior
	var projectile := ItemProjectile.new()
	projectile.destructive_terrain_tags = PackedStringArray(["acid"])

	assert_eq(projectile._destructive_terrain_kind(acid, 13), &"acid")
	assert_eq(projectile._destructive_terrain_kind(acid, 12), &"")


func test_flag_resolves_with_acid_when_the_acid_hazard_is_active() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(5, 5), FixtureLoader.terrain_id("Air"))
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Sulfuric Acid"), 13)
	var definition := load("res://config/items/flag.tres") as ItemDefinition
	var action := definition.action_factory.create_action(definition) as ItemAction
	var projectile := ItemProjectile.new()
	projectile.world = world
	projectile.terrain_registry = registry
	projectile.hex_radius = 16.0
	projectile.global_position = HexMetrics.center_for_offset(2, 2, projectile.hex_radius)
	projectile.configure(action.create_projectile(projectile.global_position, projectile.global_position + Vector2.RIGHT, ItemTrajectoryService.new(), Vector2.ZERO))
	add_child_autofree(projectile)
	var resolved_kinds: Array[StringName] = []
	projectile.resolved.connect(func(_projectile: ItemProjectile, _impact_position: Vector2, resolution_kind: StringName) -> void:
		resolved_kinds.append(resolution_kind)
	)

	projectile._physics_process(0.016)

	assert_eq(resolved_kinds, [&"acid"])
	assert_true(projectile.is_queued_for_deletion())
