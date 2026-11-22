extends GutTest

const DeathCauseScript = preload("res://src/player/death_cause.gd")

const TUNING_PATH := "res://config/audio/audio_tuning.tres"
const FEEDBACK_KEYS: Array[StringName] = [
	&"small_bomb", &"large_bomb", &"flag", &"pickaxe", &"shovel", &"flare", &"fluid_bottle", &"excavator",
]
const DEATH_CAUSES: Array[StringName] = [
	DeathCauseScript.COOKED, DeathCauseScript.SUFFOCATION, DeathCauseScript.ACID, DeathCauseScript.POISON,
	DeathCauseScript.BOMB, DeathCauseScript.IMPACT, DeathCauseScript.BOUNDS,
]

var _now_msec := 0
var _played: Array[Array] = []
var _director: AudioDirector


func before_each() -> void:
	_now_msec = 5000
	_played = []
	_director = _new_director(load(TUNING_PATH) as AudioTuning)


func test_shipped_tuning_is_valid_and_covers_the_whole_sound_set() -> void:
	var tuning := load(TUNING_PATH) as AudioTuning
	var tuned := tuning.cue_by_id()

	assert_eq(tuning.validate(), PackedStringArray())
	for id in SfxRecipes.ids():
		assert_true(tuned.has(id), "%s has mix tuning" % id)
	assert_eq(tuned.size(), SfxRecipes.ids().size())


func test_tuning_validation_reports_broken_entries() -> void:
	var tuning := AudioTuning.new()
	var unknown := SfxCueTuning.new()
	unknown.id = &"no_such_sound"
	var duplicate := SfxCueTuning.new()
	duplicate.id = &"jump"
	tuning.cues = [unknown, duplicate, duplicate.duplicate(), null]
	tuning.default_death_cue = &"hook_miss"
	tuning.distance_far = tuning.distance_full

	var errors := "\n".join(tuning.validate())

	assert_string_contains(errors, "no_such_sound has no recipe")
	assert_string_contains(errors, "jump is tuned twice")
	assert_string_contains(errors, "empty cue")
	assert_string_contains(errors, "hook_miss is mapped but has no cue tuning")
	assert_string_contains(errors, "distance_far")


func test_main_scene_gives_the_director_its_tuning_and_the_bus_layout_exists() -> void:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	var director := app_root.get_node("AudioDirector") as AudioDirector

	assert_eq(director.tuning, load(TUNING_PATH))
	app_root.free()
	for bus: StringName in [AudioDirector.BUS_MUSIC, AudioDirector.BUS_SFX, AudioDirector.BUS_UI]:
		var index := AudioServer.get_bus_index(bus)
		assert_gt(index, 0, "%s bus exists" % bus)
		assert_eq(AudioServer.get_bus_send(index), AudioDirector.BUS_MASTER)


func test_running_over_hex_steps_never_plays_a_landing() -> void:
	for step in range(60):
		_director.play_land(40.0 + 3.0 * step, 0.03 + 0.002 * step)
		_now_msec += 120

	assert_eq(_played, [])


func test_landings_scale_from_soft_to_heavy_with_impact_speed() -> void:
	_director.play_land(60.0, 0.6)
	assert_eq(_played, [], "a feather landing is silent")

	_director.play_land(200.0, 0.4)
	_now_msec += 500
	_director.play_land(420.0, 0.6)
	_now_msec += 500
	_director.play_land(700.0, 1.0)
	_now_msec += 500
	_director.play_land(480.0, 0.05)

	assert_eq(_ids(), [&"land_soft", &"land_soft", &"land_heavy", &"land_heavy"])
	assert_lt(_played[0][1], _played[1][1], "a faster landing is louder")


func test_repeats_inside_the_cue_interval_are_dropped() -> void:
	var bomb := _item(&"small_bomb")
	_director.play_projectile_bounce(Vector2.ZERO, 600.0, bomb)
	_director.play_projectile_bounce(Vector2.ZERO, 600.0, bomb)
	_now_msec += 20
	_director.play_projectile_bounce(Vector2.ZERO, 600.0, bomb)
	assert_eq(_ids(), [&"bounce_metal"])

	_now_msec += 200
	_director.play_projectile_bounce(Vector2.ZERO, 600.0, bomb)

	assert_eq(_ids(), [&"bounce_metal", &"bounce_metal"])


