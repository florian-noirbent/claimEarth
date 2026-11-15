## A moving world object the grapple hook can attach to and pull, without the player knowing its type.
class_name GrappleTarget
extends RefCounted


## Returns whether the target can still hold a hook; an invalid target detaches it.
func is_valid() -> bool:
	return false


## Returns the world position the rope attaches to.
func anchor_position() -> Vector2:
	return Vector2.ZERO


## Returns the radius of the circle the hook ray must hit.
func radius() -> float:
	return 0.0


## Pulls the target toward a point when the rope is overstretched by the given distance.
func pull_toward(_point: Vector2, _overshoot: float, _delta: float) -> void:
	pass
