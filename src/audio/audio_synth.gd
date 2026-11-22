## Pure mono sample-buffer synthesis toolkit. Buffers are PackedFloat32Array in [-1, 1].
## Generators return a new buffer; processors change the given buffer in place and return
## it so calls chain. Nothing here touches nodes, time, or global random state: the same
## arguments always produce the same samples.
class_name AudioSynth
extends RefCounted


enum Wave { SINE, TRIANGLE, SQUARE, SAW }
enum Filter { LOW_PASS, HIGH_PASS, BAND_PASS }

const PCM16_PEAK := 32767.0
const _LCG_MULTIPLIER := 1664525
const _LCG_INCREMENT := 1013904223
const _LCG_MASK := 0xFFFFFFFF
## -60 dB as a natural-log factor: an exponential decay over its decay time reaches it.
const _T60_LOG := 6.9078
const _FILTER_UPDATE_INTERVAL := 16
const _TAIL_DAMPING := 0.45


# --- Sizing and notes ---

static func frame_count(seconds: float, mix_rate: int) -> int:
	return maxi(1, int(round(seconds * mix_rate)))


static func silence(frames: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(maxi(0, frames))
	return buffer


## Frequency of a MIDI note number (69 is A4, 440 Hz).
static func note_hz(midi_note: float) -> float:
	return 440.0 * pow(2.0, (midi_note - 69.0) / 12.0)


# --- Oscillators ---

## An oscillator whose pitch glides exponentially from start_hz to end_hz. sweep_curve
## below 1 front-loads the glide (a fast drop that settles), above 1 delays it.
## pulse_width shapes SQUARE only. vibrato_depth is a fraction of the frequency.
static func tone(
	frames: int,
	mix_rate: int,
	wave: Wave,
	start_hz: float,
	end_hz: float = -1.0,
	sweep_curve: float = 1.0,
	pulse_width: float = 0.5,
	vibrato_hz: float = 0.0,
	vibrato_depth: float = 0.0
) -> PackedFloat32Array:
	var buffer := _phase_ramp(frames, mix_rate, start_hz, end_hz, sweep_curve, vibrato_hz, vibrato_depth)
	if wave == Wave.SINE:
		for index in range(frames):
			buffer[index] = sin(TAU * buffer[index])
	elif wave == Wave.TRIANGLE:
		for index in range(frames):
			buffer[index] = 1.0 - 4.0 * absf(buffer[index] - 0.5)
	elif wave == Wave.SQUARE:
		for index in range(frames):
			buffer[index] = 1.0 if buffer[index] < pulse_width else -1.0
	else:
		for index in range(frames):
			buffer[index] = 2.0 * buffer[index] - 1.0
	return buffer


## Two-operator sine FM: the modulator runs at carrier * ratio and its index glides from
## index_start to index_end, so a bright attack can mellow into a pure tone.
static func fm(
	frames: int,
	mix_rate: int,
	carrier_start_hz: float,
	carrier_end_hz: float,
	ratio: float,
	index_start: float,
	index_end: float = 0.0
) -> PackedFloat32Array:
	var buffer := _phase_ramp(frames, mix_rate, carrier_start_hz, carrier_end_hz, 1.0, 0.0, 0.0)
	var index_step := (index_end - index_start) / maxf(1.0, float(frames))
	var modulation := index_start
	var unwrapped := 0.0
	var previous := 0.0
	for index in range(frames):
		var phase := buffer[index]
		## The ramp wraps at 1; unwrap it so a non-integer ratio stays continuous.
		var advance := phase - previous
		if advance < 0.0:
			advance += 1.0
		unwrapped += advance
		previous = phase
		buffer[index] = sin(TAU * phase + modulation * sin(TAU * unwrapped * ratio))
		modulation += index_step
	return buffer


static func _phase_ramp(
	frames: int,
	mix_rate: int,
	start_hz: float,
	end_hz: float,
	sweep_curve: float,
	vibrato_hz: float,
	vibrato_depth: float
) -> PackedFloat32Array:
	var buffer := silence(frames)
	var target_hz := start_hz if end_hz <= 0.0 else end_hz
	var inverse_rate := 1.0 / float(mix_rate)
	var phase := 0.0
	var has_vibrato := vibrato_hz > 0.0 and vibrato_depth != 0.0
	if is_equal_approx(target_hz, start_hz) and not has_vibrato:
		var step := start_hz * inverse_rate
		for index in range(frames):
			buffer[index] = phase
			phase += step
			if phase >= 1.0:
				phase -= floorf(phase)
		return buffer
	var log_ratio := log(maxf(0.001, target_hz) / maxf(0.001, start_hz))
	var inverse_frames := 1.0 / maxf(1.0, float(frames - 1))
	var vibrato_step := TAU * vibrato_hz * inverse_rate
	if is_equal_approx(sweep_curve, 1.0):
		## A plain exponential glide multiplies the frequency by a constant every frame.
		var glide := exp(log_ratio * inverse_frames)
		var gliding_hz := start_hz
		for index in range(frames):
			buffer[index] = phase
			if has_vibrato:
				phase += gliding_hz * (1.0 + vibrato_depth * sin(vibrato_step * float(index))) * inverse_rate
			else:
				phase += gliding_hz * inverse_rate
			gliding_hz *= glide
			if phase >= 1.0:
				phase -= floorf(phase)
		return buffer
	for index in range(frames):
		var frequency := start_hz * exp(log_ratio * pow(float(index) * inverse_frames, sweep_curve))
		if has_vibrato:
			frequency *= 1.0 + vibrato_depth * sin(vibrato_step * float(index))
		buffer[index] = phase
		phase += frequency * inverse_rate
		if phase >= 1.0:
			phase -= floorf(phase)
	return buffer


# --- Noise ---

## Uniform white noise from a seeded linear congruential generator.
static func white_noise(frames: int, noise_seed: int) -> PackedFloat32Array:
	var buffer := silence(frames)
	var state := _seed_state(noise_seed)
	for index in range(frames):
		state = (state * _LCG_MULTIPLIER + _LCG_INCREMENT) & _LCG_MASK
		buffer[index] = float(state >> 8) / 8388608.0 - 1.0
	return buffer


## Pink-ish noise (about -3 dB per octave): white noise through three leaky integrators.
static func pink_noise(frames: int, noise_seed: int) -> PackedFloat32Array:
	var buffer := silence(frames)
	var state := _seed_state(noise_seed)
	var slow := 0.0
	var middle := 0.0
	var fast := 0.0
	for index in range(frames):
		state = (state * _LCG_MULTIPLIER + _LCG_INCREMENT) & _LCG_MASK
		var white := float(state >> 8) / 8388608.0 - 1.0
		slow = 0.99765 * slow + white * 0.0990460
		middle = 0.96300 * middle + white * 0.2965164
		fast = 0.57000 * fast + white * 1.0526913
		buffer[index] = (slow + middle + fast + white * 0.1848) * 0.22
	return buffer


## Sparse random impulses for crackle, sparks, and grit. The impulse rate glides from
## start_per_second to end_per_second; filter the result to give the grains a body.
static func crackle(
	frames: int,
	mix_rate: int,
	noise_seed: int,
	start_per_second: float,
	end_per_second: float
) -> PackedFloat32Array:
	var buffer := silence(frames)
	var state := _seed_state(noise_seed)
	var inverse_rate := 1.0 / float(mix_rate)
	var inverse_frames := 1.0 / maxf(1.0, float(frames))
	for index in range(frames):
		state = (state * _LCG_MULTIPLIER + _LCG_INCREMENT) & _LCG_MASK
		var chance := float(state >> 8) / 16777216.0
		var density := start_per_second + (end_per_second - start_per_second) * float(index) * inverse_frames
		if chance < density * inverse_rate:
			state = (state * _LCG_MULTIPLIER + _LCG_INCREMENT) & _LCG_MASK
			buffer[index] = float(state >> 8) / 8388608.0 - 1.0
	return buffer


## A deterministic value in [0, 1) for recipe decisions such as grain offsets.
static func hash01(value_seed: int, index: int) -> float:
	var state := _seed_state(value_seed + index * 7919)
	state = (state * _LCG_MULTIPLIER + _LCG_INCREMENT) & _LCG_MASK
	state = (state * _LCG_MULTIPLIER + _LCG_INCREMENT) & _LCG_MASK
	return float(state >> 8) / 16777216.0


static func _seed_state(noise_seed: int) -> int:
	return (noise_seed * 2654435761 + 12345) & _LCG_MASK


# --- Envelopes ---

## Linear attack to full level, then an exponential decay that is 60 dB down after
## decay_seconds.
static func env_decay(
	buffer: PackedFloat32Array,
	mix_rate: int,
	attack_seconds: float,
	decay_seconds: float
) -> PackedFloat32Array:
	var attack_frames := mini(buffer.size(), int(attack_seconds * mix_rate))
	for index in range(attack_frames):
		buffer[index] *= float(index) / float(attack_frames)
	var factor := exp(-_T60_LOG / maxf(1.0, decay_seconds * mix_rate))
	var level := 1.0
	for index in range(attack_frames, buffer.size()):
		buffer[index] *= level
		level *= factor
	return buffer


## Linear attack, decay to the sustain level, hold, and release over the last
## release_seconds of the buffer.
static func env_adsr(
	buffer: PackedFloat32Array,
	mix_rate: int,
	attack_seconds: float,
	decay_seconds: float,
	sustain_level: float,
	release_seconds: float
) -> PackedFloat32Array:
	var total := float(buffer.size()) / float(mix_rate)
	var release_start := maxf(attack_seconds + decay_seconds, total - release_seconds)
	return env_points(buffer, mix_rate, PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(attack_seconds, 1.0),
		Vector2(attack_seconds + decay_seconds, sustain_level),
		Vector2(release_start, sustain_level),
		Vector2(maxf(total, release_start + 0.0001), 0.0),
	]))


