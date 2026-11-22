## The synthesized sound set: one recipe per sound id, built on AudioSynth. A recipe is a
## pure function of the mix rate, so every render of an id is identical. Loudness and
## per-play variation live in AudioTuning; AudioDirector decides which moment plays which id.
class_name SfxRecipes
extends RefCounted


const S = preload("res://src/audio/audio_synth.gd")

const SINE := S.Wave.SINE
const TRIANGLE := S.Wave.TRIANGLE
const SQUARE := S.Wave.SQUARE
const SAW := S.Wave.SAW
const LOW := S.Filter.LOW_PASS
const HIGH := S.Filter.HIGH_PASS
const BAND := S.Filter.BAND_PASS

## Every recipe leaves this much headroom below full scale.
const RENDER_PEAK := 0.89

static var _recipes: Dictionary[StringName, Callable] = {}


## Every sound id this set can render, in a stable order.
static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_table().keys())
	return result


static func has(id: StringName) -> bool:
	return _table().has(id)


## Renders one sound as mono samples at mix_rate. Unknown ids render as empty.
static func render(id: StringName, mix_rate: int) -> PackedFloat32Array:
	var recipe: Callable = _table().get(id, Callable())
	if not recipe.is_valid():
		return PackedFloat32Array()
	return recipe.call(mix_rate)


static func _table() -> Dictionary[StringName, Callable]:
	if not _recipes.is_empty():
		return _recipes
	_recipes = {
		&"ui_hover": _ui_hover,
		&"ui_press": _ui_press,
		&"ui_confirm": _ui_confirm,
		&"pause": _pause.bind(true),
		&"resume": _pause.bind(false),
		&"item_select": _item_select,
		&"run_start": _run_start,
		&"game_over": _game_over,
		&"victory": _victory,
		&"jump": _jump.bind(false),
		&"air_jump": _jump.bind(true),
		&"land_soft": _land.bind(false),
		&"land_heavy": _land.bind(true),
		&"hard_impact": _hard_impact,
		&"knockout": _knockout,
		&"hook_launch": _hook_launch,
		&"hook_attach": _hook_attach,
		&"hook_attach_moving": _hook_attach_moving,
		&"hook_miss": _hook_miss,
		&"hook_release": _hook_release,
		&"hook_snap": _hook_snap,
		&"splash_in": _splash_in,
		&"splash_out": _splash_out,
		&"sand_burrow_in": _sand_burrow.bind(true),
		&"sand_burrow_out": _sand_burrow.bind(false),
		&"hazard_warning": _hazard_warning.bind(false),
		&"hazard_critical": _hazard_warning.bind(true),
		&"death_cooked": _death_cooked,
		&"death_suffocation": _death_suffocation,
		&"death_acid": _death_acid,
		&"death_poison": _death_poison,
		&"death_bomb": _death_bomb,
		&"death_impact": _death_impact,
		&"death_fall": _death_fall,
		&"throw_light": _throw.bind(0.17, 800.0, 2600.0, 21),
		&"throw_heavy": _throw.bind(0.27, 320.0, 1150.0, 22),
		&"throw_flag": _throw_flag,
		&"tool_pickaxe": _tool_pickaxe,
		&"tool_shovel": _tool_shovel,
		&"bounce_metal": _bounce_metal,
		&"bounce_glass": _bounce_glass,
		&"bounce_wood": _bounce_wood,
		&"flare_fizzle": _flare_fizzle,
		&"item_sizzle": _item_sizzle,
		&"bottle_burst": _bottle_burst,
		&"explosion_small": _explosion.bind(false),
		&"explosion_large": _explosion.bind(true),
		&"fuse_armed": _fuse_armed,
		&"debris_wood": _debris_wood,
		&"debris_metal": _debris_metal,
		&"debris_crystal": _debris_crystal,
		&"barrel_bump": _barrel_bump,
		&"excavator_deploy": _excavator_deploy,
		&"excavator_drill": _excavator_drill.bind(true),
		&"excavator_idle": _excavator_drill.bind(false),
		&"terrain_pulse": _terrain_pulse,
		&"flag_flight": _flag_flight,
		&"flag_plant": _flag_plant,
		&"flag_destroyed": _flag_destroyed,
		&"chest_open": _chest_open,
		&"geode_open": _geode_open,
		&"reward_choices": _reward_choices,
		&"reward_perk": _reward_perk,
		&"reward_item": _reward_item,
	}
	return _recipes


# --- Building blocks ---

static func _frames(seconds: float, rate: int) -> int:
	return S.frame_count(seconds, rate)


## A decaying oscillator with a pitch glide: thumps, blips, and tonal bodies.
static func _sweep(
	rate: int, seconds: float, wave: S.Wave, start_hz: float, end_hz: float,
	curve: float, attack: float, decay: float
) -> PackedFloat32Array:
	var buffer := S.tone(_frames(seconds, rate), rate, wave, start_hz, end_hz, curve)
	return S.env_decay(buffer, rate, attack, decay)


## A decaying burst of filtered noise.
static func _noise(
	rate: int, seconds: float, noise_seed: int, kind: S.Filter, start_hz: float,
	end_hz: float, q: float, attack: float, decay: float, pink: bool = false
) -> PackedFloat32Array:
	var frames := _frames(seconds, rate)
	var buffer := S.pink_noise(frames, noise_seed) if pink else S.white_noise(frames, noise_seed)
	S.biquad(buffer, rate, kind, start_hz, end_hz, q)
	return S.env_decay(buffer, rate, attack, decay)


## Band-passed noise that swells to a peak and falls away: whooshes and breaths.
static func _swell(
	rate: int, seconds: float, noise_seed: int, start_hz: float, end_hz: float,
	q: float, peak_fraction: float, pink: bool = false
) -> PackedFloat32Array:
	var frames := _frames(seconds, rate)
	var buffer := S.pink_noise(frames, noise_seed) if pink else S.white_noise(frames, noise_seed)
	S.biquad(buffer, rate, BAND, start_hz, end_hz, q)
	return S.env_points(buffer, rate, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(seconds * peak_fraction, 1.0), Vector2(seconds, 0.0),
	]))


## A warm FM bell or pluck: bright at the strike, pure as it rings out.
static func _bell(
	rate: int, seconds: float, hz: float, ratio: float = 2.0, index: float = 1.2,
	attack: float = 0.003
) -> PackedFloat32Array:
	var buffer := S.fm(_frames(seconds, rate), rate, hz, hz, ratio, index, 0.0)
	return S.env_decay(buffer, rate, attack, seconds)


## Bells on successive MIDI notes, step_seconds apart.
static func _arpeggio(
	rate: int, notes: Array[float], step_seconds: float, note_seconds: float,
	ratio: float = 2.0, index: float = 1.2
) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	for note_index in range(notes.size()):
		var bell := _bell(rate, note_seconds, S.note_hz(notes[note_index]), ratio, index)
		buffer = S.mix_into(buffer, bell, rate, 1.0, step_seconds * note_index)
	return buffer