func test_slow_bounces_and_barrel_bumps_are_silent_and_rolling_is_rate_limited() -> void:
	_director.play_projectile_bounce(Vector2.ZERO, 40.0, _item(&"flare"))
	_director.play_barrel_bump(Vector2.ZERO, 60.0)
	assert_eq(_played, [])

	for bump in range(30):
		_director.play_barrel_bump(Vector2.ZERO, 300.0)
		_now_msec += 16

	assert_between(_played.size(), 3, 5)


func test_a_pile_of_landing_body_parts_is_thinned_out_and_slow_ones_are_silent() -> void:
	_director.play_gib_impact(Vector2.ZERO, 60.0)
	assert_eq(_played, [], "A part that barely touches down makes no sound")

	# Sixteen parts landing over a third of a second.
	for part in range(16):
		_director.play_gib_impact(Vector2.ZERO, 500.0)
		_now_msec += 20

	assert_between(_played.size(), 3, 6)
	for id in _ids():
		assert_eq(id, &"gib_splat")
	_played.clear()
	_now_msec += 1000
	_director.play_gib_impact(Vector2.ZERO, 200.0)
	_now_msec += 1000
	_director.play_gib_impact(Vector2.ZERO, 900.0)
	assert_lt(float(_played[0][1]), float(_played[1][1]) - 3.0, "A harder landing is louder")


func test_polyphony_cap_holds_under_a_burst_and_ducks_the_crowd() -> void:
	var tuning := load(TUNING_PATH) as AudioTuning
	for id in SfxRecipes.ids():
		_director._play(id)
		_now_msec += 1

	assert_lte(_director.active_voice_count(AudioDirector.BUS_SFX), tuning.sfx_voice_count)
	assert_lte(_director.active_voice_count(AudioDirector.BUS_UI), tuning.ui_voice_count)
	assert_gt(_director.active_voice_count(AudioDirector.BUS_SFX), tuning.crowd_free_voices)

	_played = []
	_now_msec += 60
	_director.play_explosion(Vector2.ZERO, tuning.explosion_large_reference_radius, true)
	var crowded_db: float = _played[0][1]
	_now_msec += 10000
	_played = []
	_director.play_explosion(Vector2.ZERO, tuning.explosion_large_reference_radius, true)

	assert_lt(crowded_db, _played[0][1] - 3.0, "a sound entering a crowd is turned down")


func test_variation_is_bounded_and_repeatable_for_a_seed() -> void:
	var first := _jump_sequence(11)
	var second := _jump_sequence(11)
	var other := _jump_sequence(12)
	var cue: SfxCueTuning = (load(TUNING_PATH) as AudioTuning).cue_by_id()[&"jump"]

	assert_eq(first, second)
	assert_ne(first, other)
	assert_gt(cue.pitch_variation_semitones, 0.0)
	for entry in first:
		assert_between(entry[1], cue.volume_db - cue.volume_variation_db, cue.volume_db + cue.volume_variation_db)
		assert_between(
			entry[2],
			pow(2.0, -cue.pitch_variation_semitones / 12.0) - 0.0001,
			pow(2.0, cue.pitch_variation_semitones / 12.0) + 0.0001
		)
	assert_ne(first[0][2], first[1][2], "repeats do not sound identical")


func test_explosions_grow_lower_and_louder_with_radius() -> void:
	_director.set_variation_seed(1)
	_director.play_explosion(Vector2.ZERO, 80.0, false)
	_now_msec += 3000
	_director.set_variation_seed(1)
	_director.play_explosion(Vector2.ZERO, 160.0, false)
	_now_msec += 3000
	_director.set_variation_seed(1)
	_director.play_explosion(Vector2.ZERO, 160.0, true)

	assert_eq(_ids(), [&"explosion_small", &"explosion_small", &"explosion_large"])
	assert_gt(_played[1][1], _played[0][1])
	assert_lt(_played[1][2], _played[0][2])
	assert_gt(_played[2][1], _played[0][1], "the large blast is louder than the small one")