## Piecewise-linear envelope through (seconds, level) points sorted by time. The level
## before the first point and after the last one holds.
static func env_points(
	buffer: PackedFloat32Array,
	mix_rate: int,
	points: PackedVector2Array
) -> PackedFloat32Array:
	if points.is_empty():
		return buffer
	var frames := buffer.size()
	var cursor := 0
	var first_frame := mini(frames, int(points[0].x * mix_rate))
	for index in range(cursor, first_frame):
		buffer[index] *= points[0].y
	cursor = first_frame
	for point_index in range(1, points.size()):
		var from_point := points[point_index - 1]
		var to_point := points[point_index]
		var end_frame := mini(frames, int(to_point.x * mix_rate))
		var span := float(maxi(1, end_frame - cursor))
		var start_frame := cursor
		for index in range(start_frame, end_frame):
			buffer[index] *= from_point.y + (to_point.y - from_point.y) * float(index - start_frame) / span
		cursor = maxi(cursor, end_frame)
	var last_level := points[points.size() - 1].y
	for index in range(cursor, frames):
		buffer[index] *= last_level
	return buffer


## Short linear fades that remove clicks at both ends.
static func fade_edges(
	buffer: PackedFloat32Array,
	mix_rate: int,
	fade_in_seconds: float,
	fade_out_seconds: float
) -> PackedFloat32Array:
	var frames := buffer.size()
	var in_frames := mini(frames, int(fade_in_seconds * mix_rate))
	for index in range(in_frames):
		buffer[index] *= float(index) / float(in_frames)
	var out_frames := mini(frames, int(fade_out_seconds * mix_rate))
	for index in range(out_frames):
		buffer[frames - 1 - index] *= float(index) / float(out_frames)
	return buffer