## Mixes a layer at a gain relative to its own peak, so layer gains read as a balance.
static func _layer(
	mix: PackedFloat32Array, layer: PackedFloat32Array, rate: int, gain: float,
	offset_seconds: float = 0.0
) -> PackedFloat32Array:
	S.normalize(layer, 1.0)
	return S.mix_into(mix, layer, rate, gain, offset_seconds)


## Scatters short grains produced by make_grain(index) over spread_seconds.
static func _scatter(
	rate: int, count: int, spread_seconds: float, scatter_seed: int, make_grain: Callable
) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	for grain_index in range(count):
		var offset := spread_seconds * S.hash01(scatter_seed, grain_index)
		var gain := 0.45 + 0.55 * S.hash01(scatter_seed + 101, grain_index)
		var grain: PackedFloat32Array = make_grain.call(grain_index)
		buffer = S.mix_into(buffer, grain, rate, gain, offset)
	return buffer


## Removes DC, fades both edges against clicks, and normalizes to the render peak.
static func _finish(buffer: PackedFloat32Array, rate: int, fade_in: float = 0.0005, fade_out: float = 0.012) -> PackedFloat32Array:
	S.high_pass(buffer, rate, 28.0)
	S.fade_edges(buffer, rate, fade_in, fade_out)
	return S.normalize(buffer, RENDER_PEAK)


# --- UI ---

static func _ui_hover(rate: int) -> PackedFloat32Array:
	var mix := _sweep(rate, 0.035, SINE, 1250.0, 1050.0, 1.0, 0.002, 0.03)
	return _finish(mix, rate, 0.001, 0.008)


static func _ui_press(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.08, rate))
	mix = _layer(mix, _sweep(rate, 0.07, TRIANGLE, 540.0, 330.0, 0.7, 0.001, 0.06), rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.02, 31, BAND, 2600.0, -1.0, 1.2, 0.0, 0.015), rate, 0.35)
	S.low_pass(mix, rate, 5200.0)
	return _finish(mix, rate, 0.0005, 0.01)


static func _ui_confirm(rate: int) -> PackedFloat32Array:
	var mix := _arpeggio(rate, [79.0, 84.0, 91.0], 0.07, 0.3, 2.0, 0.9)
	S.pad(mix, rate, 0.08)
	S.cave_tail(mix, rate, 0.047, 0.35, 0.25)
	return _finish(mix, rate)


static func _pause(rate: int, is_pausing: bool) -> PackedFloat32Array:
	var notes: Array[float] = [76.0, 71.0]
	if not is_pausing:
		notes.reverse()
	var mix := _arpeggio(rate, notes, 0.075, 0.16, 1.0, 0.6)
	S.low_pass(mix, rate, 3800.0)
	return _finish(mix, rate)


static func _item_select(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.06, rate))
	mix = _layer(mix, _sweep(rate, 0.05, SINE, 880.0, 660.0, 1.0, 0.001, 0.04), rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.012, 32, BAND, 3200.0, -1.0, 1.5, 0.0, 0.01), rate, 0.3)
	return _finish(mix, rate, 0.0005, 0.008)


# --- Run flow ---

static func _run_start(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.75, rate))
	mix = _layer(mix, _swell(rate, 0.55, 41, 2400.0, 420.0, 0.9, 0.25, true), rate, 0.5)
	mix = _layer(mix, _arpeggio(rate, [67.0, 72.0, 76.0], 0.09, 0.42, 2.0, 1.1), rate, 1.0, 0.06)
	mix = _layer(mix, _sweep(rate, 0.3, SINE, 98.0, 65.0, 0.8, 0.01, 0.28), rate, 0.5, 0.06)
	S.cave_tail(mix, rate, 0.061, 0.4, 0.3)
	return _finish(mix, rate, 0.004, 0.03)


static func _game_over(rate: int) -> PackedFloat32Array:
	## Starts after the death or flag sting that plays in the same frame.
	var lead_in := 0.8
	var mix := S.silence(_frames(2.2, rate))
	var notes: Array[float] = [64.0, 60.0, 57.0, 52.0]
	for note_index in range(notes.size()):
		var seconds := 0.9 if note_index == notes.size() - 1 else 0.5
		var voice := S.tone(_frames(seconds, rate), rate, TRIANGLE, S.note_hz(notes[note_index]), -1.0, 1.0, 0.5, 5.0, 0.006)
		S.env_decay(voice, rate, 0.012, seconds)
		mix = S.mix_into(mix, voice, rate, 0.8, lead_in + 0.24 * note_index)
		var under := _bell(rate, seconds, S.note_hz(notes[note_index] - 12.0), 1.0, 0.8, 0.01)
		mix = S.mix_into(mix, under, rate, 0.5, lead_in + 0.24 * note_index)
	S.low_pass(mix, rate, 2600.0)
	S.cave_tail(mix, rate, 0.083, 0.5, 0.4)
	return _finish(mix, rate, 0.002, 0.06)


static func _victory(rate: int) -> PackedFloat32Array:
	## Starts after the flag plant motif that plays in the same frame.
	var lead_in := 0.5
	var mix := S.silence(_frames(2.3, rate))
	var melody: Array[float] = [72.0, 76.0, 79.0, 84.0, 79.0, 84.0, 88.0]
	var times: Array[float] = [0.0, 0.11, 0.22, 0.33, 0.52, 0.63, 0.74]
	for note_index in range(melody.size()):
		var is_last := note_index == melody.size() - 1
		var bell := _bell(rate, 1.2 if is_last else 0.4, S.note_hz(melody[note_index]), 2.0, 1.4)
		mix = S.mix_into(mix, bell, rate, 0.9, lead_in + times[note_index])
	for chord_note: float in [60.0, 64.0, 67.0, 72.0]:
		var pad_voice := S.tone(_frames(1.25, rate), rate, TRIANGLE, S.note_hz(chord_note), -1.0, 1.0, 0.5, 5.5, 0.004)
		S.env_adsr(pad_voice, rate, 0.04, 0.2, 0.6, 0.7)
		mix = S.mix_into(mix, pad_voice, rate, 0.22, lead_in + 0.74)
	mix = _layer(mix, _swell(rate, 0.9, 42, 3000.0, 7000.0, 0.8, 0.2), rate, 0.12, lead_in + 0.7)
	S.cave_tail(mix, rate, 0.079, 0.5, 0.4)
	return _finish(mix, rate, 0.002, 0.08)


# --- Player ---

