extends GutTest

const RATE := 32000


func test_generators_are_deterministic() -> void:
	assert_eq(AudioSynth.white_noise(512, 7), AudioSynth.white_noise(512, 7))
	assert_eq(AudioSynth.pink_noise(512, 7), AudioSynth.pink_noise(512, 7))
	assert_eq(AudioSynth.crackle(4096, RATE, 7, 800.0, 100.0), AudioSynth.crackle(4096, RATE, 7, 800.0, 100.0))
	assert_ne(AudioSynth.white_noise(512, 7), AudioSynth.white_noise(512, 8))
	assert_eq(
		AudioSynth.tone(512, RATE, AudioSynth.Wave.SAW, 300.0, 90.0, 0.5),
		AudioSynth.tone(512, RATE, AudioSynth.Wave.SAW, 300.0, 90.0, 0.5)
	)
	assert_eq(AudioSynth.fm(512, RATE, 400.0, 400.0, 2.76, 3.0), AudioSynth.fm(512, RATE, 400.0, 400.0, 2.76, 3.0))


func test_every_oscillator_stays_in_range_at_its_pitch() -> void:
	for wave: AudioSynth.Wave in [
		AudioSynth.Wave.SINE, AudioSynth.Wave.TRIANGLE, AudioSynth.Wave.SQUARE, AudioSynth.Wave.SAW,
	]:
		var buffer := AudioSynth.tone(RATE, RATE, wave, 440.0)
		assert_true(AudioSynth.is_all_finite(buffer))
		assert_between(AudioSynth.peak(buffer), 0.98, 1.0001)
		assert_almost_eq(float(_rising_crossings(buffer)), 440.0, 2.0, "wave %d is at 440 Hz" % wave)


func test_pitch_sweep_glides_between_its_endpoints() -> void:
	var buffer := AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 800.0, 200.0)

	var first_half := _rising_crossings(buffer.slice(0, RATE / 2))
	var second_half := _rising_crossings(buffer.slice(RATE / 2))

	assert_gt(float(first_half), second_half * 1.5)
	assert_between(float(first_half + second_half), 200.0, 800.0)


func test_noise_is_centered_and_pink_noise_is_darker_than_white() -> void:
	var white := AudioSynth.white_noise(RATE, 3)
	var pink := AudioSynth.pink_noise(RATE, 3)

	assert_almost_eq(AudioSynth.dc_offset(white), 0.0, 0.02)
	assert_between(AudioSynth.peak(white), 0.9, 1.0)
	assert_true(AudioSynth.is_all_finite(pink))
	assert_lt(_high_band_share(pink), _high_band_share(white))


func test_crackle_density_follows_its_rate() -> void:
	var dense := _non_zero_count(AudioSynth.crackle(RATE, RATE, 5, 2000.0, 2000.0))
	var sparse := _non_zero_count(AudioSynth.crackle(RATE, RATE, 5, 50.0, 50.0))

	assert_between(float(dense), 1500.0, 2500.0)
	assert_between(float(sparse), 20.0, 90.0)


func test_decay_envelope_attacks_then_falls_sixty_decibels() -> void:
	var buffer := _ones(RATE)
	AudioSynth.env_decay(buffer, RATE, 0.01, 0.5)

	assert_eq(buffer[0], 0.0)
	assert_almost_eq(buffer[int(0.01 * RATE)], 1.0, 0.001)
	assert_almost_eq(buffer[int(0.01 * RATE) + int(0.5 * RATE)], 0.001, 0.0005)
	assert_lt(buffer[RATE - 1], 0.001)


func test_adsr_envelope_holds_the_sustain_level_and_releases_to_silence() -> void:
	var buffer := _ones(RATE)
	AudioSynth.env_adsr(buffer, RATE, 0.1, 0.1, 0.5, 0.2)

	assert_eq(buffer[0], 0.0)
	assert_almost_eq(buffer[int(0.1 * RATE)], 1.0, 0.01)
	assert_almost_eq(buffer[int(0.5 * RATE)], 0.5, 0.001)
	assert_almost_eq(buffer[int(0.9 * RATE)], 0.25, 0.01)
	assert_lt(buffer[RATE - 1], 0.001)


func test_point_envelope_interpolates_and_holds_its_ends() -> void:
	var buffer := _ones(1000)
	AudioSynth.env_points(buffer, 1000, PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.4, 1.0), Vector2(0.6, 0.5)]))

	assert_eq(buffer[100], 0.0)
	assert_almost_eq(buffer[300], 0.5, 0.01)
	assert_almost_eq(buffer[500], 0.75, 0.01)
	assert_almost_eq(buffer[900], 0.5, 0.001)


