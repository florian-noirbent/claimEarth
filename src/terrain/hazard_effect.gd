## Describes a player hazard and the meter it contributes to.
class_name HazardEffect
extends RefCounted


var cause := &"none"
var icon: Texture2D
var bar_color := Color.WHITE
var fill_seconds := 1.0
var recovery_seconds := 1.0
var display_order := 0
var minimum_fill := 1
var fill_rate_multiplier := 1.0


func applies_at_fill(fill: int) -> bool:
	return fill >= minimum_fill