static func _jump(rate: int, is_air_jump: bool) -> PackedFloat32Array:
	var seconds := 0.13 if is_air_jump else 0.17
	var mix := S.silence(_frames(seconds, rate))
	if is_air_jump:
		mix = _layer(mix, _swell(rate, seconds, 51, 1000.0, 3200.0, 1.1, 0.3), rate, 1.0)
		var chirp := S.tone(_frames(seconds, rate), rate, SINE, 460.0, 820.0, 0.8)
		S.env_points(chirp, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.02, 1.0), Vector2(seconds, 0.0)]))
		mix = _layer(mix, chirp, rate, 0.4)
	else:
		mix = _layer(mix, _swell(rate, seconds, 52, 380.0, 1500.0, 0.9, 0.3, true), rate, 1.0)
		var effort := S.tone(_frames(seconds, rate), rate, TRIANGLE, 170.0, 330.0, 0.8)
		S.env_points(effort, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.025, 1.0), Vector2(seconds, 0.0)]))
		S.low_pass(effort, rate, 900.0)
		mix = _layer(mix, effort, rate, 0.55)
	return _finish(mix, rate, 0.003, 0.02)


static func _land(rate: int, is_heavy: bool) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.3 if is_heavy else 0.14, rate))
	if is_heavy:
		var thud := _sweep(rate, 0.26, SINE, 150.0, 48.0, 0.6, 0.002, 0.2)
		S.saturate(thud, 1.8)
		mix = _layer(mix, thud, rate, 1.0)
		mix = _layer(mix, _noise(rate, 0.14, 53, BAND, 1100.0, 380.0, 0.7, 0.001, 0.12, true), rate, 1.0)
		var grit := S.crackle(_frames(0.2, rate), rate, 54, 500.0, 40.0)
		S.biquad(grit, rate, BAND, 1700.0, 900.0, 1.2)
		S.env_decay(grit, rate, 0.005, 0.18)
		mix = _layer(mix, grit, rate, 0.22, 0.015)
	else:
		mix = _layer(mix, _sweep(rate, 0.12, SINE, 175.0, 70.0, 0.6, 0.002, 0.1), rate, 1.0)
		mix = _layer(mix, _noise(rate, 0.07, 55, BAND, 900.0, 420.0, 0.7, 0.001, 0.06, true), rate, 0.9)
	return _finish(mix, rate)


static func _hard_impact(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.36, rate))
	var body := _sweep(rate, 0.3, SINE, 190.0, 48.0, 0.5, 0.001, 0.26)
	S.saturate(body, 2.0)
	mix = _layer(mix, body, rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.11, 56, BAND, 1500.0, 550.0, 0.8, 0.0, 0.1), rate, 1.1)
	mix = _layer(mix, _sweep(rate, 0.08, TRIANGLE, 420.0, 160.0, 0.6, 0.0005, 0.07), rate, 0.6)
	mix = _layer(mix, _noise(rate, 0.02, 57, HIGH, 2500.0, -1.0, 0.7, 0.0, 0.015), rate, 0.6)
	S.saturate(mix, 1.5)
	S.cave_tail(mix, rate, 0.037, 0.35, 0.25)
	return _finish(mix, rate)


static func _knockout(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.85, rate))
	var dizzy := S.tone(_frames(0.7, rate), rate, TRIANGLE, 720.0, 230.0, 0.8, 0.5, 9.0, 0.05)
	S.env_points(dizzy, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.02, 1.0), Vector2(0.2, 0.5), Vector2(0.45, 0.3), Vector2(0.7, 0.0)]))
	S.low_pass(dizzy, rate, 2400.0)
	mix = _layer(mix, dizzy, rate, 1.0)
	var stars: Array[float] = [93.0, 89.0, 86.0]
	for star_index in range(stars.size()):
		var star := _bell(rate, 0.2, S.note_hz(stars[star_index]), 3.0, 0.8)
		mix = S.mix_into(mix, star, rate, 0.3, 0.12 + 0.17 * star_index)
	S.cave_tail(mix, rate, 0.053, 0.4, 0.3)
	return _finish(mix, rate, 0.002, 0.03)


static func _hook_launch(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.16, rate))
	mix = _layer(mix, _swell(rate, 0.15, 61, 900.0, 5200.0, 2.0, 0.55), rate, 1.0)
	var zip := S.tone(_frames(0.13, rate), rate, SAW, 420.0, 1900.0, 0.8)
	S.env_points(zip, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 1.0), Vector2(0.13, 0.0)]))
	S.biquad(zip, rate, LOW, 2600.0, -1.0, 0.9)
	mix = _layer(mix, zip, rate, 0.3)
	return _finish(mix, rate, 0.002, 0.015)


static func _hook_attach(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.3, rate))
	mix = _layer(mix, S.env_decay(S.fm(_frames(0.2, rate), rate, 1480.0, 1480.0, 2.76, 1.6, 0.1), rate, 0.0005, 0.16), rate, 1.0)
	mix = _layer(mix, _sweep(rate, 0.12, SINE, 2390.0, 2390.0, 1.0, 0.0005, 0.09), rate, 0.45)
	mix = _layer(mix, _sweep(rate, 0.07, SINE, 190.0, 85.0, 0.6, 0.001, 0.06), rate, 0.75)
	mix = _layer(mix, _noise(rate, 0.02, 62, HIGH, 3000.0, -1.0, 0.7, 0.0, 0.012), rate, 0.5)
	S.cave_tail(mix, rate, 0.031, 0.35, 0.25)
	return _finish(mix, rate)


static func _hook_attach_moving(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.3, rate))
	mix = _layer(mix, _sweep(rate, 0.16, SINE, 250.0, 120.0, 0.6, 0.001, 0.14), rate, 1.0)
	mix = _layer(mix, S.env_decay(S.fm(_frames(0.16, rate), rate, 640.0, 600.0, 1.47, 2.4, 0.3), rate, 0.0005, 0.13), rate, 0.7)
	mix = _layer(mix, _noise(rate, 0.03, 63, BAND, 1800.0, 900.0, 1.0, 0.0, 0.025), rate, 0.5)
	S.cave_tail(mix, rate, 0.029, 0.4, 0.3)
	return _finish(mix, rate)


static func _hook_miss(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.26, rate))
	mix = _layer(mix, _sweep(rate, 0.08, SINE, 170.0, 80.0, 0.7, 0.002, 0.07), rate, 1.0)
	var rattle := _scatter(rate, 4, 0.14, 64, func(grain_index: int) -> PackedFloat32Array:
		return _noise(rate, 0.03, 65 + grain_index, BAND, 1700.0 - 150.0 * grain_index, -1.0, 2.5, 0.0, 0.025)
	)
	mix = _layer(mix, rattle, rate, 0.55, 0.03)
	S.low_pass(mix, rate, 3600.0)
	return _finish(mix, rate)


static func _hook_release(rate: int) -> PackedFloat32Array:
	var mix := _noise(rate, 0.11, 66, BAND, 4200.0, 800.0, 1.6, 0.004, 0.1)
	return _finish(mix, rate, 0.002, 0.015)