func test_edge_fades_silence_both_ends() -> void:
	var buffer := _ones(1000)
	AudioSynth.fade_edges(buffer, 1000, 0.05, 0.1)

	assert_eq(buffer[0], 0.0)
	assert_eq(buffer[999], 0.0)
	assert_eq(buffer[500], 1.0)


func test_one_pole_filters_pass_their_side_of_the_spectrum() -> void:
	var low_tone_rms := AudioSynth.rms(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 100.0))

	var low_through_low := AudioSynth.rms(AudioSynth.low_pass(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 100.0), RATE, 1000.0))
	var high_through_low := AudioSynth.rms(AudioSynth.low_pass(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 8000.0), RATE, 1000.0))
	var low_through_high := AudioSynth.rms(AudioSynth.high_pass(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 100.0), RATE, 1000.0))
	var high_through_high := AudioSynth.rms(AudioSynth.high_pass(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 8000.0), RATE, 1000.0))

	assert_gt(low_through_low, low_tone_rms * 0.85)
	assert_lt(high_through_low, low_tone_rms * 0.25)
	assert_lt(low_through_high, low_tone_rms * 0.25)
	assert_gt(high_through_high, low_tone_rms * 0.85)


func test_high_pass_removes_a_constant_offset() -> void:
	var buffer := _ones(RATE)
	AudioSynth.high_pass(buffer, RATE, 30.0)

	assert_lt(absf(buffer[RATE - 1]), 0.001)


func test_biquad_filters_select_their_band() -> void:
	var reference := AudioSynth.rms(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 1000.0))
	var kinds := {
		AudioSynth.Filter.LOW_PASS: [200.0, 6000.0],
		AudioSynth.Filter.HIGH_PASS: [6000.0, 200.0],
		AudioSynth.Filter.BAND_PASS: [1000.0, 8000.0],
	}

	for kind: AudioSynth.Filter in kinds:
		var passed := AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, kinds[kind][0])
		var stopped := AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, kinds[kind][1])
		AudioSynth.biquad(passed, RATE, kind, 1000.0, -1.0, 1.0)
		AudioSynth.biquad(stopped, RATE, kind, 1000.0, -1.0, 1.0)
		assert_gt(AudioSynth.rms(passed), reference * 0.85, "filter %d passes its band" % kind)
		assert_lt(AudioSynth.rms(stopped), reference * 0.2, "filter %d rejects the other side" % kind)


func test_swept_biquad_stays_stable_on_noise() -> void:
	var buffer := AudioSynth.white_noise(RATE, 9)
	AudioSynth.biquad(buffer, RATE, AudioSynth.Filter.BAND_PASS, 12000.0, 60.0, 4.0)

	assert_true(AudioSynth.is_all_finite(buffer))
	assert_lt(AudioSynth.peak(buffer), 4.0)


func test_saturation_bounds_hot_signals_and_keeps_full_scale() -> void:
	var buffer := AudioSynth.scale(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 220.0), 5.0)
	AudioSynth.saturate(buffer, 2.0)

	assert_true(AudioSynth.is_all_finite(buffer))
	assert_lte(AudioSynth.peak(buffer), 1.0 / tanh(2.0) + 0.0001)
	assert_almost_eq(AudioSynth.saturate(PackedFloat32Array([1.0, -1.0, 0.0]), 3.0)[0], 1.0, 0.0001)


func test_modulators_shape_amplitude() -> void:
	var wobble := _ones(RATE)
	AudioSynth.tremolo(wobble, RATE, 10.0, 0.5)
	var ring := _ones(RATE)
	AudioSynth.ring_mod(ring, RATE, 50.0)

	assert_between(_minimum(wobble), 0.49, 0.51)
	assert_between(AudioSynth.peak(wobble), 0.99, 1.0)
	assert_almost_eq(AudioSynth.dc_offset(ring), 0.0, 0.01)
	assert_between(AudioSynth.peak(ring), 0.99, 1.0)


