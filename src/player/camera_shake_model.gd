## Pure trauma-based camera shake. Requests add trauma, the shake grows with trauma squared,
## and smooth seeded noise turns it into an offset and a roll, so the same requests always
## produce the same motion.
class_name CameraShakeModel
extends RefCounted


const NOISE_CHANNEL_SPACING := 137.0

## Offset in world px at full trauma.
var max_offset := 26.0
## Roll in radians at full trauma.
var max_rotation := deg_to_rad(1.2)
## Exponential trauma decay per second.
var trauma_decay := 3.2
## Noise wiggles per second.
var frequency := 18.0
## Share of a request's intensity that pushes the camera away from its source.
var kick_ratio := 0.6
## Exponential decay per second of that push.
var kick_decay := 14.0
## Requests closer than this to the listener shake at full strength.
var full_distance := 220.0
## Requests at or beyond this distance do not shake at all.
var zero_distance := 1500.0
## Scales every output; 0 turns shake off.
var intensity_multiplier := 1.0

var trauma := 0.0

var _noise := FastNoiseLite.new()
var _time := 0.0
var _kick := Vector2.ZERO


func _init(noise_seed: int = 1) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.seed = noise_seed


func reset() -> void:
	trauma = 0.0
	_time = 0.0
	_kick = Vector2.ZERO


## Asks for a shake whose peak offset is about intensity world px. source_offset points from
## the listener to the cause; it weakens far requests and aims the kick away from the cause.
## Vector2.INF means the cause has no place.
func add_shake(intensity: float, source_offset: Vector2 = Vector2.INF) -> void:
	if intensity <= 0.0 or max_offset <= 0.0:
		return
	var has_source := source_offset.is_finite()
	var strength := intensity * (attenuation(source_offset.length()) if has_source else 1.0)
	if strength <= 0.0:
		return
	trauma = minf(trauma + sqrt(minf(strength / max_offset, 1.0)), 1.0)
	if has_source and source_offset.length_squared() > 1.0:
		_kick = (_kick - source_offset.normalized() * strength * kick_ratio).limit_length(max_offset)


## Strength left for a request this far from the listener, from 1 down to 0.
func attenuation(distance: float) -> float:
	if distance <= full_distance:
		return 1.0
	if distance >= zero_distance:
		return 0.0
	var remaining := 1.0 - (distance - full_distance) / (zero_distance - full_distance)
	return remaining * remaining


func advance(delta: float) -> void:
	if not is_active():
		return
	_time += delta
	trauma *= exp(-trauma_decay * delta)
	_kick *= exp(-kick_decay * delta)
	if trauma < 0.01:
		trauma = 0.0
	if _kick.length_squared() < 0.0025:
		_kick = Vector2.ZERO


func is_active() -> bool:
	return trauma > 0.0 or _kick != Vector2.ZERO


## Camera offset in world px; never longer than max_offset times the multiplier.
func offset() -> Vector2:
	var shake := trauma * trauma * max_offset
	var noise_offset := Vector2(_sample(0), _sample(1)) * shake
	return (noise_offset + _kick).limit_length(max_offset) * intensity_multiplier


## Largest offset length the current trauma and kick can produce, in world px.
func offset_envelope() -> float:
	return minf(trauma * trauma * max_offset + _kick.length(), max_offset) * intensity_multiplier


## Largest roll the current trauma can produce, in radians.
func rotation_envelope() -> float:
	return trauma * trauma * max_rotation * intensity_multiplier


## Camera roll in radians.
func rotation() -> float:
	return _sample(2) * trauma * trauma * max_rotation * intensity_multiplier


func _sample(channel: int) -> float:
	return _noise.get_noise_1d(_time * frequency + channel * NOISE_CHANNEL_SPACING)