static func _hook_snap(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.34, rate))
	var twang := S.tone(_frames(0.3, rate), rate, SAW, 250.0, 130.0, 0.5, 0.5, 23.0, 0.04)
	S.env_decay(twang, rate, 0.001, 0.26)
	S.biquad(twang, rate, LOW, 2400.0, 500.0, 1.4)
	mix = _layer(mix, twang, rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.09, 67, BAND, 3800.0, 900.0, 1.4, 0.001, 0.08), rate, 0.6)
	return _finish(mix, rate)


static func _splash_in(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.55, rate))
	mix = _layer(mix, _noise(rate, 0.45, 71, BAND, 2800.0, 480.0, 0.7, 0.004, 0.4), rate, 1.0)
	mix = _layer(mix, _sweep(rate, 0.09, SINE, 210.0, 90.0, 0.7, 0.002, 0.08), rate, 0.6)
	var bubbles := _scatter(rate, 6, 0.3, 72, func(grain_index: int) -> PackedFloat32Array:
		var base := 380.0 + 520.0 * S.hash01(73, grain_index)
		return _sweep(rate, 0.05, SINE, base, base * 1.9, 1.0, 0.004, 0.045)
	)
	mix = _layer(mix, bubbles, rate, 0.35, 0.08)
	S.low_pass(mix, rate, 6000.0)
	return _finish(mix, rate, 0.001, 0.03)


static func _splash_out(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.4, rate))
	mix = _layer(mix, _swell(rate, 0.28, 74, 700.0, 3400.0, 0.8, 0.2), rate, 1.0)
	var drips := _scatter(rate, 4, 0.22, 75, func(grain_index: int) -> PackedFloat32Array:
		var base := 900.0 + 900.0 * S.hash01(76, grain_index)
		return _sweep(rate, 0.04, SINE, base * 1.5, base, 1.0, 0.002, 0.035)
	)
	mix = _layer(mix, drips, rate, 0.4, 0.1)
	return _finish(mix, rate, 0.002, 0.03)


static func _sand_burrow(rate: int, is_entering: bool) -> PackedFloat32Array:
	var seconds := 0.42 if is_entering else 0.3
	var frames := _frames(seconds, rate)
	var grains := S.pink_noise(frames, 77)
	if is_entering:
		S.biquad(grains, rate, BAND, 2600.0, 520.0, 0.8)
	else:
		S.biquad(grains, rate, BAND, 600.0, 2400.0, 0.8)
	S.tremolo(grains, rate, 37.0, 0.55)
	S.env_points(grains, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(seconds * 0.25, 1.0), Vector2(seconds, 0.0)]))
	var mix := S.silence(frames)
	mix = _layer(mix, grains, rate, 1.0)
	var grit := S.crackle(frames, rate, 78, 900.0, 300.0)
	S.biquad(grit, rate, BAND, 3000.0, 1800.0, 1.0)
	S.env_points(grit, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(seconds * 0.3, 1.0), Vector2(seconds, 0.0)]))
	mix = _layer(mix, grit, rate, 0.3)
	if is_entering:
		mix = _layer(mix, _sweep(rate, 0.2, SINE, 110.0, 60.0, 0.8, 0.02, 0.18), rate, 0.45)
	return _finish(mix, rate, 0.004, 0.03)


static func _hazard_warning(rate: int, is_critical: bool) -> PackedFloat32Array:
	var pulse_count := 2 if is_critical else 1
	var root := 74.0 if is_critical else 69.0
	var mix := S.silence(_frames(0.2 + 0.13 * (pulse_count - 1), rate))
	for pulse_index in range(pulse_count):
		for interval: float in [0.0, 7.0]:
			var voice := S.tone(_frames(0.2, rate), rate, TRIANGLE, S.note_hz(root + interval))
			S.env_decay(voice, rate, 0.006, 0.16)
			mix = S.mix_into(mix, voice, rate, 0.6 if interval > 0.0 else 1.0, 0.13 * pulse_index)
		var knock := _sweep(rate, 0.05, SINE, 330.0, 220.0, 0.8, 0.001, 0.04)
		mix = S.mix_into(mix, knock, rate, 0.5, 0.13 * pulse_index)
	S.low_pass(mix, rate, 3000.0)
	return _finish(mix, rate, 0.002, 0.02)


# --- Death stings: a shared falling motif under a texture that names the cause ---

static func _death_motif(rate: int, low_pass_hz: float = 2600.0, vibrato_depth: float = 0.008) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.95, rate))
	var notes: Array[float] = [57.0, 51.0]
	for note_index in range(notes.size()):
		var seconds := 0.3 if note_index == 0 else 0.62
		var voice := S.tone(_frames(seconds, rate), rate, SAW, S.note_hz(notes[note_index]), S.note_hz(notes[note_index] - 0.6), 1.0, 0.5, 6.0, vibrato_depth)
		S.env_decay(voice, rate, 0.004, seconds)
		S.biquad(voice, rate, LOW, 2200.0, 500.0, 1.0)
		mix = S.mix_into(mix, voice, rate, 0.8, 0.17 * note_index)
		var sub := _sweep(rate, seconds, SINE, S.note_hz(notes[note_index] - 12.0), S.note_hz(notes[note_index] - 13.0), 1.0, 0.004, seconds)
		mix = S.mix_into(mix, sub, rate, 0.7, 0.17 * note_index)
	S.saturate(mix, 1.6)
	S.low_pass(mix, rate, low_pass_hz)
	return S.normalize(mix, 1.0)


static func _death_finish(mix: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	S.pad(mix, rate, 0.15)
	S.cave_tail(mix, rate, 0.073, 0.5, 0.4)
	return _finish(mix, rate, 0.0005, 0.06)


static func _sizzle(rate: int, seconds: float, noise_seed: int) -> PackedFloat32Array:
	var frames := _frames(seconds, rate)
	var hiss := S.white_noise(frames, noise_seed)
	S.biquad(hiss, rate, BAND, 5200.0, 2600.0, 0.7)
	S.tremolo(hiss, rate, 43.0, 0.35)
	S.env_decay(hiss, rate, 0.01, seconds)
	var spit := S.crackle(frames, rate, noise_seed + 1, 500.0, 60.0)
	S.biquad(spit, rate, HIGH, 2400.0, -1.0, 0.8)
	S.env_decay(spit, rate, 0.005, seconds)
	S.normalize(hiss, 1.0)
	return _layer(hiss, spit, rate, 0.6)


static func _death_cooked(rate: int) -> PackedFloat32Array:
	var mix := _death_motif(rate)
	mix = _layer(mix, _sizzle(rate, 0.8, 81), rate, 0.55)
	return _death_finish(mix, rate)


static func _death_suffocation(rate: int) -> PackedFloat32Array:
	var mix := _death_motif(rate, 900.0)
	var gasp := S.pink_noise(_frames(0.7, rate), 82)
	S.biquad(gasp, rate, BAND, 900.0, 380.0, 1.2)
	S.env_points(gasp, rate, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.08, 1.0), Vector2(0.22, 0.15), Vector2(0.3, 0.7), Vector2(0.45, 0.1), Vector2(0.52, 0.4), Vector2(0.7, 0.0),
	]))
	mix = _layer(mix, gasp, rate, 0.7)
	return _death_finish(mix, rate)


