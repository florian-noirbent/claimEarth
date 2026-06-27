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
	world.set_committed_by_offset(2, 2, FixtureLoader.terrain_id("Lava"), 26)

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
	assert_eq(projectile._sample_fill(projectile.global_position), 26)
	assert_true(definition.blast_reaction.resolve().detonate_immediately)
	assert_not_null(definition.hazard_behavior.resolve_for_fill(26))
	projectile._physics_process(0.016)

	assert_eq(resolved_kinds, [&"lava"])
	assert_true(projectile.is_queued_for_deletion())
