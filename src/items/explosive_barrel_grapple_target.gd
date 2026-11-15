## Lets the grapple hook attach to and pull an explosive barrel without the player knowing its type.
class_name ExplosiveBarrelGrappleTarget
extends GrappleTarget


var _barrel_ref: WeakRef


func _init(barrel: ExplosiveBarrel = null) -> void:
	_barrel_ref = weakref(barrel) if barrel != null else null


## Returns the barrel while it exists and has not detonated, otherwise null.
func barrel() -> ExplosiveBarrel:
	var target := _barrel_ref.get_ref() as ExplosiveBarrel if _barrel_ref != null else null
	return target if target != null and target.is_inside_tree() and target.is_live() else null


func is_valid() -> bool:
	return barrel() != null


func anchor_position() -> Vector2:
	var target := barrel()
	return target.global_position if target != null else Vector2.ZERO


func radius() -> float:
	var target := barrel()
	return target.body_radius() if target != null else 0.0


func pull_toward(point: Vector2, overshoot: float, delta: float) -> void:
	var target := barrel()
	if target != null:
		target.pull_toward(point, overshoot, delta)