static func _death_acid(rate: int) -> PackedFloat32Array:
	var mix := _death_motif(rate)
	mix = _layer(mix, _sizzle(rate, 0.7, 83), rate, 0.35)
	var bubbles := _scatter(rate, 9, 0.6, 84, func(grain_index: int) -> PackedFloat32Array:
		var base := 300.0 + 700.0 * S.hash01(85, grain_index)
		return _sweep(rate, 0.06, SINE, base, base * 2.2, 1.0, 0.004, 0.055)
	)
	mix = _layer(mix, bubbles, rate, 0.5, 0.04)
	return _death_finish(mix, rate)


static func _death_poison(rate: int) -> PackedFloat32Array:
	var mix := _death_motif(rate, 2000.0, 0.035)
	S.ring_mod(mix, rate, 31.0, 0.45)
	var wheeze := S.tone(_frames(0.7, rate), rate, SINE, 880.0, 370.0, 1.2, 0.5, 7.0, 0.06)
	S.env_points(wheeze, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.1, 1.0), Vector2(0.7, 0.0)]))
	mix = _layer(mix, wheeze, rate, 0.3, 0.05)
	return _death_finish(mix, rate)


static func _death_bomb(rate: int) -> PackedFloat32Array:
	var mix := _death_motif(rate, 1800.0)
	var thump := _sweep(rate, 0.3, SINE, 150.0, 36.0, 0.5, 0.001, 0.28)
	S.saturate(thump, 2.5)
	mix = _layer(mix, thump, rate, 0.9)
	var ringing := _sweep(rate, 0.9, SINE, 3150.0, 3150.0, 1.0, 0.15, 0.9)
	mix = _layer(mix, ringing, rate, 0.1, 0.05)
	return _death_finish(mix, rate)


static func _death_impact(rate: int) -> PackedFloat32Array:
	var mix := _death_motif(rate)
	var crunch := S.crackle(_frames(0.18, rate), rate, 86, 2400.0, 200.0)
	S.biquad(crunch, rate, BAND, 2200.0, 800.0, 0.9)
	S.env_decay(crunch, rate, 0.0, 0.16)
	mix = _layer(mix, crunch, rate, 0.7)
	var thud := _sweep(rate, 0.22, SINE, 170.0, 42.0, 0.5, 0.001, 0.2)
	S.saturate(thud, 2.5)
	mix = _layer(mix, thud, rate, 0.9)
	return _death_finish(mix, rate)


static func _death_fall(rate: int) -> PackedFloat32Array:
	var mix := _death_motif(rate)
	var whistle := S.tone(_frames(0.6, rate), rate, SINE, 1250.0, 240.0, 1.4, 0.5, 6.0, 0.015)
	S.env_points(whistle, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 1.0), Vector2(0.6, 0.0)]))
	mix = _layer(mix, whistle, rate, 0.4)
	return _death_finish(mix, rate)


# --- Items ---

static func _throw(rate: int, seconds: float, start_hz: float, end_hz: float, noise_seed: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(seconds, rate))
	mix = _layer(mix, _swell(rate, seconds, noise_seed, start_hz, end_hz, 1.2, 0.35), rate, 1.0)
	var effort := S.tone(_frames(seconds, rate), rate, SINE, start_hz * 0.3, start_hz * 0.45, 1.0)
	S.env_points(effort, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(seconds * 0.2, 1.0), Vector2(seconds, 0.0)]))
	mix = _layer(mix, effort, rate, 0.3)
	return _finish(mix, rate, 0.003, 0.02)


static func _throw_flag(rate: int) -> PackedFloat32Array:
	var flutter := _swell(rate, 0.34, 23, 520.0, 1900.0, 1.0, 0.3, true)
	S.tremolo(flutter, rate, 27.0, 0.65)
	var mix := S.silence(_frames(0.34, rate))
	mix = _layer(mix, flutter, rate, 1.0)
	mix = _layer(mix, _swell(rate, 0.2, 24, 900.0, 2600.0, 1.4, 0.3), rate, 0.5)
	return _finish(mix, rate, 0.003, 0.03)


static func _tool_pickaxe(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.3, rate))
	mix = _layer(mix, S.env_decay(S.fm(_frames(0.16, rate), rate, 1320.0, 1300.0, 3.1, 1.5, 0.1), rate, 0.0005, 0.13), rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.06, 25, BAND, 2700.0, 1500.0, 0.9, 0.0, 0.05), rate, 0.7)
	mix = _layer(mix, _sweep(rate, 0.09, SINE, 150.0, 68.0, 0.6, 0.001, 0.08), rate, 0.8)
	var chips := S.crackle(_frames(0.18, rate), rate, 26, 420.0, 30.0)
	S.biquad(chips, rate, BAND, 2400.0, 1600.0, 1.5)
	S.env_decay(chips, rate, 0.0, 0.16)
	mix = _layer(mix, chips, rate, 0.3, 0.03)
	S.cave_tail(mix, rate, 0.033, 0.35, 0.25)
	return _finish(mix, rate)


static func _tool_shovel(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.32, rate))
	mix = _layer(mix, _swell(rate, 0.22, 27, 520.0, 2300.0, 1.1, 0.45, true), rate, 1.0)
	mix = _layer(mix, S.env_decay(S.fm(_frames(0.08, rate), rate, 430.0, 400.0, 1.9, 1.8, 0.2), rate, 0.0005, 0.07), rate, 0.6)
	mix = _layer(mix, _sweep(rate, 0.08, SINE, 130.0, 70.0, 0.7, 0.001, 0.07), rate, 0.6)
	var crumble := S.crackle(_frames(0.2, rate), rate, 28, 700.0, 60.0)
	S.biquad(crumble, rate, BAND, 1500.0, 800.0, 1.0)
	S.env_decay(crumble, rate, 0.01, 0.18)
	mix = _layer(mix, crumble, rate, 0.45, 0.1)
	return _finish(mix, rate, 0.002, 0.02)


static func _bounce_metal(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.16, rate))
	mix = _layer(mix, S.env_decay(S.fm(_frames(0.13, rate), rate, 540.0, 520.0, 2.31, 2.2, 0.2), rate, 0.0005, 0.1), rate, 1.0)
	mix = _layer(mix, _sweep(rate, 0.07, SINE, 170.0, 90.0, 0.7, 0.001, 0.06), rate, 0.8)
	mix = _layer(mix, _noise(rate, 0.015, 91, BAND, 2200.0, -1.0, 1.0, 0.0, 0.012), rate, 0.4)
	return _finish(mix, rate)


