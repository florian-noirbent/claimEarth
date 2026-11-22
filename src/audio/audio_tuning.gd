## Resource tuning for sound playback: the mix of every sound, which resource-declared
## key plays which sound, the raw-fact thresholds that decide whether a moment is audible,
## and the voice budget. The synthesis of each sound lives in SfxRecipes.
class_name AudioTuning
extends Resource


@export_group("Rendering")
## Sample rate every sound is rendered at.
@export_range(8000, 48000, 50) var mix_rate := 32000
## Sounds are rendered a few per frame at startup; this is the time spent per frame.
@export_range(0.5, 50.0, 0.5) var prewarm_budget_msec := 4.0

@export_group("Voices")
@export_range(1, 32, 1) var sfx_voice_count := 12
@export_range(1, 8, 1) var ui_voice_count := 3
## A new sound is turned down by this much for every voice already sounding beyond
## crowd_free_voices, so a pile-up cannot sum far past full scale.
@export_range(0.0, 6.0, 0.1) var crowd_duck_db_per_voice := 1.0
@export_range(0, 32, 1) var crowd_free_voices := 4
## Sounds that end up quieter than this are not played at all.
@export_range(-80.0, -20.0, 0.5) var silence_floor_db := -46.0

@export_group("Mix")
## Added to every sound: moves the whole set up or down without retuning each cue.
@export_range(-24.0, 12.0, 0.5) var set_gain_db := 0.0
@export var cues: Array[SfxCueTuning] = []

@export_group("Keyed sounds")
## AppUiController feedback kind to sound id.
@export var ui_cues: Dictionary[StringName, StringName] = {}
## ItemDefinition.feedback_key to sound id; an unknown key plays the default.
@export var throw_cues: Dictionary[StringName, StringName] = {}
@export var default_throw_cue: StringName
@export var tool_cues: Dictionary[StringName, StringName] = {}
@export var default_tool_cue: StringName
@export var bounce_cues: Dictionary[StringName, StringName] = {}
@export var default_bounce_cue: StringName
## Projectile resolution kind to sound id. An empty id keeps that kind silent; any other
## kind is a terrain tag that destroyed the projectile and plays the default.
@export var projectile_end_cues: Dictionary[StringName, StringName] = {}
@export var default_projectile_end_cue: StringName
## World object statistics_key to sound id.
@export var object_destroyed_cues: Dictionary[StringName, StringName] = {}
@export var default_object_destroyed_cue: StringName
@export var container_open_cues: Dictionary[StringName, StringName] = {}
@export var default_container_open_cue: StringName
## DeathCause value to sound id.
@export var death_cues: Dictionary[StringName, StringName] = {}
@export var default_death_cue: StringName

@export_group("Player")
## A landing after less air time than this is a running step and stays silent, unless
## it is faster than land_bypass_speed.
@export_range(0.0, 2.0, 0.01) var land_min_airborne_seconds := 0.2
@export_range(0.0, 2000.0, 1.0) var land_bypass_speed := 300.0
@export_range(0.0, 2000.0, 1.0) var land_min_speed := 120.0
## Landings at least this fast use the heavy thud.
@export_range(0.0, 2000.0, 1.0) var land_heavy_speed := 460.0
@export_range(0.0, 2000.0, 1.0) var land_full_speed := 520.0
@export_range(-40.0, 0.0, 0.5) var land_min_db := -12.0
@export_range(0.0, 3000.0, 1.0) var hard_impact_min_speed := 500.0
@export_range(0.0, 3000.0, 1.0) var hard_impact_full_speed := 1000.0
@export_range(-40.0, 0.0, 0.5) var hard_impact_min_db := -6.0
@export_range(0.0, 3000.0, 1.0) var splash_min_speed := 60.0
@export_range(0.0, 3000.0, 1.0) var splash_full_speed := 600.0
@export_range(-40.0, 0.0, 0.5) var splash_min_db := -12.0
## Meter fill at which the warning switches to the urgent double pulse.
@export_range(0.0, 1.0, 0.01) var hazard_critical_level := 0.85
## Meter fill at which the warning plays at its base pitch and quietest level.
@export_range(0.0, 0.99, 0.01) var hazard_base_level := 0.6
## Pitch rise in semitones between the base level and a full meter.
@export_range(0.0, 12.0, 0.1) var hazard_pitch_rise_semitones := 3.0
@export_range(-40.0, 0.0, 0.5) var hazard_min_db := -6.0