## Amplitude wobble between (1 - depth) and 1.
static func tremolo(
	buffer: PackedFloat32Array,
	mix_rate: int,
	tremolo_hz: float,
	depth: float
) -> PackedFloat32Array:
	var step := TAU * tremolo_hz / float(mix_rate)
	for index in range(buffer.size()):
		buffer[index] *= 1.0 - depth * (0.5 + 0.5 * sin(step * float(index)))
	return buffer


## Multiplies by a sine carrier for metallic, inharmonic colour. mix 0 leaves the input.
static func ring_mod(
	buffer: PackedFloat32Array,
	mix_rate: int,
	carrier_hz: float,
	mix: float = 1.0
) -> PackedFloat32Array:
	var step := TAU * carrier_hz / float(mix_rate)
	for index in range(buffer.size()):
		buffer[index] *= (1.0 - mix) + mix * sin(step * float(index))
	return buffer


# --- Filters ---

static func low_pass(buffer: PackedFloat32Array, mix_rate: int, cutoff_hz: float) -> PackedFloat32Array:
	var coefficient := 1.0 - exp(-TAU * cutoff_hz / float(mix_rate))
	var state := 0.0
	for index in range(buffer.size()):
		state += coefficient * (buffer[index] - state)
		buffer[index] = state
	return buffer


