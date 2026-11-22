## Draws the grappling rope and its claw, and animates launch, bite, miss, and retraction.
## It is stepped by the player presentation once per physics step and decides nothing.
class_name GrappleRopeVisual
extends Node2D


enum Phase { STOWED, LAUNCHING, HOLDING, RETRACTING }

@export_group("Rope")
## Straight pieces the rope is drawn with; more pieces curve more smoothly.
@export_range(2, 32) var rope_segments := 10
## Rope length from which the waves below reach their full height.
@export var full_wave_length := 90.0
## Sideways height of the wave that runs along the rope while the hook flies out.
@export var launch_wave_height := 5.0
@export var launch_wave_count := 1.25
## Sideways height, frequency in Hz, and decay of the shiver after the hook bites.
@export var bite_vibration_height := 3.0
@export var bite_vibration_frequency := 16.0
@export var bite_vibration_damping := 13.0
@export_group("Retraction")
## Time the hook takes to whip back to the hand after a release.
@export var release_retract_seconds := 0.12
## Time the hook takes to fall back to the hand after it found nothing to bite.
@export var miss_retract_seconds := 0.2
## How far a slack returning rope sags, as a share of the length it started from.
@export_range(0.0, 0.5) var retract_sag := 0.07
## Sideways height and count of the whip wave on a returning rope.
@export var retract_wave_height := 6.0
@export var retract_wave_count := 1.5
@export_group("Claw")
## Opening of each jaw while flying and returning, and while it holds on.
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var jaw_open_angle := 0.72
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var jaw_closed_angle := 0.1
## Frequency in Hz and decay of the snap that closes the jaws and settles the claw.
@export var bite_frequency := 9.0
@export var bite_damping := 16.0
## Extra claw size at the moment it bites, as a share of its resting size.
@export var bite_scale_punch := 0.3
## How quickly the jaws reopen once the claw lets go; higher is snappier.
@export var jaw_open_response := 40.0

@onready var rope_line: Line2D = %RopeLine
@onready var hook: Node2D = %Hook
@onready var rope_socket: Node2D = %RopeSocket
@onready var upper_jaw: Node2D = %UpperJaw
@onready var lower_jaw: Node2D = %LowerJaw

var _phase := Phase.STOWED
var _elapsed := 0.0
var _duration := 0.0
var _launch_target := Vector2.ZERO
var _anchor := Vector2.ZERO
var _hook_point := Vector2.ZERO
var _retract_from := Vector2.ZERO
var _jaw_angle := 0.0


func _ready() -> void:
	_jaw_angle = jaw_open_angle
	_stow()


func phase() -> Phase:
	return _phase


## True while the rope and claw are drawn.
func is_out() -> bool:
	return _phase != Phase.STOWED


func is_launching() -> bool:
	return _phase == Phase.LAUNCHING


## World point the hook flies toward during a launch.
func launch_target() -> Vector2:
	return _launch_target


## World point the hands should reach for while the rope is out.
func aim_target() -> Vector2:
	if _phase == Phase.LAUNCHING:
		return _launch_target
	if _phase == Phase.RETRACTING:
		return to_global(_retract_from)
	return _anchor


## Local point the claw bites at: the anchor while it holds on.
func hook_point() -> Vector2:
	return _hook_point


## Local point where the rope enters the claw.
func rope_claw_end() -> Vector2:
	return rope_line.points[0]


## Local point where the hand holds the rope.
func rope_grip_end() -> Vector2:
	return rope_line.points[rope_line.points.size() - 1]


func start_launch(target_world_position: Vector2, seconds: float) -> void:
	_phase = Phase.LAUNCHING
	_elapsed = 0.0
	_duration = maxf(seconds, 0.001)
	_launch_target = target_world_position
	_jaw_angle = jaw_open_angle


## Stops a launch in flight; a hook that already left the hand returns to it.
func cancel_launch() -> void:
	if _phase != Phase.LAUNCHING:
		return
	if rope_line.visible:
		_start_retract(release_retract_seconds)
	else:
		_stow()


## The hand lets go for good: a rope that is out falls back over the given time. Keep
## stepping it with `advance(false, ...)` and `pose` until it is no longer out.
func let_go(seconds: float) -> void:
	if _phase == Phase.STOWED or _phase == Phase.RETRACTING:
		return
	if rope_line.visible:
		_start_retract(seconds)
	else:
		_stow()


