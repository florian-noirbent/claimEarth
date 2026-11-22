## Maps gameplay and UI events to audio playback without owning gameplay state.
## Each play_* method is one feedback moment routed by FeedbackRouter. Positions are world
## positions, speeds are px/s, radii are world px; this class decides how a moment sounds:
## which sound of the synthesized set plays, how loud, at what pitch, or not at all.
class_name AudioDirector
extends Node


## A sound started on a voice with this final volume and pitch.
signal cue_played(id: StringName, volume_db: float, pitch_scale: float)

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const _NO_POSITION := Vector2(INF, INF)

## Mix, thresholds, and keyed sound choices. Without one, neutral defaults apply and
## keyed moments stay silent.
@export var tuning: AudioTuning

var _tuning := AudioTuning.new()
var _cues: Dictionary[StringName, SfxCueTuning] = {}
var _bank: SfxBank
var _pools: Dictionary[StringName, SfxVoicePool] = {}
var _last_played_msec: Dictionary[StringName, int] = {}
var _random := RandomNumberGenerator.new()
var _clock: Callable = Time.get_ticks_msec


func _ready() -> void:
	_tuning = tuning if tuning != null else AudioTuning.new()
	var errors := _tuning.validate()
	if not errors.is_empty():
		push_error("\n".join(errors))
	_cues = _tuning.cue_by_id()
	_bank = SfxBank.new(_tuning.mix_rate)
	_add_pool(BUS_SFX, _tuning.sfx_voice_count)
	_add_pool(BUS_UI, _tuning.ui_voice_count)
	## Without an audio device nothing is audible, so sounds render on first use only.
	var queued: Array[StringName] = []
	if AudioServer.get_driver_name() != "Dummy":
		queued.assign(_cues.keys())
	_bank.queue(queued)
	set_process(_bank.pending_count() > 0)


func _process(_delta: float) -> void:
	set_process(_bank.prewarm_step(_tuning.prewarm_budget_msec))


# --- Volume and determinism ---

## Sets the volume of a bus (BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI) from 0 to 1.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0001, 1.0)))


func bus_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(index)) if index >= 0 else 0.0


func set_bus_muted(bus: StringName, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, muted)


func is_bus_muted(bus: StringName) -> bool:
	var index := AudioServer.get_bus_index(bus)
	return index >= 0 and AudioServer.is_bus_mute(index)


## Makes the per-play pitch and volume variation repeatable.
func set_variation_seed(variation_seed: int) -> void:
	_random.seed = variation_seed


## Replaces the millisecond clock behind rate limits and voice lifetimes.
func set_clock(clock: Callable) -> void:
	_clock = clock
	for bus: StringName in _pools:
		var pool := _pools[bus]
		pool.configure(bus, pool.voice_count(), clock)


## Renders queued sounds for up to budget_msec; returns true while more remain.
func prewarm_step(budget_msec: float) -> bool:
	return _bank.prewarm_step(budget_msec)


func sound_bank() -> SfxBank:
	return _bank


func active_voice_count(bus: StringName = BUS_SFX) -> int:
	var pool: SfxVoicePool = _pools.get(bus)
	return pool.active_count() if pool != null else 0


# --- Run flow and UI ---

## Gameplay of a new run became playable.
func play_run_start() -> void:
	_play(&"run_start")


## The run was paused (true) or resumed (false).
func play_pause(is_paused: bool) -> void:
	_play(&"pause" if is_paused else &"resume")


## The run ended without a claim: the player died or the flag was destroyed.
func play_game_over() -> void:
	_play(&"game_over")


## The planted flag reached the victory depth; follows play_flag_plant in the same frame.
func play_victory() -> void:
	_play(&"victory")


## The player confirmed the name entry and the score was accepted.
func play_ui_confirm() -> void:
	_play(&"ui_confirm")


## A UI button moment. kind is AppUiController.UI_FEEDBACK_HOVER or UI_FEEDBACK_PRESS.
func play_ui(kind: StringName) -> void:
	_play(_tuning.ui_cues.get(kind, &""))


## The player settled a volume slider; channel is an AppSettingsData.VOLUME_* value.
func play_volume_preview(channel: StringName) -> void:
	_play(_tuning.volume_preview_cues.get(channel, &""))


