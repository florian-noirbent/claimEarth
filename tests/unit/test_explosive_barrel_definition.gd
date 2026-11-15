extends GutTest


func _definition() -> ExplosiveBarrelDefinition:
	return load("res://config/items/explosive_barrel.tres") as ExplosiveBarrelDefinition


func test_configured_barrel_definition_is_valid_and_uses_its_own_large_blast() -> void:
	var definition := _definition()
	assert_not_null(definition)
	assert_eq(definition.validate(), PackedStringArray())
	assert_not_null(definition.barrel_scene)
	assert_eq(definition.required_edge_clearance(), definition.chamber_radius)
	assert_eq(definition.detonating_terrain_tags, PackedStringArray(["lava", "acid"]))
	assert_true(definition.detonates_in_blast_radius)

	var explosion := definition.explosion_definition
	var large_bomb := load("res://config/items/explosions/large_bomb_explosion.tres") as ExplosionDefinition
	assert_not_null(explosion)
	assert_ne(explosion.resource_path, large_bomb.resource_path, "The barrel blast must be tuned separately")
	assert_eq(explosion.blast_radius, large_bomb.blast_radius)
	assert_eq(explosion.vaporize_radius, large_bomb.vaporize_radius)
	assert_eq(explosion.player_kill_radius, large_bomb.player_kill_radius)
	assert_null(explosion.perk_terrain_emission)
	assert_not_null(explosion.terrain_emission)
	assert_eq(explosion.terrain_emission.product.display_name, "Sulfur Dioxide")
	assert_gt(explosion.terrain_emission.quantity, explosion.terrain_emission.product.storage_capacity)


func test_barrel_is_selectable_from_the_generated_item_catalog() -> void:
	var catalog := load("res://config/generation/item_catalog.tres") as GeneratedItemPlacementCatalog
	assert_not_null(catalog)
	assert_true(catalog.definitions.has(_definition()))


func test_validation_rejects_missing_or_invalid_tuning() -> void:
	var cases := {
		"barrel_scene": [null, "requires a barrel scene"],
		"explosion_definition": [null, "requires an explosion definition"],
		"impact_detonation_speed": [0.0, "impact_detonation_speed must be positive"],
		"chamber_radius": [0, "chamber_radius must be positive"],
		"detonating_terrain_clearance": [-1, "detonating_terrain_clearance must not be negative"],
		"gravity": [0.0, "gravity must be positive"],
		"terminal_fall_speed": [0.0, "terminal_fall_speed must be positive"],
		"body_radius_radii": [0.0, "geometry sizes must be positive"],
		"sprite_width_radii": [0.0, "geometry sizes must be positive"],
		"bounce_damping": [1.5, "bounce_damping must be between zero and one"],
		"ground_friction": [-1.0, "ground_friction must not be negative"],
		"support_contact_distance": [0.0, "support_contact_distance must be positive"],
		"rest_speed": [0.0, "rest_speed must be positive"],
		"rest_max_slope_degrees": [90.0, "rest_max_slope_degrees must be at least zero and below 90"],
		"push_velocity_ratio": [-0.1, "push tuning must not be negative"],
		"max_push_speed": [-1.0, "push tuning must not be negative"],
		"hook_pull_acceleration": [-1.0, "hook pull tuning must not be negative"],
		"max_hook_pull_speed": [-1.0, "hook pull tuning must not be negative"],
		"grounded_check_interval_seconds": [0.0, "terrain check intervals must be positive"],
		"offscreen_check_interval_seconds": [0.0, "terrain check intervals must be positive"],
		"stuck_check_interval_seconds": [0.0, "terrain check intervals must be positive"],
		"screen_margin_radii": [-1.0, "screen_margin_radii must not be negative"],
	}
	for property: String in cases:
		var definition := _definition().duplicate() as ExplosiveBarrelDefinition
		definition.set(property, cases[property][0])
		var errors := "\n".join(definition.validate())
		assert_true(errors.contains(cases[property][1]), "%s must be validated, got: %s" % [property, errors])


func test_validation_rejects_bodies_larger_than_the_chamber_and_empty_tags() -> void:
	var definition := _definition().duplicate() as ExplosiveBarrelDefinition
	definition.chamber_radius = 1
	definition.body_radius_radii = 2.0
	assert_true("\n".join(definition.validate()).contains("must fit inside its generated chamber"))

	definition = _definition().duplicate() as ExplosiveBarrelDefinition
	definition.detonating_terrain_tags = PackedStringArray(["lava", ""])
	assert_true("\n".join(definition.validate()).contains("must not contain empty tags"))

	definition = _definition().duplicate() as ExplosiveBarrelDefinition
	definition.detonating_terrain_tags = PackedStringArray()
	assert_eq(definition.validate(), PackedStringArray(), "A barrel may opt out of terrain detonation")


func test_validation_reports_nested_explosion_errors() -> void:
	var definition := _definition().duplicate() as ExplosiveBarrelDefinition
	var explosion := definition.explosion_definition.duplicate() as ExplosionDefinition
	explosion.blast_radius = 0
	definition.explosion_definition = explosion
	assert_true("\n".join(definition.validate()).contains("explosion: explosion blast_radius must be positive"))

	explosion = definition.explosion_definition.duplicate() as ExplosionDefinition
	explosion.blast_radius = 10
	var emission := TerrainEmissionDefinition.new()
	explosion.terrain_emission = emission
	definition.explosion_definition = explosion
	assert_true("\n".join(definition.validate()).contains("explosion emission: terrain emission requires a product"))