static func _bounce_glass(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.14, rate))
	mix = _layer(mix, _sweep(rate, 0.11, SINE, 2380.0, 2380.0, 1.0, 0.0005, 0.08), rate, 1.0)
	mix = _layer(mix, _sweep(rate, 0.07, SINE, 3710.0, 3710.0, 1.0, 0.0005, 0.05), rate, 0.5)
	mix = _layer(mix, _sweep(rate, 0.04, SINE, 420.0, 300.0, 0.8, 0.001, 0.035), rate, 0.5)
	mix = _layer(mix, _noise(rate, 0.01, 92, HIGH, 3000.0, -1.0, 0.7, 0.0, 0.008), rate, 0.35)
	return _finish(mix, rate)


static func _bounce_wood(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.11, rate))
	mix = _layer(mix, _sweep(rate, 0.08, SINE, 420.0, 330.0, 0.7, 0.0005, 0.06), rate, 1.0)
	mix = _layer(mix, _sweep(rate, 0.05, TRIANGLE, 760.0, 700.0, 1.0, 0.0005, 0.035), rate, 0.4)
	mix = _layer(mix, _noise(rate, 0.02, 93, BAND, 1300.0, -1.0, 1.2, 0.0, 0.015), rate, 0.5)
	return _finish(mix, rate)


static func _flare_fizzle(rate: int) -> PackedFloat32Array:
	var mix := _sizzle(rate, 0.55, 94)
	S.biquad(mix, rate, LOW, 9000.0, 1400.0, 0.8)
	mix = _layer(mix, _sweep(rate, 0.3, SINE, 620.0, 180.0, 1.0, 0.02, 0.28), rate, 0.25)
	return _finish(mix, rate, 0.004, 0.04)


static func _item_sizzle(rate: int) -> PackedFloat32Array:
	var mix := _sizzle(rate, 0.5, 95)
	var plop := _sweep(rate, 0.1, SINE, 260.0, 110.0, 0.7, 0.003, 0.09)
	mix = _layer(mix, plop, rate, 0.7)
	S.low_pass(mix, rate, 7000.0)
	return _finish(mix, rate, 0.002, 0.04)


static func _bottle_burst(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.5, rate))
	mix = _layer(mix, _noise(rate, 0.04, 96, HIGH, 3800.0, -1.0, 0.7, 0.0, 0.03), rate, 0.9)
	var shards := _scatter(rate, 8, 0.09, 97, func(grain_index: int) -> PackedFloat32Array:
		var hz := 2300.0 + 4200.0 * S.hash01(98, grain_index)
		return _sweep(rate, 0.09, SINE, hz, hz * 0.995, 1.0, 0.0005, 0.03 + 0.05 * S.hash01(99, grain_index))
	)
	mix = _layer(mix, shards, rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.4, 100, BAND, 2000.0, 520.0, 0.8, 0.02, 0.36), rate, 0.75, 0.03)
	mix = _layer(mix, _sweep(rate, 0.07, SINE, 230.0, 110.0, 0.7, 0.002, 0.06), rate, 0.35, 0.02)
	return _finish(mix, rate, 0.0005, 0.03)


static func _explosion(rate: int, is_large: bool) -> PackedFloat32Array:
	var mix := S.silence(_frames(1.6 if is_large else 0.85, rate))
	var sub := _sweep(
		rate, 1.0 if is_large else 0.48, SINE,
		108.0 if is_large else 170.0, 27.0 if is_large else 45.0,
		0.5, 0.002, 0.9 if is_large else 0.42
	)
	S.saturate(sub, 2.4)
	mix = _layer(mix, sub, rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.04, 111, HIGH, 1500.0, -1.0, 0.7, 0.0, 0.035), rate, 0.8)
	var body := _noise(
		rate, 1.2 if is_large else 0.6, 112, LOW,
		2300.0 if is_large else 3600.0, 120.0 if is_large else 330.0,
		0.8, 0.004, 1.0 if is_large else 0.5, true
	)
	mix = _layer(mix, body, rate, 1.25)
	if is_large:
		var rumble := _noise(rate, 1.5, 113, LOW, 150.0, 70.0, 0.9, 0.06, 1.4, true)
		S.tremolo(rumble, rate, 13.0, 0.5)
		mix = _layer(mix, rumble, rate, 0.6)
	var debris := S.crackle(_frames(1.3 if is_large else 0.65, rate), rate, 114, 240.0 if is_large else 320.0, 8.0)
	S.biquad(debris, rate, BAND, 1400.0 if is_large else 2100.0, 650.0 if is_large else 1200.0, 1.4)
	S.env_decay(debris, rate, 0.02, 1.2 if is_large else 0.6)
	mix = _layer(mix, debris, rate, 0.4, 0.05)
	S.saturate(mix, 1.9 if is_large else 1.5)
	S.cave_tail(mix, rate, 0.089 if is_large else 0.047, 0.5 if is_large else 0.42, 0.4)
	return _finish(mix, rate, 0.0005, 0.08)


static func _fuse_armed(rate: int) -> PackedFloat32Array:
	var seconds := 0.36
	var hiss := S.white_noise(_frames(seconds, rate), 115)
	S.biquad(hiss, rate, BAND, 2400.0, 5200.0, 0.9)
	S.tremolo(hiss, rate, 61.0, 0.4)
	S.env_points(hiss, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.4), Vector2(0.28, 1.0), Vector2(seconds, 0.0)]))
	var mix := S.silence(_frames(seconds, rate))
	mix = _layer(mix, hiss, rate, 0.8)
	var ticks: Array[float] = [1250.0, 1650.0, 2100.0]
	for tick_index in range(ticks.size()):
		var tick := _sweep(rate, 0.025, SQUARE, ticks[tick_index], ticks[tick_index], 1.0, 0.0005, 0.02)
		S.low_pass(tick, rate, 4500.0)
		mix = S.mix_into(mix, tick, rate, 0.55, 0.02 + 0.1 * tick_index)
	return _finish(mix, rate, 0.002, 0.02)


static func _knock(rate: int, hz: float, decay: float, noise_seed: int) -> PackedFloat32Array:
	var mix := _sweep(rate, decay + 0.01, SINE, hz, hz * 0.8, 0.7, 0.0005, decay)
	var click := _noise(rate, 0.02, noise_seed, BAND, hz * 3.1, -1.0, 1.2, 0.0, 0.015)
	return _layer(mix, click, rate, 0.5)