func test_hazard_warning_tightens_with_the_meter() -> void:
	_director.play_hazard_warning(DeathCauseScript.ACID, 0.62)
	_now_msec += 800
	_director.play_hazard_warning(DeathCauseScript.ACID, 0.8)
	_now_msec += 800
	_director.play_hazard_warning(DeathCauseScript.ACID, 0.95)

	assert_eq(_ids(), [&"hazard_warning", &"hazard_warning", &"hazard_critical"])
	assert_gt(_played[1][2], _played[0][2])
	assert_gt(_played[2][2], _played[1][2])
	assert_gt(_played[1][1], _played[0][1])


func test_distant_sounds_are_quieter_than_near_ones() -> void:
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()
	await wait_process_frames(1)
	var center := camera.get_screen_center_position()

	_director.play_bottle_burst(center)
	_now_msec += 1000
	_director.set_variation_seed(0)
	_director.play_bottle_burst(center + Vector2(1500.0, 0.0))
	_now_msec += 1000
	_director.play_bottle_burst(center + Vector2(90000.0, 0.0))

	assert_lt(_played[1][1], _played[0][1] - 3.0)
	assert_lt(_played[2][1], _played[1][1])
	assert_eq(_played.size(), 3, "far sounds stay audible")


func test_keyed_moments_choose_their_sound_from_resource_keys() -> void:
	var moments: Array[Callable] = [
		_director.play_throw.bind(_item(&"small_bomb")),
		_director.play_throw.bind(_item(&"large_bomb")),
		_director.play_throw.bind(_item(&"flag")),
		_director.play_throw.bind(_item(&"unknown_family")),
		_director.play_tool_use.bind(_item(&"pickaxe")),
		_director.play_tool_use.bind(_item(&"shovel")),
		_director.play_object_destroyed.bind(Vector2.ZERO, &"item_chest"),
		_director.play_object_destroyed.bind(Vector2.ZERO, &"perk_geode"),
		_director.play_object_destroyed.bind(Vector2.ZERO, &"explosive_barrel"),
		_director.play_container_open.bind(&"item_chest"),
		_director.play_container_open.bind(&"perk_geode"),
		_director.play_hook_release.bind(true),
		_director.play_hook_release.bind(false),
		_director.play_reward_claimed.bind(true),
		_director.play_reward_claimed.bind(false),
		_director.play_ui.bind(&"hover"),
		_director.play_ui.bind(&"press"),
		_director.play_use_refused.bind(ItemUseRefusal.EMPTY),
		_director.play_use_refused.bind(ItemUseRefusal.FLAG_IN_FLIGHT),
		_director.play_volume_preview.bind(AppSettingsData.VOLUME_SFX),
		_director.play_volume_preview.bind(AppSettingsData.VOLUME_MUSIC),
	]
	for moment in moments:
		moment.call()
		_now_msec += 1000

	assert_eq(_ids(), [
		&"throw_light", &"throw_heavy", &"throw_flag", &"throw_light", &"tool_pickaxe", &"tool_shovel",
		&"debris_wood", &"debris_crystal", &"debris_metal", &"chest_open", &"geode_open",
		&"hook_release", &"hook_snap", &"reward_perk", &"reward_item", &"ui_hover", &"ui_press",
		&"use_denied", &"use_denied", &"item_select",
	])


func test_refused_use_is_quiet_and_rate_limited() -> void:
	_director.play_use_refused(ItemUseRefusal.START_LOCK)
	_now_msec += 50
	_director.play_use_refused(ItemUseRefusal.START_LOCK)
	_director.play_use_refused(ItemUseRefusal.EMPTY)
	_now_msec += 400
	_director.play_use_refused(&"some_future_reason")

	assert_eq(_ids(), [&"use_denied", &"use_denied"] as Array[StringName], "A held or mashed button plays one sound.")
	var cues := (load(TUNING_PATH) as AudioTuning).cue_by_id()
	assert_eq(cues[&"use_denied"].bus, AudioDirector.BUS_UI)
	assert_lte(cues[&"use_denied"].volume_db, cues[&"ui_press"].volume_db, "Denied is no louder than a button press.")
	assert_gte(cues[&"use_denied"].min_interval_seconds, 0.15)


