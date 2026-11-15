## Pure state machine choosing the player animation state and facing from body snapshots.
class_name PlayerAnimationSelector
extends RefCounted


## Horizontal speed below which a grounded body idles.
var walk_speed := 15.0
## Horizontal speed from which a grounded body runs instead of walking.
var run_speed := 170.0
## Downward speed a landing needs to play the landing crouch.
var land_speed := 260.0
var land_seconds := 0.2
## Time a grounded body may lose its footing before it counts as airborne.
var air_grace_seconds := 0.08
## Share of the body that must be in liquid to swim.
var swim_submersion := 0.5
## Horizontal speed needed to turn around; a swing needs more so it does not flip at each apex.
var turn_speed := 10.0
var swing_turn_speed := 60.0

var state: StringName = PlayerAnimationState.IDLE
## 1 when facing right, -1 when facing left.
var facing := 1.0

var _land_remaining := 0.0
var _airborne_seconds := 0.0
var _was_airborne := false
var _last_fall_speed := 0.0
var _knocked_out := false


## Advances one step. aim_side is the horizontal side of the hook target (-1, 0 for none, or 1).
func advance(snapshot: PlayerAnimationSnapshot, aim_side: float, delta: float) -> void:
	_update_facing(snapshot, aim_side)
	state = _select_state(snapshot, delta)


func _update_facing(snapshot: PlayerAnimationSnapshot, aim_side: float) -> void:
	if snapshot.ragdolling:
		return
	var required_speed := swing_turn_speed if snapshot.swinging else turn_speed
	if absf(snapshot.velocity.x) > required_speed:
		facing = signf(snapshot.velocity.x)
	elif aim_side != 0.0 and not snapshot.swinging:
		facing = signf(aim_side)


func _select_state(snapshot: PlayerAnimationSnapshot, delta: float) -> StringName:
	var landing_speed := _last_fall_speed
	_last_fall_speed = 0.0 if snapshot.grounded else maxf(0.0, snapshot.velocity.y)
	_land_remaining = maxf(0.0, _land_remaining - delta)
	_airborne_seconds = 0.0 if snapshot.grounded else _airborne_seconds + delta

	if snapshot.ragdolling:
		_knocked_out = true
		return _interrupt(PlayerAnimationState.RAGDOLL, true)
	var recovering := _knocked_out
	_knocked_out = false
	if snapshot.sand_burrowing:
		return _interrupt(PlayerAnimationState.BURROW, not snapshot.grounded)
	if snapshot.swinging and not snapshot.grounded:
		return _interrupt(PlayerAnimationState.HOOK_SWING, true)
	if snapshot.liquid_submersion >= swim_submersion and not snapshot.grounded:
		return _interrupt(PlayerAnimationState.SWIM, false)

	if not snapshot.grounded:
		var rising := snapshot.velocity.y < 0.0
		if not rising and not _was_airborne and _airborne_seconds < air_grace_seconds:
			return _ground_state(snapshot)
		_was_airborne = true
		_land_remaining = 0.0
		return PlayerAnimationState.JUMP if rising else PlayerAnimationState.FALL

	# A knocked-out body that comes to on the ground gets up through the landing crouch.
	if recovering or (_was_airborne and landing_speed >= land_speed):
		_land_remaining = land_seconds
	_was_airborne = false
	if _land_remaining > 0.0:
		return PlayerAnimationState.LAND
	return _ground_state(snapshot)


## Enters a state that overrides ground and air movement.
func _interrupt(next_state: StringName, airborne: bool) -> StringName:
	_land_remaining = 0.0
	_was_airborne = airborne
	return next_state


func _ground_state(snapshot: PlayerAnimationSnapshot) -> StringName:
	var speed := absf(snapshot.velocity.x)
	if speed < walk_speed:
		return PlayerAnimationState.IDLE
	return PlayerAnimationState.WALK if speed < run_speed else PlayerAnimationState.RUN
