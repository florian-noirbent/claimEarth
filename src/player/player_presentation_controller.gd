## Owns the editor-authored player visuals and their transient animation state.
class_name PlayerPresentationController
extends Node2D


@export var hook_launch_animation_seconds := 0.08
@export_group("Animation")
## Horizontal speed below which the grounded body idles.
@export var walk_speed := 15.0
## Horizontal speed from which the grounded body runs instead of walking.
@export var run_speed := 170.0
## Downward speed a landing needs to play the landing crouch.
@export var land_speed := 260.0
@export var land_seconds := 0.2
## How far the body leans along the rope while swinging, as a share of the rope angle.
@export_range(0.0, 1.0) var swing_lean := 0.6
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var maximum_swing_lean := 0.8
## How quickly the body settles onto its lean; higher is snappier.
@export var lean_response := 14.0
@export_group("Ragdoll")
## Distance a knocked-out body travels along the ground per radian it rolls.
@export var ragdoll_roll_radius := 16.0
## Ground speed below which a knocked-out body stops rolling and lies flat.
@export var ragdoll_rest_speed := 45.0
## How quickly the tumble follows flight and rolling; higher is snappier.
@export var ragdoll_spin_response := 7.0
## How quickly a resting body drops flat onto the ground; higher is snappier.
@export var ragdoll_settle_response := 12.0
## How far the body sinks to rest on the ground when lying on its front and on its back.
@export var ragdoll_front_rest_offset := 7.0
@export var ragdoll_back_rest_offset := 3.0

@onready var body_visual: Node2D = %BodyVisual
@onready var rig: PlayerRig = %Rig
@onready var sand_outline: Line2D = %SandOutline
@onready var rope_line: Line2D = %RopeLine
@onready var hook_indicator: Polygon2D = %HookIndicator

var _selector := PlayerAnimationSelector.new()
var _hook_launch_elapsed := 0.0
var _hook_launch_duration := 0.0
var _hook_launch_target := Vector2.ZERO
var _grapple_attached := false
var _grapple_anchor := Vector2.ZERO
var _was_ragdolling := false
var _spin_velocity := 0.0


func _ready() -> void:
	_selector.walk_speed = walk_speed
	_selector.run_speed = run_speed
	_selector.land_speed = land_speed
	_selector.land_seconds = land_seconds


func animation_state() -> StringName:
	return _selector.state


func update_body(snapshot: PlayerAnimationSnapshot, delta: float) -> void:
	_selector.advance(snapshot, _aim_side(), delta)
	rig.play_state(_selector.state)
	rig.scale.x = absf(rig.scale.x) * _selector.facing
	rig.advance(delta)

	var rest_offset := 0.0
	var lying := snapshot.ragdolling and _is_resting(snapshot)
	if snapshot.ragdolling:
		rest_offset = _tumble(snapshot, lying, delta)
	else:
		var lean := 0.0
		if _selector.state == PlayerAnimationState.HOOK_SWING and _grapple_attached:
			var rope_angle := (_grapple_anchor - global_position).angle() + PI * 0.5
			lean = clampf(wrapf(rope_angle, -PI, PI) * swing_lean, -maximum_swing_lean, maximum_swing_lean)
		body_visual.rotation = lerp_angle(body_visual.rotation, lean, 1.0 - exp(-lean_response * delta))
		_spin_velocity = 0.0
	_was_ragdolling = snapshot.ragdolling
	body_visual.position.y = lerpf(
		body_visual.position.y,
		rest_offset,
		1.0 - exp(-ragdoll_settle_response * delta)
	)
	rig.update_ragdoll(snapshot.ragdolling, lying, snapshot.velocity, _spin_velocity, delta)


## True when a knocked-out body has stopped rolling and lies on the ground.
func _is_resting(snapshot: PlayerAnimationSnapshot) -> bool:
	return snapshot.grounded and absf(snapshot.velocity.x) < ragdoll_rest_speed


## Turns a knocked-out body: it spins in flight, rolls along the ground, and drops
## flat once it slows down. Returns how far the body should sink to rest on the ground.
func _tumble(snapshot: PlayerAnimationSnapshot, lying: bool, delta: float) -> float:
	var flight_spin := snapshot.ragdoll_spin_direction * snapshot.ragdoll_spin_speed
	if not _was_ragdolling:
		_spin_velocity = flight_spin
	if not lying:
		var spin := flight_spin
		if snapshot.grounded:
			spin = snapshot.velocity.x / maxf(ragdoll_roll_radius, 0.001)
		_spin_velocity = lerpf(_spin_velocity, spin, 1.0 - exp(-ragdoll_spin_response * delta))
		body_visual.rotation += _spin_velocity * delta
		return 0.0

	# The body falls on over in the direction it was turning, onto its front or its back.
	var half_turns := (body_visual.rotation - PI * 0.5) / PI
	# A body already close to flat settles back instead of rolling over once more.
	var steps := floorf(half_turns + 0.15)
	if snapshot.ragdoll_spin_direction >= 0.0:
		steps = ceilf(half_turns - 0.15)
	var flat := steps * PI + PI * 0.5
	var rotation_before := body_visual.rotation
	body_visual.rotation = lerpf(rotation_before, flat, 1.0 - exp(-ragdoll_settle_response * delta))
	_spin_velocity = (body_visual.rotation - rotation_before) / delta if delta > 0.0 else 0.0
	var front_down := sin(flat) * _selector.facing > 0.0
	return ragdoll_front_rest_offset if front_down else ragdoll_back_rest_offset


func start_hook_launch(target_world_position: Vector2) -> void:
	_hook_launch_elapsed = 0.0
	_hook_launch_duration = maxf(hook_launch_animation_seconds, 0.001)
	_hook_launch_target = target_world_position


func cancel_hook_launch() -> void:
	_hook_launch_elapsed = 0.0
	_hook_launch_duration = 0.0


func update_grapple(
	attached: bool,
	anchor_world_position: Vector2,
	delta: float
) -> void:
	_grapple_attached = attached
	_grapple_anchor = anchor_world_position
	if _hook_launch_duration > 0.0:
		_hook_launch_elapsed = minf(
			_hook_launch_duration,
			_hook_launch_elapsed + delta
		)
		var progress := _hook_launch_elapsed / _hook_launch_duration
		_show_rope(to_local(_hook_launch_target) * progress)
		if _hook_launch_elapsed < _hook_launch_duration:
			rig.update_aim(true, _hook_launch_target, delta)
			return
		cancel_hook_launch()

	if not attached:
		rig.update_aim(false, Vector2.ZERO, delta)
		rope_line.visible = false
		hook_indicator.visible = false
		return

	# A swinging body turns around often, so its hands hold the rope on the center line.
	rig.update_aim(true, anchor_world_position, delta, _selector.state == PlayerAnimationState.HOOK_SWING)
	_show_rope(to_local(anchor_world_position))


func set_sand_burrow_visible(visible: bool) -> void:
	sand_outline.visible = visible


## Draws the rope from the near hand to a point in local space.
func _show_rope(local_end: Vector2) -> void:
	rope_line.visible = true
	hook_indicator.visible = true
	rope_line.points = PackedVector2Array([
		to_local(rig.grip_position()),
		local_end,
	])
	hook_indicator.position = local_end


## Returns which side the hook pulls toward: -1, 1, or 0 with no hook out.
func _aim_side() -> float:
	if _hook_launch_duration > 0.0:
		return signf(_hook_launch_target.x - global_position.x)
	if _grapple_attached:
		return signf(_grapple_anchor.x - global_position.x)
	return 0.0