## Advances the rope's phase for this step. Call before posing the arms, then `pose`.
func advance(attached: bool, anchor_world_position: Vector2, delta: float) -> void:
	_anchor = anchor_world_position
	if _phase == Phase.LAUNCHING:
		if attached:
			# A hooked barrel keeps moving while the hook is still on its way.
			_launch_target = anchor_world_position
		_elapsed = minf(_duration, _elapsed + delta)
		if _elapsed < _duration:
			return
		if attached:
			_hold()
		else:
			_hook_point = to_local(_launch_target)
			_start_retract(miss_retract_seconds)
		return

	if attached:
		if _phase == Phase.HOLDING:
			_elapsed += delta
		else:
			_hold()
		return

	if _phase == Phase.HOLDING:
		_start_retract(release_retract_seconds)
	elif _phase == Phase.RETRACTING:
		_elapsed += delta
		if _elapsed >= _duration:
			_stow()


## Draws the rope from the hand to the claw for the current phase.
func pose(grip_world_position: Vector2, delta: float) -> void:
	if _phase == Phase.STOWED:
		return
	var grip := to_local(grip_world_position)
	var pluck := 0.0
	var wave := 0.0
	var wave_count := 1.0
	var wave_shift := 0.0
	var sag := 0.0
	var jaw_target := jaw_open_angle
	var claw_scale := 1.0
	match _phase:
		Phase.LAUNCHING:
			var progress := _elapsed / _duration
			_hook_point = grip.lerp(to_local(_launch_target), progress)
			wave = launch_wave_height * (1.0 - progress)
			wave_count = launch_wave_count
			wave_shift = -progress
		Phase.HOLDING:
			_hook_point = to_local(_anchor)
			pluck = bite_vibration_height \
				* exp(-bite_vibration_damping * _elapsed) \
				* sin(TAU * bite_vibration_frequency * _elapsed)
			var ring := exp(-bite_damping * _elapsed) * cos(TAU * bite_frequency * _elapsed)
			_jaw_angle = lerpf(jaw_closed_angle, jaw_open_angle, ring)
			jaw_target = _jaw_angle
			claw_scale = 1.0 + bite_scale_punch * ring
		Phase.RETRACTING:
			var progress := _elapsed / _duration
			# The hook starts slowly and whips in.
			_hook_point = _retract_from.lerp(grip, progress * progress)
			var slack := sin(PI * progress)
			sag = retract_sag * grip.distance_to(_retract_from) * slack
			wave = retract_wave_height * slack
			wave_count = retract_wave_count
			wave_shift = progress
	_jaw_angle = lerpf(_jaw_angle, jaw_target, 1.0 - exp(-jaw_open_response * delta))

	var span := _hook_point - grip
	var length := span.length()
	var along := span / length if length > 0.001 else Vector2.RIGHT.rotated(hook.rotation)
	var across := along.orthogonal()
	var down := global_transform.basis_xform_inv(Vector2.DOWN).normalized()
	# The rope stops where it enters the claw, behind the jaws.
	var rope_end := _hook_point - along * minf(length, absf(rope_socket.position.x))
	var fullness := minf(1.0, length / maxf(full_wave_length, 0.001))
	pluck *= fullness
	wave *= fullness

	# The rope is laid out from the claw to the hand, so its pattern travels with the claw.
	var points := PackedVector2Array()
	points.resize(rope_segments + 1)
	for index in rope_segments + 1:
		var share := float(index) / float(rope_segments)
		var bow := sin(PI * share)
		var sideways := pluck + wave * sin(TAU * (wave_count * share + wave_shift))
		points[index] = rope_end.lerp(grip, share) + (down * sag + across * sideways) * bow
	rope_line.points = points
	rope_line.visible = true

	hook.visible = true
	hook.position = _hook_point
	hook.rotation = along.angle()
	hook.scale = Vector2.ONE * claw_scale
	upper_jaw.rotation = -_jaw_angle
	lower_jaw.rotation = _jaw_angle


func _hold() -> void:
	_phase = Phase.HOLDING
	_elapsed = 0.0


func _start_retract(seconds: float) -> void:
	_phase = Phase.RETRACTING
	_elapsed = 0.0
	_duration = maxf(seconds, 0.001)
	_retract_from = _hook_point


func _stow() -> void:
	_phase = Phase.STOWED
	_elapsed = 0.0
	rope_line.visible = false
	hook.visible = false
