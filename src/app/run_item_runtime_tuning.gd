## Typed item-runtime policy compiled once when selected perks change.
class_name RunItemRuntimeTuning
extends RefCounted


var small_bomb_preserve_chance := 0.0
var large_bomb_preserve_chance := 0.0
var shovel_pickaxe_preserve_chance := 0.0
var excavator_tick_interval_multiplier := 1.0
var excavator_chest_weight_multiplier := 1.0

var player_explosion_impulse_enabled := false
var player_kill_radius_add := 0
var sand_liquid_vaporize_radius_add := 0
var small_bomb_blast_radius_add := 0
var large_bomb_blast_radius_add := 0
var large_bomb_vaporize_radius_add := 0
var large_bomb_player_kill_radius_add := 0
var small_bomb_emits_sulfur_dioxide := false
var large_bomb_emits_sulfur_dioxide := false

var reward_choice_count_add := 0
var container_indestructible := false
var item_chest_light_add := 0
var flag_survives_hazards := false
var dirt_vaporize_chance := 0.0


static func compile(modifiers: PerkModifierSnapshot) -> RunItemRuntimeTuning:
	var tuning := RunItemRuntimeTuning.new()
	if modifiers == null:
		return tuning

	var items := modifiers.items
	tuning.small_bomb_preserve_chance = float(items.value("small_bomb_preserve_chance", 0.0))
	tuning.large_bomb_preserve_chance = float(items.value("large_bomb_preserve_chance", 0.0))
	tuning.shovel_pickaxe_preserve_chance = float(items.value("shovel_pickaxe_preserve_chance", 0.0))
	tuning.excavator_tick_interval_multiplier = float(items.value("excavator_tick_interval_multiplier", 1.0))
	tuning.excavator_chest_weight_multiplier = float(items.value("excavator_chest_weight_multiplier", 1.0))

	var explosions := modifiers.explosions
	tuning.player_explosion_impulse_enabled = bool(explosions.value("player_explosion_impulse_enabled", false))
	tuning.player_kill_radius_add = int(explosions.value("player_kill_radius_add", 0))
	tuning.sand_liquid_vaporize_radius_add = int(explosions.value("sand_liquid_vaporize_radius_add", 0))
	tuning.small_bomb_blast_radius_add = int(explosions.value("small_bomb_blast_radius_add", 0))
	tuning.large_bomb_blast_radius_add = int(explosions.value("large_bomb_blast_radius_add", 0))
	tuning.large_bomb_vaporize_radius_add = int(explosions.value("large_bomb_vaporize_radius_add", 0))
	tuning.large_bomb_player_kill_radius_add = int(explosions.value("large_bomb_player_kill_radius_add", 0))
	tuning.small_bomb_emits_sulfur_dioxide = bool(explosions.value("small_bomb_emits_sulfur_dioxide", false))
	tuning.large_bomb_emits_sulfur_dioxide = bool(explosions.value("large_bomb_emits_sulfur_dioxide", false))

	tuning.reward_choice_count_add = int(modifiers.rewards.value("choice_count_add", 0))
	tuning.container_indestructible = bool(modifiers.containers.value("indestructible", false))
	tuning.item_chest_light_add = int(modifiers.containers.value("light_level_add", 0))
	tuning.flag_survives_hazards = bool(
		modifiers.flags.value("survive_lava_acid_and_drop_on_death", false)
	)
	tuning.dirt_vaporize_chance = float(modifiers.terrain.value("dirt_vaporize_chance", 0.0))
	return tuning


func preserve_chance_for(definition: ItemDefinition) -> float:
	if definition == null:
		return 0.0
	if definition.perk_tags.has("small_bomb"):
		return small_bomb_preserve_chance
	if definition.perk_tags.has("large_bomb"):
		return large_bomb_preserve_chance
	if definition.perk_tags.has("shovel") or definition.perk_tags.has("pickaxe"):
		return shovel_pickaxe_preserve_chance
	return 0.0


func reward_choice_count(base_count: int) -> int:
	return clampi(base_count + reward_choice_count_add, 1, 3)


func tool_dirt_vaporize_chance() -> float:
	return clampf(dirt_vaporize_chance, 0.0, 1.0)


func apply_to_explosion(spec: ExplosionRuntimeSpec, source_item: ItemDefinition = null) -> void:
	if spec == null:
		return
	spec.player_kill_radius = maxi(0, spec.player_kill_radius + player_kill_radius_add)
	if source_item != null and source_item.perk_tags.has("small_bomb"):
		spec.blast_radius += small_bomb_blast_radius_add
		if small_bomb_emits_sulfur_dioxide and spec.definition != null and spec.definition.perk_terrain_emission != null:
			spec.perk_terrain_emissions.append(spec.definition.perk_terrain_emission)
	if source_item != null and source_item.perk_tags.has("large_bomb"):
		spec.blast_radius += large_bomb_blast_radius_add
		spec.vaporize_radius += large_bomb_vaporize_radius_add
		spec.player_kill_radius += large_bomb_player_kill_radius_add
		if large_bomb_emits_sulfur_dioxide and spec.definition != null and spec.definition.perk_terrain_emission != null:
			## Large Boom deliberately emits two full clouds.
			spec.perk_terrain_emissions.append(spec.definition.perk_terrain_emission)
			spec.perk_terrain_emissions.append(spec.definition.perk_terrain_emission)
	spec.vaporize_radius = clampi(spec.vaporize_radius, 0, spec.blast_radius)
	spec.player_kill_radius = clampi(spec.player_kill_radius, 0, spec.blast_radius)
	if sand_liquid_vaporize_radius_add > 0:
		var terrain_bonus := sand_liquid_vaporize_radius_add
		spec.fluid_vaporize_radius_bonus = func(definition: TerrainDefinition) -> int:
			return terrain_bonus if definition != null and (
				definition.perk_tags.has("sand") or definition.perk_tags.has("liquid")
			) else 0
	if dirt_vaporize_chance > 0.0 and source_item != null and (
		source_item.perk_tags.has("small_bomb") or source_item.perk_tags.has("large_bomb")
	):
		var blast_chance := dirt_vaporize_chance
		spec.blast_vaporize_chance = func(terrain: TerrainDefinition, _cell: Vector2i) -> float:
			return blast_chance if terrain != null and terrain.perk_tags.has("dirt") else 0.0