# --- Player ---

## The player started a jump; is_air_jump is true when it spent an extra air jump.
func play_jump(is_air_jump: bool) -> void:
	_play(&"air_jump" if is_air_jump else &"jump")


## The player touched ground after being airborne, or bounced off it. impact_speed is the
## downward speed lost on the floor; airborne_seconds is the time since the last ground
## contact. Running over hex steps also lands, after well under 0.2 s in the air.
func play_land(impact_speed: float, airborne_seconds: float) -> void:
	if airborne_seconds < _tuning.land_min_airborne_seconds and impact_speed < _tuning.land_bypass_speed:
		return
	if impact_speed < _tuning.land_min_speed:
		return
	var gain_db := _scaled_db(impact_speed, _tuning.land_min_speed, _tuning.land_full_speed, _tuning.land_min_db)
	_play(&"land_heavy" if impact_speed >= _tuning.land_heavy_speed else &"land_soft", gain_db)


## A terrain collision fast enough to fill the impact hazard meter; impact_speed is the
## velocity change. Knockout and impact death add their own moment in the same frame.
func play_hard_impact(impact_speed: float) -> void:
	_play(&"hard_impact", _scaled_db(
		impact_speed, _tuning.hard_impact_min_speed, _tuning.hard_impact_full_speed, _tuning.hard_impact_min_db
	))


## A terrain impact knocked the player out into a ragdoll.
func play_knockout(_impact_speed: float) -> void:
	_play(&"knockout")


## The hook was fired; attach or miss follows in the same frame.
func play_hook_launch() -> void:
	_play(&"hook_launch")


## The hook caught terrain (false) or a moving target such as a barrel (true).
func play_hook_attach(is_moving_target: bool) -> void:
	_play(&"hook_attach_moving" if is_moving_target else &"hook_attach")


## The fired hook found nothing in range.
func play_hook_miss() -> void:
	_play(&"hook_miss")


## The rope let go: by_input is true when the player released it, false when the anchor
## was destroyed or an impact tore it off.
func play_hook_release(by_input: bool) -> void:
	_play(&"hook_release" if by_input else &"hook_snap")


## The player's body entered (true) or left (false) liquid at this body speed.
func play_splash(speed: float, is_entering: bool) -> void:
	if speed < _tuning.splash_min_speed:
		return
	var gain_db := _scaled_db(speed, _tuning.splash_min_speed, _tuning.splash_full_speed, _tuning.splash_min_db)
	_play(&"splash_in" if is_entering else &"splash_out", gain_db)


## A Sand Worm player started (true) or stopped (false) burrowing through sand.
func play_sand_burrow(is_burrowing: bool) -> void:
	_play(&"sand_burrow_in" if is_burrowing else &"sand_burrow_out")


## A hazard meter keeps filling above the warning level; repeats at a fixed interval while
## it does. cause is a DeathCause value and level is the meter fill from 0 to 1.
func play_hazard_warning(_cause: StringName, level: float) -> void:
	var urgency := clampf(inverse_lerp(_tuning.hazard_base_level, 1.0, level), 0.0, 1.0)
	_play(
		&"hazard_critical" if level >= _tuning.hazard_critical_level else &"hazard_warning",
		lerpf(_tuning.hazard_min_db, 0.0, urgency),
		_semitones(_tuning.hazard_pitch_rise_semitones * urgency)
	)


## The player died for good; cause is a DeathCause value.
func play_death(cause: StringName) -> void:
	_play(_tuning.death_cues.get(cause, _tuning.default_death_cue))


# --- Items and world objects ---

## The player threw a projectile item; item.feedback_key names its family.
func play_throw(item: ItemDefinition) -> void:
	_play(_tuning.throw_cues.get(_feedback_key(item), _tuning.default_throw_cue))


## The player used an in-place tool such as the pickaxe or shovel and it changed terrain.
func play_tool_use(item: ItemDefinition) -> void:
	_play(_tuning.tool_cues.get(_feedback_key(item), _tuning.default_tool_cue))