static func _debris_wood(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.5, rate))
	var planks := _scatter(rate, 6, 0.28, 121, func(grain_index: int) -> PackedFloat32Array:
		return _knock(rate, 260.0 + 520.0 * S.hash01(122, grain_index), 0.05 + 0.04 * S.hash01(123, grain_index), 124 + grain_index)
	)
	mix = _layer(mix, planks, rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.12, 131, BAND, 1900.0, 700.0, 0.8, 0.0, 0.1), rate, 0.6)
	var splinters := S.crackle(_frames(0.4, rate), rate, 132, 600.0, 30.0)
	S.biquad(splinters, rate, BAND, 2600.0, 1400.0, 1.3)
	S.env_decay(splinters, rate, 0.0, 0.38)
	mix = _layer(mix, splinters, rate, 0.4)
	return _finish(mix, rate)


static func _debris_metal(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.7, rate))
	var plates := _scatter(rate, 4, 0.22, 133, func(grain_index: int) -> PackedFloat32Array:
		var hz := 240.0 + 460.0 * S.hash01(134, grain_index)
		return S.env_decay(S.fm(_frames(0.36, rate), rate, hz, hz * 0.98, 1.59 + 1.2 * S.hash01(135, grain_index), 3.2, 0.4), rate, 0.0005, 0.32)
	)
	mix = _layer(mix, plates, rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.1, 136, BAND, 3200.0, 1200.0, 0.8, 0.0, 0.08), rate, 0.55)
	mix = _layer(mix, _sweep(rate, 0.14, SINE, 120.0, 62.0, 0.6, 0.001, 0.12), rate, 0.6)
	S.cave_tail(mix, rate, 0.041, 0.45, 0.35)
	return _finish(mix, rate)


static func _debris_crystal(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.65, rate))
	mix = _layer(mix, _noise(rate, 0.05, 137, HIGH, 3200.0, -1.0, 0.7, 0.0, 0.04), rate, 0.8)
	var tinkles := _scatter(rate, 10, 0.36, 138, func(grain_index: int) -> PackedFloat32Array:
		var hz := 1700.0 + 3000.0 * S.hash01(139, grain_index)
		return _bell(rate, 0.1 + 0.12 * S.hash01(140, grain_index), hz, 2.4, 0.7, 0.0005)
	)
	mix = _layer(mix, tinkles, rate, 1.0)
	mix = _layer(mix, _sweep(rate, 0.1, SINE, 210.0, 100.0, 0.7, 0.001, 0.09), rate, 0.45)
	S.cave_tail(mix, rate, 0.043, 0.45, 0.35)
	return _finish(mix, rate)


static func _barrel_bump(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.24, rate))
	mix = _layer(mix, _sweep(rate, 0.16, SINE, 104.0, 72.0, 0.7, 0.001, 0.14), rate, 1.0)
	mix = _layer(mix, S.env_decay(S.fm(_frames(0.14, rate), rate, 215.0, 205.0, 1.59, 2.2, 0.3), rate, 0.0005, 0.11), rate, 0.75)
	mix = _layer(mix, _noise(rate, 0.04, 141, BAND, 1300.0, 600.0, 0.8, 0.0, 0.035), rate, 0.8)
	S.comb(mix, rate, 0.0061, 0.35, 0.3)
	return _finish(mix, rate)


static func _motor(rate: int, seconds: float, start_hz: float, end_hz: float) -> PackedFloat32Array:
	var motor := S.tone(_frames(seconds, rate), rate, SAW, start_hz, end_hz, 0.7)
	S.tremolo(motor, rate, 24.0, 0.45)
	return S.biquad(motor, rate, LOW, 520.0, 950.0, 1.2)


static func _excavator_deploy(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.7, rate))
	var motor := _motor(rate, 0.62, 52.0, 175.0)
	S.env_points(motor, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.08, 0.7), Vector2(0.4, 1.0), Vector2(0.62, 0.0)]))
	mix = _layer(mix, motor, rate, 0.9, 0.06)
	mix = _layer(mix, S.env_decay(S.fm(_frames(0.14, rate), rate, 330.0, 310.0, 2.31, 2.6, 0.3), rate, 0.0005, 0.12), rate, 0.8)
	mix = _layer(mix, _sweep(rate, 0.1, SINE, 140.0, 70.0, 0.6, 0.001, 0.09), rate, 0.7)
	var servo := S.tone(_frames(0.3, rate), rate, SQUARE, 480.0, 1150.0, 1.0, 0.3)
	S.env_points(servo, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 1.0), Vector2(0.24, 0.8), Vector2(0.3, 0.0)]))
	S.low_pass(servo, rate, 2200.0)
	mix = _layer(mix, servo, rate, 0.22, 0.2)
	return _finish(mix, rate, 0.0005, 0.04)


static func _excavator_drill(rate: int, is_digging: bool) -> PackedFloat32Array:
	var seconds := 0.2 if is_digging else 0.12
	var mix := S.silence(_frames(seconds, rate))
	var motor := _motor(rate, seconds, 96.0 if is_digging else 78.0, 70.0 if is_digging else 66.0)
	S.env_points(motor, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.015, 1.0), Vector2(seconds, 0.0)]))
	mix = _layer(mix, motor, rate, 1.0)
	if is_digging:
		var grind := S.crackle(_frames(seconds, rate), rate, 142, 1500.0, 300.0)
		S.biquad(grind, rate, BAND, 1300.0, 700.0, 1.0)
		S.env_decay(grind, rate, 0.01, seconds)
		mix = _layer(mix, grind, rate, 0.5)
		mix = _layer(mix, _noise(rate, 0.08, 143, BAND, 900.0, 500.0, 0.9, 0.005, 0.07, true), rate, 0.4)
	S.low_pass(mix, rate, 2800.0)
	return _finish(mix, rate, 0.003, 0.03)


static func _terrain_pulse(rate: int) -> PackedFloat32Array:
	var seconds := 1.5
	var frames := _frames(seconds, rate)
	var mix := S.silence(frames)
	var rumble := S.pink_noise(frames, 144)
	S.biquad(rumble, rate, LOW, 650.0, 180.0, 0.9)
	S.tremolo(rumble, rate, 10.0, 0.6)
	S.env_points(rumble, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 1.0), Vector2(0.5, 0.6), Vector2(seconds, 0.0)]))
	mix = _layer(mix, rumble, rate, 1.0)
	var drone := S.tone(frames, rate, SINE, 62.0, 40.0, 0.8)
	S.env_points(drone, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 1.0), Vector2(seconds, 0.0)]))
	S.saturate(drone, 2.0)
	mix = _layer(mix, drone, rate, 0.55)
	var stones := S.crackle(frames, rate, 145, 220.0, 20.0)
	S.biquad(stones, rate, BAND, 1100.0, 600.0, 1.4)
	S.env_decay(stones, rate, 0.03, seconds)
	mix = _layer(mix, stones, rate, 0.45)
	return _finish(mix, rate, 0.004, 0.1)


# --- Flag and rewards ---