func test_each_death_cause_has_its_own_sting() -> void:
	var stings: Array[StringName] = []
	for cause in DEATH_CAUSES:
		_director.play_death(cause)
		_now_msec += 2000
	stings.assign(_ids())
	_director.play_death(&"unheard_of")

	for index in range(stings.size()):
		assert_eq(stings.count(stings[index]), 1, "%s has a distinct sting" % DEATH_CAUSES[index])
		assert_true(String(stings[index]).begins_with("death_"))
	assert_eq(_ids()[-1], &"death_fall")


func test_consciously_silent_moments_play_nothing() -> void:
	_director.play_flag_flight(false)
	_director.play_projectile_end(Vector2.ZERO, _item(&"fluid_bottle"), &"impact")
	_director.play_splash(10.0, true)
	_director.play_ui(&"unknown_kind")

	assert_eq(_played, [])

	_director.play_flag_flight(true)
	_director.play_projectile_end(Vector2.ZERO, _item(&"flare"), &"fuse")
	_now_msec += 500
	_director.play_projectile_end(Vector2.ZERO, _item(&"flare"), &"lava")

	assert_eq(_ids(), [&"flag_flight", &"flare_fizzle", &"item_sizzle"])


func test_every_moment_runs_with_the_shipped_tuning() -> void:
	_call_every_moment(_director)

	assert_gt(_played.size(), 40)
	for entry in _played:
		assert_true(SfxRecipes.has(entry[0]))
		assert_true(is_finite(entry[1]) and entry[1] <= 6.0, "%s volume is sane" % entry[0])
		assert_between(entry[2], 0.4, 2.5, "%s pitch is sane" % entry[0])


func test_every_moment_runs_without_a_tuning_resource() -> void:
	var director := _new_director(null)
	_played = []

	_call_every_moment(director)

	assert_gt(_played.size(), 20, "fixed moments still sound with neutral defaults")


func test_moments_before_the_director_is_ready_are_ignored() -> void:
	var director := AudioDirector.new()

	_call_every_moment(director)

	director.free()
	pass_test("no moment needs the scene tree")


func test_prewarm_renders_the_queue_in_budgeted_steps() -> void:
	var bank := _director.sound_bank()
	var queued: Array[StringName] = [&"ui_hover", &"ui_press", &"item_select"]
	bank.queue(queued)

	assert_true(_director.prewarm_step(0.0))
	assert_eq(bank.rendered_count(), 1)
	while _director.prewarm_step(0.0):
		pass

	assert_eq(bank.rendered_count(), 3)
	assert_eq(bank.pending_count(), 0)


func test_bus_volume_and_mute_reach_the_audio_server() -> void:
	var index := AudioServer.get_bus_index(AudioDirector.BUS_SFX)

	_director.set_bus_volume(AudioDirector.BUS_SFX, 0.5)
	_director.set_bus_muted(AudioDirector.BUS_SFX, true)

	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.001)
	assert_almost_eq(_director.bus_volume(AudioDirector.BUS_SFX), 0.5, 0.001)
	assert_true(_director.is_bus_muted(AudioDirector.BUS_SFX))
	assert_false(_director.is_bus_muted(AudioDirector.BUS_UI))

	_director.set_bus_volume(AudioDirector.BUS_SFX, 1.0)
	_director.set_bus_muted(AudioDirector.BUS_SFX, false)
	_director.set_bus_volume(&"NoSuchBus", 0.2)

	assert_almost_eq(AudioServer.get_bus_volume_db(index), 0.0, 0.001)
	assert_false(AudioServer.is_bus_mute(index))


func _new_director(tuning: AudioTuning) -> AudioDirector:
	var director := AudioDirector.new()
	director.tuning = tuning
	add_child_autofree(director)
	director.set_clock(func() -> int: return _now_msec)
	director.set_variation_seed(1)
	director.cue_played.connect(func(id: StringName, volume_db: float, pitch_scale: float) -> void:
		_played.append([id, volume_db, pitch_scale])
	)
	return director


func _item(feedback_key: StringName) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.feedback_key = feedback_key
	return definition


func _ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in _played:
		result.append(entry[0])
	return result


