## A fixed set of AudioStreamPlayers on one bus. A sound takes an idle voice; when all
## are busy it steals the oldest voice of the lowest priority, unless every busy voice
## outranks it, in which case it is dropped. Voice lifetimes follow the injected clock.
class_name SfxVoicePool
extends Node


var _players: Array[AudioStreamPlayer] = []
var _priorities := PackedInt32Array()
var _started_msec := PackedInt64Array()
var _ends_msec := PackedInt64Array()
var _clock: Callable = Time.get_ticks_msec


## Creates the voices. clock returns milliseconds; tests pass their own.
func configure(bus: StringName, voice_count: int, clock: Callable = Callable()) -> void:
	if clock.is_valid():
		_clock = clock
	for player in _players:
		player.queue_free()
	_players.clear()
	_priorities.resize(voice_count)
	_started_msec.resize(voice_count)
	_ends_msec.resize(voice_count)
	_started_msec.fill(0)
	_ends_msec.fill(0)
	for index in range(voice_count):
		var player := AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)


func voice_count() -> int:
	return _players.size()


## Voices still sounding according to the clock.
func active_count() -> int:
	var now: int = _clock.call()
	var count := 0
	for index in range(_players.size()):
		if _ends_msec[index] > now:
			count += 1
	return count


## Starts the stream on a voice. Returns false when every voice outranks the sound.
func play(stream: AudioStream, volume_db: float, pitch_scale: float, priority: int) -> bool:
	if stream == null or _players.is_empty():
		return false
	var now: int = _clock.call()
	var index := _voice_for(priority, now)
	if index < 0:
		return false
	var player := _players[index]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	_priorities[index] = priority
	_started_msec[index] = now
	_ends_msec[index] = now + int(ceil(stream.get_length() / maxf(0.01, pitch_scale) * 1000.0))
	return true


func stop_all() -> void:
	for player in _players:
		player.stop()
	_ends_msec.fill(0)


func _voice_for(priority: int, now: int) -> int:
	var candidate := -1
	for index in range(_players.size()):
		if _ends_msec[index] <= now:
			return index
		if candidate < 0 \
				or _priorities[index] < _priorities[candidate] \
				or (_priorities[index] == _priorities[candidate] and _started_msec[index] < _started_msec[candidate]):
			candidate = index
	if candidate >= 0 and _priorities[candidate] <= priority:
		return candidate
	return -1
