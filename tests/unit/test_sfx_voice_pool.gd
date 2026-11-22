extends GutTest

var _now_msec := 0
var _pool: SfxVoicePool
var _stream: AudioStreamWAV


func before_each() -> void:
	_now_msec = 1000
	_stream = AudioSynth.to_stream(AudioSynth.silence(16000), 32000)
	_pool = SfxVoicePool.new()
	add_child_autofree(_pool)
	_pool.configure(&"SFX", 3, func() -> int: return _now_msec)


func test_voices_are_created_on_the_requested_bus() -> void:
	assert_eq(_pool.voice_count(), 3)
	assert_eq(_pool.get_child_count(), 3)
	for player: AudioStreamPlayer in _pool.get_children():
		assert_eq(player.bus, &"SFX")


func test_polyphony_never_exceeds_the_voice_count() -> void:
	for index in range(10):
		assert_true(_pool.play(_stream, -6.0, 1.0, 5))
		_now_msec += 1

	assert_eq(_pool.active_count(), 3)


func test_voice_is_free_again_when_its_sound_has_ended() -> void:
	_pool.play(_stream, -6.0, 1.0, 5)
	assert_eq(_pool.active_count(), 1)

	_now_msec += 499
	assert_eq(_pool.active_count(), 1)
	_now_msec += 2
	assert_eq(_pool.active_count(), 0)


func test_pitch_shortens_or_lengthens_the_voice_lifetime() -> void:
	_pool.play(_stream, -6.0, 2.0, 5)

	_now_msec += 251
	assert_eq(_pool.active_count(), 0)


func test_busy_pool_steals_the_oldest_voice_of_the_lowest_priority() -> void:
	_pool.play(_stream, -1.0, 1.0, 8)
	_now_msec += 1
	_pool.play(_stream, -2.0, 1.0, 2)
	_now_msec += 1
	_pool.play(_stream, -3.0, 1.0, 2)
	_now_msec += 1

	assert_true(_pool.play(_stream, -4.0, 1.0, 5))

	assert_eq(_volumes(), [-1.0, -4.0, -3.0])


func test_sound_is_dropped_when_every_voice_outranks_it() -> void:
	for index in range(3):
		_pool.play(_stream, -1.0, 1.0, 8)

	assert_false(_pool.play(_stream, -9.0, 1.0, 3))
	assert_eq(_volumes(), [-1.0, -1.0, -1.0])
	assert_true(_pool.play(_stream, -9.0, 1.0, 8), "equal priority may steal")


func test_missing_stream_and_stop_all() -> void:
	assert_false(_pool.play(null, 0.0, 1.0, 5))
	_pool.play(_stream, -6.0, 1.0, 5)

	_pool.stop_all()

	assert_eq(_pool.active_count(), 0)


func _volumes() -> Array:
	var result := []
	for player: AudioStreamPlayer in _pool.get_children():
		result.append(player.volume_db)
	return result