@export_group("Items")
## Bounces slower than this are silent.
@export_range(0.0, 3000.0, 1.0) var bounce_min_speed := 90.0
@export_range(0.0, 3000.0, 1.0) var bounce_full_speed := 700.0
@export_range(-40.0, 0.0, 0.5) var bounce_min_db := -14.0
@export_range(0.0, 3000.0, 1.0) var barrel_bump_min_speed := 140.0
@export_range(0.0, 3000.0, 1.0) var barrel_bump_full_speed := 700.0
@export_range(-40.0, 0.0, 0.5) var barrel_bump_min_db := -12.0
## Blast radius in world px at which each explosion sound plays unchanged.
@export_range(1.0, 2000.0, 1.0) var explosion_small_reference_radius := 80.0
@export_range(1.0, 2000.0, 1.0) var explosion_large_reference_radius := 160.0
## Pitch drop in semitones for every doubling of the blast radius.
@export_range(0.0, 12.0, 0.1) var explosion_pitch_semitones_per_doubling := 4.0
@export_range(0.0, 12.0, 0.1) var explosion_gain_db_per_doubling := 3.0
## Limit of the radius scaling, in doublings of the reference radius either way.
@export_range(0.0, 3.0, 0.05) var explosion_scale_limit := 1.0
## Extra level for each cell beyond the first that one excavator tick wears down.
@export_range(0.0, 6.0, 0.1) var excavator_extra_cell_db := 1.0
## Pulse duration at which the rumble plays unchanged; longer pulses play it slower.
@export_range(0.1, 10.0, 0.05) var terrain_pulse_reference_seconds := 1.5
@export_range(1.0, 2.0, 0.01) var terrain_pulse_max_pitch_ratio := 1.4

@export_group("Distance")
## Sounds with a world position play at full level within this distance of the screen
## centre and fade to distance_far_db at distance_far.
@export_range(0.0, 10000.0, 1.0) var distance_full := 520.0
@export_range(1.0, 20000.0, 1.0) var distance_far := 2400.0
@export_range(-60.0, 0.0, 0.5) var distance_far_db := -20.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var known: Dictionary[StringName, bool] = {}
	for cue in cues:
		if cue == null:
			errors.append("audio tuning contains an empty cue")
			continue
		errors.append_array(cue.validate())
		if known.has(cue.id):
			errors.append("sound cue %s is tuned twice" % cue.id)
		known[cue.id] = true
		if not SfxRecipes.has(cue.id):
			errors.append("sound cue %s has no recipe" % cue.id)
	for keyed: Dictionary in [
		ui_cues, throw_cues, tool_cues, bounce_cues, projectile_end_cues,
		object_destroyed_cues, container_open_cues, death_cues,
	]:
		for key: StringName in keyed:
			_require_known(keyed[key], known, errors)
	for default_cue: StringName in [
		default_throw_cue, default_tool_cue, default_bounce_cue, default_projectile_end_cue,
		default_object_destroyed_cue, default_container_open_cue, default_death_cue,
	]:
		_require_known(default_cue, known, errors)
	if distance_far <= distance_full:
		errors.append("audio distance_far must exceed distance_full")
	if land_full_speed <= land_min_speed or land_heavy_speed < land_min_speed:
		errors.append("audio landing speeds must rise from minimum to heavy and full")
	if hard_impact_full_speed <= hard_impact_min_speed:
		errors.append("audio hard impact full speed must exceed its minimum")
	if splash_full_speed <= splash_min_speed:
		errors.append("audio splash full speed must exceed its minimum")
	if bounce_full_speed <= bounce_min_speed:
		errors.append("audio bounce full speed must exceed its minimum")
	if barrel_bump_full_speed <= barrel_bump_min_speed:
		errors.append("audio barrel bump full speed must exceed its minimum")
	return errors


func cue_by_id() -> Dictionary[StringName, SfxCueTuning]:
	var result: Dictionary[StringName, SfxCueTuning] = {}
	for cue in cues:
		if cue != null:
			result[cue.id] = cue
	return result


func _require_known(cue_id: StringName, known: Dictionary[StringName, bool], errors: PackedStringArray) -> void:
	if cue_id != &"" and not known.has(cue_id):
		errors.append("sound %s is mapped but has no cue tuning" % cue_id)
