## Maps gameplay and UI events to audio playback without owning gameplay state.
class_name AudioDirector
extends Node


func play_throw() -> void:
	_play_tone(520.0, 0.06, 0.08)


func play_explosion(is_large: bool) -> void:
	_play_tone(150.0 if is_large else 210.0, 0.18 if is_large else 0.12, 0.18)


func play_flag_plant() -> void:
	_play_tone(720.0, 0.12, 0.12)
	_play_tone(940.0, 0.08, 0.08, 0.02)


func play_death() -> void:
	_play_tone(110.0, 0.26, 0.16)


func play_ui_confirm() -> void:
	_play_tone(860.0, 0.05, 0.08)


func _play_tone(frequency: float, duration: float, volume: float, delay := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = maxf(0.1, duration + delay + 0.05)
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.001, volume))
	add_child(player)
	player.play()
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
	var frame_count := int(stream.mix_rate * duration)
	for index in range(frame_count):
		var envelope := 1.0 - float(index) / maxf(1.0, frame_count)
		var sample: float = sin(TAU * frequency * float(index) / stream.mix_rate) * envelope
		playback.push_frame(Vector2(sample, sample))
	await get_tree().create_timer(duration + 0.1).timeout
	player.queue_free()