static func high_pass(buffer: PackedFloat32Array, mix_rate: int, cutoff_hz: float) -> PackedFloat32Array:
	var coefficient := 1.0 - exp(-TAU * cutoff_hz / float(mix_rate))
	var state := 0.0
	for index in range(buffer.size()):
		var sample := buffer[index]
		state += coefficient * (sample - state)
		buffer[index] = sample - state
	return buffer


## Resonant second-order filter whose cutoff glides exponentially from start_hz to
## end_hz (pass a negative end_hz for a fixed cutoff). BAND_PASS has unity peak gain.
static func biquad(
	buffer: PackedFloat32Array,
	mix_rate: int,
	kind: Filter,
	start_hz: float,
	end_hz: float = -1.0,
	q: float = 0.707
) -> PackedFloat32Array:
	var frames := buffer.size()
	var nyquist_limit := float(mix_rate) * 0.45
	var from_hz := clampf(start_hz, 10.0, nyquist_limit)
	var to_hz := from_hz if end_hz <= 0.0 else clampf(end_hz, 10.0, nyquist_limit)
	var sweeping := not is_equal_approx(from_hz, to_hz)
	var log_ratio := log(to_hz / from_hz)
	var inverse_frames := 1.0 / maxf(1.0, float(frames - 1))
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for index in range(frames):
		if index == 0 or (sweeping and index % _FILTER_UPDATE_INTERVAL == 0):
			var cutoff := from_hz * exp(log_ratio * float(index) * inverse_frames)
			var omega := TAU * cutoff / float(mix_rate)
			var cos_omega := cos(omega)
			var alpha := sin(omega) / (2.0 * maxf(0.05, q))
			var inverse_a0 := 1.0 / (1.0 + alpha)
			if kind == Filter.LOW_PASS:
				b1 = (1.0 - cos_omega) * inverse_a0
				b0 = b1 * 0.5
				b2 = b0
			elif kind == Filter.HIGH_PASS:
				b1 = -(1.0 + cos_omega) * inverse_a0
				b0 = -b1 * 0.5
				b2 = b0
			else:
				b0 = alpha * inverse_a0
				b1 = 0.0
				b2 = -b0
			a1 = -2.0 * cos_omega * inverse_a0
			a2 = (1.0 - alpha) * inverse_a0
		var input := buffer[index]
		var output := b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = input
		y2 = y1
		y1 = output
		buffer[index] = output
	return buffer


# --- Shaping and space ---

