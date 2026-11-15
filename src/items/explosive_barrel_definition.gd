@tool
## Defines a generated explosive barrel: its scene, blast, triggers, and body tuning.
class_name ExplosiveBarrelDefinition
extends GeneratedItemPlacementDefinition


@export var barrel_scene: PackedScene
@export var explosion_definition: ExplosionDefinition
## Terrain perk tags that detonate the barrel when they touch its body.
@export var detonating_terrain_tags := PackedStringArray(["lava", "acid"])
## When enabled, any explosion whose blast radius reaches the barrel arms its chain fuse.
@export var detonates_in_blast_radius := true
## A collision that changes the barrel's velocity by at least this much detonates it.
@export_range(1.0, 10000.0, 1.0) var impact_detonation_speed := 650.0
@export_category("Generation")
@export_range(1, 12, 1) var chamber_radius := 1
## Places barrels only on anchors whose three lower cells are solid, so they start at rest.
@export var requires_floor_support := true
## Hex steps around an anchor that must hold no detonating terrain, so no barrel starts touching it.
@export_range(0, 12, 1) var detonating_terrain_clearance := 2
@export_category("Motion")
@export_range(0.0, 4000.0, 1.0) var gravity := 880.0
@export_range(0.0, 4000.0, 1.0) var terminal_fall_speed := 720.0
## Collision circle radius, in hex radii.
@export_range(0.25, 4.0, 0.05) var body_radius_radii := 1.2
@export_range(0.25, 8.0, 0.05) var sprite_width_radii := 2.4
## Fraction of the incoming speed kept along a collision normal.
@export_range(0.0, 1.0, 0.01) var bounce_damping := 0.2
## Horizontal velocity damping per second while the barrel rests on terrain.
@export_range(0.0, 60.0, 0.1) var ground_friction := 4.0
## Solid terrain within this distance below the body keeps the barrel supported.
@export_range(0.05, 8.0, 0.05) var support_contact_distance := 0.75
## A grounded barrel slower than this, in world units per second, may come to rest.
@export_range(0.1, 200.0, 0.1) var rest_speed := 8.0
## Steepest supporting slope, in degrees, a slow grounded barrel rests on instead of rolling.
@export_range(0.0, 60.0, 0.5) var rest_max_slope_degrees := 15.0
@export_category("Player Interaction")
## Fraction of the player's horizontal velocity transferred to a pushed barrel.
@export_range(0.0, 4.0, 0.01) var push_velocity_ratio := 0.9
@export_range(0.0, 4000.0, 1.0) var max_push_speed := 260.0
@export_range(0.0, 10000.0, 1.0) var hook_pull_acceleration := 1600.0
@export_range(0.0, 4000.0, 1.0) var max_hook_pull_speed := 420.0
@export_category("Sleep")
## Seconds between support checks of a resting barrel.
@export_range(0.01, 5.0, 0.01) var grounded_check_interval_seconds := 0.1
## Seconds between terrain checks of a sleeping barrel outside the camera view.
@export_range(0.01, 30.0, 0.01) var offscreen_check_interval_seconds := 1.0
## Seconds between terrain checks of a sleeping barrel that found no clear Air around it.
@export_range(0.01, 30.0, 0.01) var stuck_check_interval_seconds := 1.0
## Distance outside the camera view, in hex radii, that still counts as on screen.
@export_range(0.0, 64.0, 0.5) var screen_margin_radii := 12.0