func _jump_sequence(variation_seed: int) -> Array[Array]:
	_played = []
	_director.set_variation_seed(variation_seed)
	for jump in range(6):
		_director.play_jump(false)
		_now_msec += 1000
	return _played.duplicate(true)


## Calls every play_* method with representative facts, spaced past every rate limit.
func _call_every_moment(director: AudioDirector) -> void:
	var here := Vector2(120.0, 340.0)
	var moments: Array[Callable] = [
		director.play_run_start,
		director.play_pause.bind(true),
		director.play_pause.bind(false),
		director.play_game_over,
		director.play_victory,
		director.play_ui_confirm,
		director.play_ui.bind(AppUiController.UI_FEEDBACK_HOVER),
		director.play_ui.bind(AppUiController.UI_FEEDBACK_PRESS),
		director.play_use_refused.bind(ItemUseRefusal.EMPTY),
		director.play_volume_preview.bind(AppSettingsData.VOLUME_SFX),
		director.play_jump.bind(false),
		director.play_jump.bind(true),
		director.play_land.bind(350.0, 0.5),
		director.play_land.bind(900.0, 1.2),
		director.play_hard_impact.bind(700.0),
		director.play_knockout.bind(700.0),
		director.play_hook_launch,
		director.play_hook_attach.bind(false),
		director.play_hook_attach.bind(true),
		director.play_hook_miss,
		director.play_hook_release.bind(true),
		director.play_hook_release.bind(false),
		director.play_splash.bind(300.0, true),
		director.play_splash.bind(300.0, false),
		director.play_gib_impact.bind(Vector2.ZERO, 500.0),
		director.play_sand_burrow.bind(true),
		director.play_sand_burrow.bind(false),
		director.play_hazard_warning.bind(DeathCauseScript.ACID, 0.7),
		director.play_hazard_warning.bind(DeathCauseScript.COOKED, 1.0),
		director.play_item_select.bind(null),
		director.play_throw.bind(null),
		director.play_tool_use.bind(null),
		director.play_projectile_bounce.bind(here, 500.0, null),
		director.play_projectile_end.bind(here, null, &"impact"),
		director.play_projectile_end.bind(here, null, &"fuse"),
		director.play_projectile_end.bind(here, null, &"lava"),
		director.play_bottle_burst.bind(here),
		director.play_explosion.bind(here, 80.0, false),
		director.play_explosion.bind(here, 400.0, true),
		director.play_explosion.bind(here, 0.0, false),
		director.play_fuse_armed.bind(here, 0.3),
		director.play_object_destroyed.bind(here, &"item_chest"),
		director.play_object_destroyed.bind(here, &"perk_geode"),
		director.play_object_destroyed.bind(here, &"explosive_barrel"),
		director.play_object_destroyed.bind(here, &"unknown_object"),
		director.play_barrel_bump.bind(here, 400.0),
		director.play_excavator_deploy.bind(here),
		director.play_excavator_drill.bind(here, 0),
		director.play_excavator_drill.bind(here, 3),
		director.play_terrain_pulse.bind(here, 1.6),
		director.play_terrain_pulse.bind(here, 0.0),
		director.play_flag_flight.bind(true),
		director.play_flag_flight.bind(false),
		director.play_flag_plant,
		director.play_flag_destroyed.bind(&"lava"),
		director.play_container_open.bind(&"item_chest"),
		director.play_container_open.bind(&"perk_geode"),
		director.play_reward_choices,
		director.play_reward_claimed.bind(true),
		director.play_reward_claimed.bind(false),
	]
	for cause in DEATH_CAUSES:
		moments.append(director.play_death.bind(cause))
	moments.append(director.play_death.bind(DeathCauseScript.NONE))
	for feedback_key in FEEDBACK_KEYS:
		var definition := _item(feedback_key)
		moments.append(director.play_throw.bind(definition))
		moments.append(director.play_tool_use.bind(definition))
		moments.append(director.play_item_select.bind(definition))
		moments.append(director.play_projectile_bounce.bind(here, 500.0, definition))
		moments.append(director.play_projectile_end.bind(here, definition, &"acid"))
	for moment in moments:
		moment.call()
		_now_msec += 3000
