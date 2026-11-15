## Shared list of grapple targets that item owners register and the hook query reads.
class_name GrappleTargetRegistry
extends RefCounted


var _targets: Array[GrappleTarget] = []


func register(target: GrappleTarget) -> void:
	if target == null or _targets.has(target):
		return
	_targets.append(target)


func unregister(target: GrappleTarget) -> void:
	_targets.erase(target)


func clear() -> void:
	_targets.clear()


## Returns a copy so callers may unregister while iterating.
func targets() -> Array[GrappleTarget]:
	return _targets.duplicate()
