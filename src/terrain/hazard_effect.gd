## Describes a terrain hazard effect and its fill activation threshold.
class_name HazardEffect
extends RefCounted


var cause := &"none"
var exposure_seconds := 0.0
var lethal_on_touch := false
var minimum_fill := 1


func applies_at_fill(fill: int) -> bool:
	return fill >= minimum_fill