static func _flag_flight(rate: int) -> PackedFloat32Array:
	var seconds := 0.55
	var mix := S.silence(_frames(seconds, rate))
	var whistle := S.tone(_frames(seconds, rate), rate, SINE, 520.0, 940.0, 0.7, 0.5, 6.5, 0.012)
	S.env_points(whistle, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.1, 1.0), Vector2(seconds, 0.0)]))
	mix = _layer(mix, whistle, rate, 0.7)
	var fifth := S.tone(_frames(seconds, rate), rate, SINE, 780.0, 1410.0, 0.7, 0.5, 6.5, 0.012)
	S.env_points(fifth, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.16, 1.0), Vector2(seconds, 0.0)]))
	mix = _layer(mix, fifth, rate, 0.3)
	mix = _layer(mix, _swell(rate, seconds, 151, 1500.0, 4200.0, 0.9, 0.3), rate, 0.35)
	return _finish(mix, rate, 0.004, 0.05)


static func _flag_plant(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(1.0, rate))
	var stake := _sweep(rate, 0.16, SINE, 150.0, 58.0, 0.6, 0.001, 0.14)
	S.saturate(stake, 2.0)
	mix = _layer(mix, stake, rate, 1.0)
	mix = _layer(mix, _noise(rate, 0.08, 152, BAND, 1300.0, 500.0, 0.8, 0.0, 0.07, true), rate, 0.5)
	mix = _layer(mix, _arpeggio(rate, [72.0, 76.0, 79.0, 84.0], 0.075, 0.5, 2.0, 1.3), rate, 0.9, 0.07)
	S.cave_tail(mix, rate, 0.067, 0.45, 0.35)
	return _finish(mix, rate, 0.0005, 0.06)


static func _flag_destroyed(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(1.1, rate))
	mix = _layer(mix, _sizzle(rate, 0.7, 153), rate, 0.6)
	mix = _layer(mix, _sweep(rate, 0.12, SINE, 300.0, 120.0, 0.7, 0.002, 0.1), rate, 0.5)
	var notes: Array[float] = [70.0, 66.0, 63.0]
	for note_index in range(notes.size()):
		var voice := S.tone(_frames(0.45, rate), rate, TRIANGLE, S.note_hz(notes[note_index]), S.note_hz(notes[note_index] - 0.8), 1.0, 0.5, 5.5, 0.01)
		S.env_decay(voice, rate, 0.008, 0.45)
		mix = S.mix_into(mix, voice, rate, 0.7, 0.14 + 0.17 * note_index)
	S.low_pass(mix, rate, 5200.0)
	S.cave_tail(mix, rate, 0.071, 0.45, 0.35)
	return _finish(mix, rate, 0.002, 0.06)


static func _chest_open(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.75, rate))
	mix = _layer(mix, _knock(rate, 360.0, 0.06, 154), rate, 0.9)
	mix = _layer(mix, _knock(rate, 520.0, 0.05, 155), rate, 0.7, 0.07)
	var creak := S.tone(_frames(0.22, rate), rate, SAW, 170.0, 290.0, 1.3, 0.5, 31.0, 0.05)
	S.biquad(creak, rate, BAND, 900.0, 1500.0, 2.2)
	S.env_points(creak, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 1.0), Vector2(0.22, 0.0)]))
	mix = _layer(mix, creak, rate, 0.35, 0.09)
	mix = _layer(mix, _arpeggio(rate, [79.0, 84.0, 88.0, 91.0], 0.06, 0.35, 3.0, 0.9), rate, 0.75, 0.2)
	S.cave_tail(mix, rate, 0.059, 0.42, 0.3)
	return _finish(mix, rate, 0.0005, 0.05)


static func _geode_open(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.85, rate))
	mix = _layer(mix, _noise(rate, 0.05, 156, HIGH, 2600.0, -1.0, 0.7, 0.0, 0.04), rate, 0.7)
	mix = _layer(mix, _sweep(rate, 0.1, SINE, 240.0, 110.0, 0.7, 0.001, 0.09), rate, 0.55)
	var tinkles := _scatter(rate, 6, 0.2, 157, func(grain_index: int) -> PackedFloat32Array:
		return _bell(rate, 0.14, 2200.0 + 3600.0 * S.hash01(158, grain_index), 2.4, 0.7, 0.0005)
	)
	mix = _layer(mix, tinkles, rate, 0.6)
	var shimmer := PackedFloat32Array()
	for chord_note: float in [74.0, 81.0, 86.0, 90.0]:
		var voice := _bell(rate, 0.6, S.note_hz(chord_note), 3.0, 1.0, 0.03)
		S.tremolo(voice, rate, 7.0 + chord_note * 0.05, 0.35)
		shimmer = S.mix_into(shimmer, voice, rate, 1.0, 0.02 * (chord_note - 74.0) / 4.0)
	mix = _layer(mix, shimmer, rate, 0.8, 0.14)
	S.cave_tail(mix, rate, 0.063, 0.48, 0.4)
	return _finish(mix, rate, 0.0005, 0.06)


static func _reward_choices(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.7, rate))
	mix = _layer(mix, _swell(rate, 0.35, 159, 900.0, 4600.0, 0.9, 0.6), rate, 0.3)
	mix = _layer(mix, _arpeggio(rate, [76.0, 79.0, 83.0, 88.0], 0.055, 0.42, 2.0, 1.0), rate, 1.0, 0.08)
	S.cave_tail(mix, rate, 0.057, 0.42, 0.3)
	return _finish(mix, rate, 0.004, 0.05)


static func _reward_perk(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.95, rate))
	var rise := S.fm(_frames(0.4, rate), rate, 260.0, 1040.0, 1.5, 2.2, 0.4)
	S.tremolo(rise, rate, 19.0, 0.4)
	S.env_points(rise, rate, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.6), Vector2(0.34, 1.0), Vector2(0.4, 0.0)]))
	mix = _layer(mix, rise, rate, 0.6)
	var chord := PackedFloat32Array()
	for chord_note: float in [84.0, 88.0, 91.0, 96.0]:
		chord = S.mix_into(chord, _bell(rate, 0.55, S.note_hz(chord_note), 2.0, 1.3), rate, 1.0, 0.012 * (chord_note - 84.0))
	mix = _layer(mix, chord, rate, 1.0, 0.33)
	mix = _layer(mix, _sweep(rate, 0.2, SINE, 130.0, 65.0, 0.7, 0.004, 0.18), rate, 0.45, 0.33)
	S.cave_tail(mix, rate, 0.069, 0.48, 0.4)
	return _finish(mix, rate, 0.003, 0.06)


static func _reward_item(rate: int) -> PackedFloat32Array:
	var mix := S.silence(_frames(0.45, rate))
	mix = _layer(mix, _knock(rate, 480.0, 0.04, 160), rate, 0.6)
	mix = _layer(mix, _arpeggio(rate, [79.0, 86.0], 0.07, 0.3, 2.0, 1.1), rate, 1.0, 0.03)
	S.cave_tail(mix, rate, 0.045, 0.38, 0.25)
	return _finish(mix, rate, 0.0005, 0.04)
