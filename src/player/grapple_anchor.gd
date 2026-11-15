## Describes a valid grapple attachment point in world space.
class_name GrappleAnchor
extends RefCounted


var cell := Vector2i(-1, -1)
## Where the hook ray made contact; a terrain anchor stays here for its lifetime.
var position := Vector2.ZERO
## Moving object the hook holds instead of terrain; null for terrain anchors.
var target: GrappleTarget
var _last_target_position := Vector2.ZERO


func _init(
	cell_value: Vector2i = Vector2i(-1, -1),
	position_value: Vector2 = Vector2.ZERO,
	target_value: GrappleTarget = null
) -> void:
	cell = cell_value
	position = position_value
	target = target_value
	_last_target_position = position_value


## Returns whether the hook holds a pullable target rather than a fixed swing point.
func is_target() -> bool:
	return target != null


## Returns the point the rope attaches to this frame, following a moving target.
## An invalidated target keeps its last valid point until the model detaches.
func current_position() -> Vector2:
	if target == null:
		return position
	if target.is_valid():
		_last_target_position = target.anchor_position()
	return _last_target_position