## Soft clipping through tanh, rescaled so a full-scale input stays full scale. Higher
## drive adds warmth, harmonics, and perceived loudness.
static func saturate(buffer: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var safe_drive := maxf(0.01, drive)
	var makeup := 1.0 / tanh(safe_drive)
	for index in range(buffer.size()):
		buffer[index] = tanh(buffer[index] * safe_drive) * makeup
	return buffer


## Feedback comb: each sample is fed back after delay_seconds through a one-pole damping
## filter. Short delays ring like a tube or plate; long ones echo. The buffer keeps its
## length, so pad it first to leave room for the tail.
static func comb(
	buffer: PackedFloat32Array,
	mix_rate: int,
	delay_seconds: float,
	feedback: float,
	damping: float = 0.0
) -> PackedFloat32Array:
	var delay_frames := maxi(1, int(delay_seconds * mix_rate))
	var damped := 0.0
	for index in range(delay_frames, buffer.size()):
		damped += (1.0 - damping) * (buffer[index - delay_frames] - damped)
		buffer[index] += feedback * damped
	return buffer


## A small cave tail: three damped combs of unrelated lengths mixed under the dry sound.
## size is the longest reflection in seconds, decay the feedback, mix the wet level.
static func cave_tail(
	buffer: PackedFloat32Array,
	mix_rate: int,
	size: float,
	decay: float,
	mix: float
) -> PackedFloat32Array:
	var frames := buffer.size()
	var first := silence(frames)
	var second := silence(frames)
	var third := silence(frames)
	var first_delay := maxi(1, int(size * mix_rate))
	var second_delay := maxi(1, int(size * 0.773 * mix_rate))
	var third_delay := maxi(1, int(size * 0.619 * mix_rate))
	var first_damped := 0.0
	var second_damped := 0.0
	var third_damped := 0.0
	var keep := 1.0 - _TAIL_DAMPING
	var wet_gain := mix / 3.0
	for index in range(frames):
		var dry := buffer[index]
		var wet := 0.0
		if index >= first_delay:
			first_damped += keep * (first[index - first_delay] - first_damped)
			wet += decay * first_damped
		first[index] = dry + decay * first_damped
		if index >= second_delay:
			second_damped += keep * (second[index - second_delay] - second_damped)
			wet += decay * second_damped
		second[index] = dry + decay * second_damped
		if index >= third_delay:
			third_damped += keep * (third[index - third_delay] - third_damped)
			wet += decay * third_damped
		third[index] = dry + decay * third_damped
		buffer[index] = dry + wet * wet_gain
	return buffer


# --- Mixing ---

## Appends silence so a tail effect or a later layer has room.
static func pad(buffer: PackedFloat32Array, mix_rate: int, seconds: float) -> PackedFloat32Array:
	buffer.resize(buffer.size() + maxi(0, int(seconds * mix_rate)))
	return buffer


static func scale(buffer: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	for index in range(buffer.size()):
		buffer[index] *= gain
	return buffer


## Adds source into target at offset_seconds, growing target when the layer runs past it.
static func mix_into(
	target: PackedFloat32Array,
	source: PackedFloat32Array,
	mix_rate: int,
	gain: float = 1.0,
	offset_seconds: float = 0.0
) -> PackedFloat32Array:
	var offset := maxi(0, int(offset_seconds * mix_rate))
	if target.size() < offset + source.size():
		target.resize(offset + source.size())
	for index in range(source.size()):
		target[offset + index] += source[index] * gain
	return target


static func peak(buffer: PackedFloat32Array) -> float:
	var result := 0.0
	for sample in buffer:
		result = maxf(result, absf(sample))
	return result


static func rms(buffer: PackedFloat32Array) -> float:
	if buffer.is_empty():
		return 0.0
	var total := 0.0
	for sample in buffer:
		total += sample * sample
	return sqrt(total / float(buffer.size()))


static func dc_offset(buffer: PackedFloat32Array) -> float:
	if buffer.is_empty():
		return 0.0
	var total := 0.0
	for sample in buffer:
		total += sample
	return total / float(buffer.size())


## Scales the buffer so its loudest sample sits at target_peak. Silence stays silence.
static func normalize(buffer: PackedFloat32Array, target_peak: float) -> PackedFloat32Array:
	var current := peak(buffer)
	if current < 0.000001:
		return buffer
	return scale(buffer, target_peak / current)


static func is_all_finite(buffer: PackedFloat32Array) -> bool:
	for sample in buffer:
		if not is_finite(sample):
			return false
	return true


# --- Output ---

## Little-endian signed 16-bit PCM, two bytes per frame; samples beyond full scale clamp.
static func to_pcm16(buffer: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for index in range(buffer.size()):
		bytes.encode_s16(index * 2, int(round(clampf(buffer[index], -1.0, 1.0) * PCM16_PEAK)))
	return bytes


static func to_stream(buffer: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = to_pcm16(buffer)
	return stream
