extends GutTest

const RATE := 32000
const MAX_SECONDS := 3.0


func test_every_sound_renders_clean_bounded_samples() -> void:
	var ids := SfxRecipes.ids()
	assert_gt(ids.size(), 50)

	for id in ids:
		var buffer := SfxRecipes.render(id, RATE)
		assert_gt(buffer.size(), 0, "%s renders samples" % id)
		assert_lte(float(buffer.size()) / RATE, MAX_SECONDS, "%s stays short" % id)
		assert_true(AudioSynth.is_all_finite(buffer), "%s has no NaN" % id)
		assert_almost_eq(AudioSynth.peak(buffer), SfxRecipes.RENDER_PEAK, 0.001, "%s is normalized with headroom" % id)
		assert_lt(absf(AudioSynth.dc_offset(buffer)), 0.005, "%s has no DC offset" % id)
		assert_lt(absf(buffer[0]), 0.01, "%s starts without a click" % id)
		assert_lt(absf(buffer[buffer.size() - 1]), 0.01, "%s ends without a click" % id)
		assert_eq(AudioSynth.to_pcm16(buffer).size(), buffer.size() * 2, "%s converts to 16-bit PCM" % id)


func test_rendering_is_deterministic() -> void:
	for id: StringName in [&"explosion_small", &"hook_attach", &"bottle_burst", &"flag_plant"]:
		assert_eq(SfxRecipes.render(id, RATE), SfxRecipes.render(id, RATE), "%s renders the same twice" % id)


func test_sound_length_follows_the_mix_rate() -> void:
	var full := SfxRecipes.render(&"hook_attach", RATE)
	var half := SfxRecipes.render(&"hook_attach", RATE / 2)

	assert_almost_eq(float(half.size()) / float(full.size()), 0.5, 0.01)


func test_large_explosion_is_longer_and_lower_than_small() -> void:
	var small := SfxRecipes.render(&"explosion_small", RATE)
	var large := SfxRecipes.render(&"explosion_large", RATE)

	assert_gt(large.size(), int(small.size() * 1.5))
	assert_lt(_brightness(large), _brightness(small))
	assert_gt(_tail_level(large), _tail_level(small) * 2.0, "the large blast still rumbles after half a second")


func test_heavy_landing_carries_more_energy_than_soft() -> void:
	var soft := SfxRecipes.render(&"land_soft", RATE)
	var heavy := SfxRecipes.render(&"land_heavy", RATE)

	assert_gt(_energy(heavy), _energy(soft) * 1.5)


func test_unknown_sound_renders_empty() -> void:
	assert_false(SfxRecipes.has(&"missing_sound"))
	assert_eq(SfxRecipes.render(&"missing_sound", RATE).size(), 0)


func test_bank_renders_each_sound_once_and_prewarms_its_queue() -> void:
	var bank := SfxBank.new(RATE)
	bank.queue([&"ui_hover", &"ui_press", &"missing_sound", &"ui_hover"])

	assert_eq(bank.pending_count(), 3)
	assert_false(bank.is_rendered(&"ui_hover"))
	var first := bank.stream(&"ui_hover")
	assert_same(bank.stream(&"ui_hover"), first)
	assert_eq(bank.pending_count(), 2)
	assert_eq(first.data.size(), SfxRecipes.render(&"ui_hover", RATE).size() * 2)

	var remaining := true
	var steps := 0
	while remaining and steps < 10:
		remaining = bank.prewarm_step(0.0)
		steps += 1

	assert_eq(steps, 2, "a zero budget still renders one queued sound per step")
	assert_eq(bank.rendered_count(), 2)
	assert_null(bank.stream(&"missing_sound"))
	assert_eq(bank.byte_count(), first.data.size() + bank.stream(&"ui_press").data.size())
	assert_gt(bank.render_msec(), 0.0)


## Rising zero crossings per second: a cheap measure of how bright a sound is.
func _brightness(buffer: PackedFloat32Array) -> float:
	var count := 0
	for index in range(1, buffer.size()):
		if buffer[index - 1] < 0.0 and buffer[index] >= 0.0:
			count += 1
	return float(count) * RATE / float(buffer.size())


func _tail_level(buffer: PackedFloat32Array) -> float:
	return AudioSynth.rms(buffer.slice(RATE / 2))


func _energy(buffer: PackedFloat32Array) -> float:
	var level := AudioSynth.rms(buffer)
	return level * level * buffer.size()