## The player selected another item.
func play_item_select(_item: ItemDefinition) -> void:
	_play(&"item_select")


## A use or throw of the selected item was refused; reason is an ItemUseRefusal value.
## Arrives once per press, and the cue's minimum interval absorbs rapid presses.
func play_use_refused(reason: StringName) -> void:
	_play(_tuning.use_refused_cues.get(reason, _tuning.default_use_refused_cue))


## A thrown item bounced off terrain; impact_speed is its speed before the bounce.
func play_projectile_bounce(world_position: Vector2, impact_speed: float, item: ItemDefinition) -> void:
	if impact_speed < _tuning.bounce_min_speed:
		return
	_play(
		_tuning.bounce_cues.get(_feedback_key(item), _tuning.default_bounce_cue),
		_scaled_db(impact_speed, _tuning.bounce_min_speed, _tuning.bounce_full_speed, _tuning.bounce_min_db),
		1.0,
		world_position
	)


## A thrown item without an explosive ended. resolution_kind is &"impact", &"fuse" (timed
## out, such as a flare burning out) or the terrain tag that destroyed it, such as &"lava".
func play_projectile_end(world_position: Vector2, _item: ItemDefinition, resolution_kind: StringName) -> void:
	_play(
		_tuning.projectile_end_cues.get(resolution_kind, _tuning.default_projectile_end_cue),
		0.0, 1.0, world_position
	)


## A fluid bottle broke and released its fluid.
func play_bottle_burst(world_position: Vector2) -> void:
	_play(&"bottle_burst", 0.0, 1.0, world_position)


## An explosion resolved; radius_world is its blast radius.
func play_explosion(world_position: Vector2, radius_world: float, is_large: bool) -> void:
	var reference := _tuning.explosion_large_reference_radius if is_large else _tuning.explosion_small_reference_radius
	var limit := _tuning.explosion_scale_limit
	var doublings := clampf(log(maxf(1.0, radius_world) / reference) / log(2.0), -limit, limit)
	_play(
		&"explosion_large" if is_large else &"explosion_small",
		_tuning.explosion_gain_db_per_doubling * doublings,
		_semitones(-_tuning.explosion_pitch_semitones_per_doubling * doublings),
		world_position
	)


## A blast lit the chain fuse of a barrel, container, or lying bomb that explodes after
## fuse_seconds.
func play_fuse_armed(world_position: Vector2, _fuse_seconds: float) -> void:
	_play(&"fuse_armed", 0.0, 1.0, world_position)


## An explosion destroyed a world object; object_key is its definition's statistics_key
## (&"item_chest", &"perk_geode", &"explosive_barrel"). play_explosion follows.
func play_object_destroyed(world_position: Vector2, object_key: StringName) -> void:
	_play(
		_tuning.object_destroyed_cues.get(object_key, _tuning.default_object_destroyed_cue),
		0.0, 1.0, world_position
	)


## A rolling or falling barrel rebounded off terrain; impact_speed is the velocity change.
func play_barrel_bump(world_position: Vector2, impact_speed: float) -> void:
	if impact_speed < _tuning.barrel_bump_min_speed:
		return
	_play(
		&"barrel_bump",
		_scaled_db(impact_speed, _tuning.barrel_bump_min_speed, _tuning.barrel_bump_full_speed, _tuning.barrel_bump_min_db),
		1.0,
		world_position
	)


## A thrown excavator landed and started working.
func play_excavator_deploy(world_position: Vector2) -> void:
	_play(&"excavator_deploy", 0.0, 1.0, world_position)


## One excavator drill tick; dug_cell_count is how many cells it wore down (0 to 3).
func play_excavator_drill(world_position: Vector2, dug_cell_count: int) -> void:
	if dug_cell_count <= 0:
		_play(&"excavator_idle", 0.0, 1.0, world_position)
		return
	_play(&"excavator_drill", _tuning.excavator_extra_cell_db * (dug_cell_count - 1), 1.0, world_position)


## A destroyed container started a directional terrain pulse lasting duration_seconds.
func play_terrain_pulse(world_position: Vector2, duration_seconds: float) -> void:
	var max_ratio := _tuning.terrain_pulse_max_pitch_ratio
	var pitch := clampf(
		_tuning.terrain_pulse_reference_seconds / maxf(0.05, duration_seconds), 1.0 / max_ratio, max_ratio
	)
	_play(&"terrain_pulse", 0.0, pitch, world_position)


