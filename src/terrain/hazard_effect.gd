## Describes a player hazard and the meter it contributes to.
class_name HazardEffect
extends RefCounted


var cause := &"none"
var icon: Texture2D
var bar_color := Color.WHITE
var fill_seconds := 1.0
var recovery_seconds := 1.0
var display_order := 0
var minimum_quantity := 1
var fill_rate_multiplier := 1.0
var secondary_threshold := -1.0
var lethal_end := false


func applies_at_quantity(quantity: int) -> bool:
	return quantity >= minimum_quantity