func validate() -> PackedStringArray:
	var errors := super.validate()
	if barrel_scene == null:
		errors.append("explosive barrel definition requires a barrel scene")
	if explosion_definition == null:
		errors.append("explosive barrel definition requires an explosion definition")
	else:
		for error in explosion_definition.validate():
			errors.append("explosion: %s" % error)
	for terrain_tag in detonating_terrain_tags:
		if String(terrain_tag).is_empty():
			errors.append("explosive barrel detonating_terrain_tags must not contain empty tags")
			break
	if impact_detonation_speed <= 0.0:
		errors.append("explosive barrel impact_detonation_speed must be positive")
	if chamber_radius < 1:
		errors.append("explosive barrel chamber_radius must be positive")
	if detonating_terrain_clearance < 0:
		errors.append("explosive barrel detonating_terrain_clearance must not be negative")
	if gravity <= 0.0:
		errors.append("explosive barrel gravity must be positive")
	if terminal_fall_speed <= 0.0:
		errors.append("explosive barrel terminal_fall_speed must be positive")
	if body_radius_radii <= 0.0 or sprite_width_radii <= 0.0:
		errors.append("explosive barrel geometry sizes must be positive")
	elif body_radius_radii > float(chamber_radius) + 0.25:
		errors.append("explosive barrel body_radius_radii must fit inside its generated chamber")
	if bounce_damping < 0.0 or bounce_damping > 1.0:
		errors.append("explosive barrel bounce_damping must be between zero and one")
	if ground_friction < 0.0:
		errors.append("explosive barrel ground_friction must not be negative")
	if support_contact_distance <= 0.0:
		errors.append("explosive barrel support_contact_distance must be positive")
	if rest_speed <= 0.0:
		errors.append("explosive barrel rest_speed must be positive")
	if rest_max_slope_degrees < 0.0 or rest_max_slope_degrees >= 90.0:
		errors.append("explosive barrel rest_max_slope_degrees must be at least zero and below 90")
	if push_velocity_ratio < 0.0 or max_push_speed < 0.0:
		errors.append("explosive barrel push tuning must not be negative")
	if hook_pull_acceleration < 0.0 or max_hook_pull_speed < 0.0:
		errors.append("explosive barrel hook pull tuning must not be negative")
	if (
		grounded_check_interval_seconds <= 0.0
		or offscreen_check_interval_seconds <= 0.0
		or stuck_check_interval_seconds <= 0.0
	):
		errors.append("explosive barrel terrain check intervals must be positive")
	if screen_margin_radii < 0.0:
		errors.append("explosive barrel screen_margin_radii must not be negative")
	return errors


func required_edge_clearance() -> int:
	return chamber_radius


## Skips anchors without solid ground below or with detonating terrain near the resting body.
func accepts_anchor(context: GenerationContext, anchor: Vector2i) -> bool:
	var world := context.world
	var anchor_hex := HexCoord.from_offset_odd_q(anchor.x, anchor.y)
	if requires_floor_support:
		# The body is wider than one hex, so it rests on the cell below and both lower neighbors.
		for floor_delta: HexCoord in [HexCoord.new(0, 1), HexCoord.new(-1, 1), HexCoord.new(1, 0)]:
			var floor_offset := anchor_hex.add(floor_delta).to_offset_odd_q()
			if not world.dimensions.is_in_bounds_offset(floor_offset.x, floor_offset.y):
				return false
			var floor_terrain := context.terrain_registry.get_definition(world.get_committed_by_offset(floor_offset.x, floor_offset.y))
			if floor_terrain == null or not floor_terrain.is_solid:
				return false
	if detonating_terrain_tags.is_empty():
		return true
	var radius := detonating_terrain_clearance
	for delta_q in range(-radius, radius + 1):
		for delta_r in range(maxi(-radius, -delta_q - radius), mini(radius, -delta_q + radius) + 1):
			var offset := anchor_hex.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q()
			if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
				continue
			var terrain := context.terrain_registry.get_definition(world.get_committed_by_offset(offset.x, offset.y))
			if terrain == null:
				continue
			for terrain_tag in detonating_terrain_tags:
				if terrain.perk_tags.has(terrain_tag):
					return false
	return true


## Carves Air at and above the anchor, preserving the generated floor below it.
func prepare_terrain(context: GenerationContext, anchor: Vector2i) -> bool:
	var air_id := context.terrain_registry.stable_id_for_name("Air")
	if air_id < 0:
		return false
	var anchor_hex := HexCoord.from_offset_odd_q(anchor.x, anchor.y)
	var anchor_y := anchor_hex.to_world_position(1.0).y
	for delta_q in range(-chamber_radius, chamber_radius + 1):
		var min_delta_r := maxi(-chamber_radius, -delta_q - chamber_radius)
		var max_delta_r := mini(chamber_radius, -delta_q + chamber_radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var cell_hex := anchor_hex.add(HexCoord.new(delta_q, delta_r))
			var offset := cell_hex.to_offset_odd_q()
			if cell_hex.to_world_position(1.0).y <= anchor_y + 0.0001:
				context.world.set_committed_by_offset(offset.x, offset.y, air_id)
	return true


func record_spawn(context: GenerationContext, anchor: Vector2i, spawn_seed: int) -> bool:
	context.explosive_barrel_spawns.append(GeneratedExplosiveBarrelSpawn.new(anchor, self, spawn_seed))
	return true