## The flag left the player's hand (true) or its flight ended (false). A false also
## arrives once when a run is configured. Only the launch sounds: the end of a flight is
## voiced by the plant, destruction, or death moment that ends it.
func play_flag_flight(in_flight: bool) -> void:
	if in_flight:
		_play(&"flag_flight")


## The flag landed and claimed its depth.
func play_flag_plant() -> void:
	_play(&"flag_plant")


## Terrain destroyed the flying flag; cause is the terrain tag, such as &"lava" or &"acid".
func play_flag_destroyed(_cause: StringName) -> void:
	_play(&"flag_destroyed")


## The player touched a reward container and it opened; container_key is its definition's
## statistics_key (&"item_chest" or &"perk_geode").
func play_container_open(container_key: StringName) -> void:
	_play(_tuning.container_open_cues.get(container_key, _tuning.default_container_open_cue))


## The reward picker appeared.
func play_reward_choices() -> void:
	_play(&"reward_choices")


## The player picked a reward: a perk (true) or an item added to the inventory (false).
func play_reward_claimed(is_perk: bool) -> void:
	_play(&"reward_perk" if is_perk else &"reward_item")


# --- Playback ---

## Plays one sound of the set. gain_db and pitch_scale are the moment's own scaling on
## top of the cue tuning; a finite world_position adds distance attenuation.
func _play(id: StringName, gain_db: float = 0.0, pitch_scale: float = 1.0, world_position: Vector2 = _NO_POSITION) -> void:
	if id == &"" or _bank == null:
		return
	var cue := _cue_for(id)
	var now: int = _clock.call()
	if _last_played_msec.has(id) and now - _last_played_msec[id] < int(cue.min_interval_seconds * 1000.0):
		return
	var pool: SfxVoicePool = _pools.get(cue.bus, _pools[BUS_SFX])
	var crowd := maxi(0, pool.active_count() - _tuning.crowd_free_voices)
	var volume_db := cue.volume_db + _tuning.set_gain_db + gain_db + _distance_db(world_position) \
		- _tuning.crowd_duck_db_per_voice * crowd \
		+ _random.randf_range(-cue.volume_variation_db, cue.volume_variation_db)
	if volume_db < _tuning.silence_floor_db:
		return
	var pitch := pitch_scale * _semitones(
		_random.randf_range(-cue.pitch_variation_semitones, cue.pitch_variation_semitones)
	)
	if not pool.play(_bank.stream(id), volume_db, pitch, cue.priority):
		return
	_last_played_msec[id] = now
	cue_played.emit(id, volume_db, pitch)


func _cue_for(id: StringName) -> SfxCueTuning:
	var cue: SfxCueTuning = _cues.get(id)
	if cue == null:
		cue = SfxCueTuning.new()
		cue.id = id
		_cues[id] = cue
	return cue


func _add_pool(bus: StringName, voice_count: int) -> void:
	var pool := SfxVoicePool.new()
	pool.name = "%sVoices" % bus
	add_child(pool)
	pool.configure(bus, voice_count, _clock)
	_pools[bus] = pool


## Level change for a sound at world_position, heard from the centre of the screen.
func _distance_db(world_position: Vector2) -> float:
	if not world_position.is_finite() or not is_inside_tree():
		return 0.0
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return 0.0
	var distance := camera.get_screen_center_position().distance_to(world_position)
	var far := clampf(inverse_lerp(_tuning.distance_full, _tuning.distance_far, distance), 0.0, 1.0)
	return _tuning.distance_far_db * far


## Maps value between min_value and full_value to a level between min_db and 0 dB.
func _scaled_db(value: float, min_value: float, full_value: float, min_db: float) -> float:
	return lerpf(min_db, 0.0, clampf(inverse_lerp(min_value, full_value, value), 0.0, 1.0))


func _semitones(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)


func _feedback_key(item: ItemDefinition) -> StringName:
	return item.feedback_key if item != null else &""
