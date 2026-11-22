## The look of every gameplay feedback moment: one effect recipe per moment plus the
## thresholds that decide whether and how strongly a moment shows.
class_name GameplayEffectLibrary
extends Resource


@export_group("Player")
## From the player's body position to its feet, where dust appears.
@export var player_feet_offset := Vector2(0.0, 24.0)
## From the player's body position to the point effects circle above its head.
@export var player_head_offset := Vector2(0.0, -34.0)
@export var jump_dust: EffectRecipe
@export var air_jump: EffectRecipe
@export var landing_dust: EffectRecipe
## Landings after less time in the air are footsteps over hex steps and show nothing.
@export_range(0.0, 2.0, 0.01) var landing_min_airborne_seconds := 0.22
@export_range(0.0, 2000.0, 1.0) var landing_min_speed := 160.0
@export_range(1.0, 4000.0, 1.0) var landing_full_speed := 700.0
@export var impact_flash: EffectRecipe
@export_range(0.0, 4000.0, 1.0) var impact_min_speed := 400.0
@export_range(1.0, 4000.0, 1.0) var impact_full_speed := 1000.0
@export var knockout_stars: EffectRecipe
@export var hook_launch: EffectRecipe
@export var hook_spark_terrain: EffectRecipe
@export var hook_spark_moving: EffectRecipe
@export var hook_miss: EffectRecipe
@export var hook_release: EffectRecipe
@export var hook_torn_off: EffectRecipe
@export var splash_enter: EffectRecipe
@export var splash_exit: EffectRecipe
@export_range(0.0, 2000.0, 1.0) var splash_min_speed := 60.0
@export_range(1.0, 4000.0, 1.0) var splash_full_speed := 600.0
@export var sand_burst_enter: EffectRecipe
@export var sand_burst_exit: EffectRecipe
@export var hazard_warning: EffectRecipe
## Effect played at every permanent death.
@export var death: EffectRecipe
## Extra effect by DeathCause value; causes without an entry only play death.
@export var death_by_cause: Dictionary[StringName, EffectRecipe] = {}

@export_group("Items")
@export var throw_whoosh: EffectRecipe
@export var tool_swing: EffectRecipe
@export var bounce_spark: EffectRecipe
@export_range(0.0, 2000.0, 1.0) var bounce_min_speed := 120.0
@export_range(1.0, 4000.0, 1.0) var bounce_full_speed := 700.0
## Effect by projectile resolution kind; kinds without an entry play projectile_end_default.
@export var projectile_end_by_kind: Dictionary[StringName, EffectRecipe] = {}
@export var projectile_end_default: EffectRecipe
@export var bottle_burst: EffectRecipe
@export var fuse_warning: EffectRecipe
## Effect by world object statistics key; keys without an entry play object_debris_default.
@export var object_debris_by_key: Dictionary[StringName, EffectRecipe] = {}
@export var object_debris_default: EffectRecipe
@export var barrel_bump: EffectRecipe
@export_range(0.0, 2000.0, 1.0) var barrel_bump_min_speed := 160.0
@export_range(1.0, 4000.0, 1.0) var barrel_bump_full_speed := 700.0
## Shortest time between two barrel bump effects, whatever barrel bumps.
@export_range(0.0, 2.0, 0.01) var barrel_bump_cooldown_seconds := 0.12
@export var excavator_deploy: EffectRecipe
@export var drill_debris: EffectRecipe
## Cells one drill tick digs at full effect strength.
@export_range(1, 16, 1) var drill_full_cell_count := 3

@export_group("Explosions")
## Played at a scale of the blast radius: its lengths are fractions of that radius.
@export var explosion: EffectRecipe
## Added on top for explosions with large feedback.
@export var explosion_large: EffectRecipe
## Peak camera offset in world px per world px of blast radius.
@export_range(0.0, 1.0, 0.001) var explosion_shake_per_radius := 0.11
@export_range(0.0, 64.0, 0.1) var explosion_shake_max := 24.0

@export_group("Flag and rewards")
@export var flag_planted: EffectRecipe
## Effect by the terrain tag that destroyed the flag; other tags play flag_destroyed_default.
@export var flag_destroyed_by_cause: Dictionary[StringName, EffectRecipe] = {}
@export var flag_destroyed_default: EffectRecipe
@export var victory: EffectRecipe
## Texture of the flag that stays planted where it landed.
@export var flag_marker_texture: Texture2D
@export_range(0.01, 4.0, 0.01) var flag_marker_scale := 0.45
## Texture pixel of the pole's foot, which stands on the ground.
@export var flag_marker_foot := Vector2(38.0, 125.0)
## From the landing position to the ground the foot stands on; world px.
@export var flag_marker_offset := Vector2(0.0, 10.0)
@export_range(0.0, 2.0, 0.01) var flag_marker_pop_seconds := 0.28
## Effect by reward container statistics key; other keys play container_open_default.
@export var container_open_by_key: Dictionary[StringName, EffectRecipe] = {}
@export var container_open_default: EffectRecipe
@export var reward_claimed_item: EffectRecipe
@export var reward_claimed_perk: EffectRecipe


## Recipe stored under key, or fallback when the dictionary has none.
static func keyed(recipes: Dictionary[StringName, EffectRecipe], key: StringName, fallback: EffectRecipe) -> EffectRecipe:
	var recipe: EffectRecipe = recipes.get(key)
	return recipe if recipe != null else fallback


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for property in get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var property_name: String = property["name"]
		var value: Variant = get(property_name)
		if property["type"] == TYPE_OBJECT and property["hint_string"] == "EffectRecipe":
			_validate_recipe(property_name, value as EffectRecipe, errors)
		elif value is Dictionary:
			for key: StringName in value:
				_validate_recipe("%s[%s]" % [property_name, key], value[key] as EffectRecipe, errors)
	if flag_marker_texture == null:
		errors.append("flag_marker_texture is required")
	return errors


func _validate_recipe(label: String, recipe: EffectRecipe, errors: PackedStringArray) -> void:
	if recipe == null:
		errors.append("%s is missing" % label)
		return
	for error in recipe.validate():
		errors.append("%s: %s" % [label, error])
