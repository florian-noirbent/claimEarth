## Typed player runtime policy compiled from authored configs and perk modifiers.
class_name PlayerRuntimeTuning
extends RefCounted


const IMPACT_MODE_HARD_SKIN := 1
const IMPACT_MODE_JELLY := 2
const IMPACT_MODE_GLASS := 3

var movement: PlayerMovementConfig
var grapple: GrappleConfig
var free_air_control_disabled := false
var liquid_gravity_cancelled := false
var liquid_drag_disabled := false
var liquid_buoyancy_multiplier := 1.0
var hard_surface_restitution := 0.0
var bounce_settle_speed := 0.0
var sand_passable := false
var sand_breathable := false
var all_hazards_immune := false
var lava_duration_seconds_add := 0.0
var suffocation_duration_seconds_add := 0.0


static func compile(
	base_movement: PlayerMovementConfig,
	base_grapple: GrappleConfig,
	modifiers: PerkModifierSnapshot
) -> PlayerRuntimeTuning:
	var tuning := PlayerRuntimeTuning.new()
	if base_movement == null or base_grapple == null:
		return tuning

	tuning.movement = base_movement.duplicate() as PlayerMovementConfig
	tuning.grapple = base_grapple.duplicate() as GrappleConfig
	if modifiers == null:
		return tuning

	var player_domain := modifiers.player
	tuning.movement.gravity *= maxf(
		0.0,
		1.0 + float(player_domain.value("gravity_multiplier_delta", 0.0))
	)
	var speed_multiplier := maxf(
		0.0,
		float(player_domain.value("movement_speed_multiplier", 1.0))
	)
	tuning.movement.max_ground_speed *= speed_multiplier
	tuning.movement.max_air_speed *= speed_multiplier
	tuning.movement.ground_friction *= float(
		player_domain.value("ground_friction_multiplier", 1.0)
	)
	tuning.movement.extra_air_jumps += int(
		player_domain.value("extra_air_jumps_add", 0)
	)
	tuning.grapple.max_rope_length *= maxf(
		0.0,
		1.0 + float(player_domain.value("rope_length_multiplier_delta", 0.0))
	)
	tuning.free_air_control_disabled = bool(
		player_domain.value("free_air_control_disabled", false)
	)
	tuning.liquid_gravity_cancelled = bool(
		player_domain.value("liquid_gravity_cancelled", false)
	)
	tuning.liquid_drag_disabled = bool(
		player_domain.value("liquid_drag_disabled", false)
	)
	tuning.liquid_buoyancy_multiplier = maxf(
		1.0,
		float(player_domain.value("liquid_buoyancy_multiplier", 1.0))
	)
	tuning.hard_surface_restitution = clampf(
		float(player_domain.value("hard_surface_restitution", 0.0)),
		0.0,
		1.0
	)
	tuning.bounce_settle_speed = maxf(
		0.0,
		float(player_domain.value("bounce_settle_speed", 0.0))
	)
	tuning._apply_impact_modifiers(base_movement, player_domain)

	tuning.sand_passable = bool(
		modifiers.terrain.value("player_sand_passable", false)
	)
	tuning.sand_breathable = bool(
		modifiers.hazards.value("sand_breathable", false)
	)
	tuning.all_hazards_immune = bool(
		modifiers.hazards.value("all_hazards_immune", false)
	)
	tuning.lava_duration_seconds_add = float(
		modifiers.hazards.value("lava_duration_seconds_add", 0.0)
	)
	tuning.suffocation_duration_seconds_add = float(
		modifiers.hazards.value("suffocation_duration_seconds_add", 0.0)
	)
	return tuning


func _apply_impact_modifiers(
	base_movement: PlayerMovementConfig,
	player_domain: PerkModifierSnapshot.PerkModifierDomain
) -> void:
	var impact_mode := int(player_domain.value("impact_mode", 0))
	if bool(player_domain.value("impact_disabled", false)):
		movement.impact_hazard_minimum_speed = INF
	elif bool(player_domain.value("impact_death_disabled", false)):
		var threshold_add := float(player_domain.value("impact_threshold_add", 0.0))
		movement.impact_hazard_minimum_speed += threshold_add
		movement.medium_impact_speed += threshold_add
		movement.lethal_impact_speed += threshold_add
	elif impact_mode == IMPACT_MODE_HARD_SKIN:
		movement.impact_hazard_minimum_speed = base_movement.medium_impact_speed
		movement.medium_impact_speed = base_movement.lethal_impact_speed
		movement.lethal_impact_speed = maxf(
			base_movement.lethal_impact_speed + 1.0,
			base_movement.lethal_impact_speed
				+ (base_movement.lethal_impact_speed - base_movement.medium_impact_speed)
		)
	elif impact_mode == IMPACT_MODE_JELLY:
		movement.impact_hazard_minimum_speed = INF
	elif impact_mode == IMPACT_MODE_GLASS:
		movement.impact_hazard_minimum_speed = base_movement.impact_hazard_minimum_speed
		movement.medium_impact_speed = base_movement.medium_impact_speed
		movement.lethal_impact_speed = base_movement.medium_impact_speed