func test_comb_and_cave_tail_ring_on_after_the_source() -> void:
	var click := AudioSynth.silence(RATE)
	click[0] = 1.0
	var comb := click.duplicate()
	AudioSynth.comb(comb, RATE, 0.01, 0.5)
	var tail := click.duplicate()
	AudioSynth.cave_tail(tail, RATE, 0.05, 0.5, 0.5)

	assert_almost_eq(comb[int(0.01 * RATE)], 0.5, 0.0001)
	assert_almost_eq(comb[int(0.01 * RATE) * 2], 0.25, 0.0001)
	assert_eq(tail[0], 1.0)
	assert_gt(AudioSynth.peak(tail.slice(100)), 0.01)
	assert_true(AudioSynth.is_all_finite(tail))
	assert_lt(absf(tail[RATE - 1]), 0.001, "the tail decays")


func test_mixing_layers_at_an_offset_and_grows_the_target() -> void:
	var target := _ones(10)
	target = AudioSynth.mix_into(target, _ones(10), 10, 0.5, 0.5)

	assert_eq(target.size(), 15)
	assert_eq(target[4], 1.0)
	assert_eq(target[5], 1.5)
	assert_eq(target[14], 0.5)
	assert_eq(AudioSynth.pad(_ones(10), 10, 0.5).size(), 15)


func test_normalization_sets_the_peak_and_keeps_silence() -> void:
	var buffer := PackedFloat32Array([0.1, -0.25, 0.05])
	AudioSynth.normalize(buffer, 0.8)
	var silent := AudioSynth.normalize(AudioSynth.silence(16), 0.8)

	assert_almost_eq(AudioSynth.peak(buffer), 0.8, 0.0001)
	assert_almost_eq(buffer[0], 0.32, 0.0001)
	assert_eq(AudioSynth.peak(silent), 0.0)
	assert_true(AudioSynth.is_all_finite(silent))
	assert_false(AudioSynth.is_all_finite(PackedFloat32Array([0.0, NAN])))


func test_measurements_and_notes() -> void:
	assert_almost_eq(AudioSynth.rms(AudioSynth.tone(RATE, RATE, AudioSynth.Wave.SINE, 100.0)), sqrt(0.5), 0.001)
	assert_almost_eq(AudioSynth.dc_offset(PackedFloat32Array([0.5, 0.5, -0.25, 0.25])), 0.25, 0.0001)
	assert_almost_eq(AudioSynth.note_hz(69.0), 440.0, 0.001)
	assert_almost_eq(AudioSynth.note_hz(81.0), 880.0, 0.001)
	assert_eq(AudioSynth.frame_count(0.5, RATE), 16000)
	assert_between(AudioSynth.hash01(3, 4), 0.0, 1.0)
	assert_eq(AudioSynth.hash01(3, 4), AudioSynth.hash01(3, 4))


func test_pcm_conversion_is_sixteen_bit_little_endian_and_clamped() -> void:
	var bytes := AudioSynth.to_pcm16(PackedFloat32Array([0.0, 1.0, -1.0, 2.0, -2.0, 0.5]))

	assert_eq(bytes.size(), 12)
	assert_eq(bytes.decode_s16(0), 0)
	assert_eq(bytes.decode_s16(2), 32767)
	assert_eq(bytes.decode_s16(4), -32767)
	assert_eq(bytes.decode_s16(6), 32767)
	assert_eq(bytes.decode_s16(8), -32767)
	assert_eq(bytes.decode_s16(10), 16384)


func test_stream_is_a_mono_sixteen_bit_one_shot() -> void:
	var stream := AudioSynth.to_stream(AudioSynth.tone(RATE / 2, RATE, AudioSynth.Wave.SINE, 440.0), RATE)

	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(stream.mix_rate, RATE)
	assert_false(stream.stereo)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq(stream.data.size(), RATE)
	assert_almost_eq(stream.get_length(), 0.5, 0.001)


func _ones(frames: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(frames)
	buffer.fill(1.0)
	return buffer


func _rising_crossings(buffer: PackedFloat32Array) -> int:
	var count := 0
	for index in range(1, buffer.size()):
		if buffer[index - 1] < 0.0 and buffer[index] >= 0.0:
			count += 1
	return count


func _non_zero_count(buffer: PackedFloat32Array) -> int:
	var count := 0
	for sample in buffer:
		if sample != 0.0:
			count += 1
	return count


func _minimum(buffer: PackedFloat32Array) -> float:
	var result := INF
	for sample in buffer:
		result = minf(result, sample)
	return result


## Share of the signal's level that survives a 4 kHz high-pass.
func _high_band_share(buffer: PackedFloat32Array) -> float:
	var total := AudioSynth.rms(buffer)
	var high := AudioSynth.rms(AudioSynth.high_pass(buffer.duplicate(), RATE, 4000.0))
	return high / total
