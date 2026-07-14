## Immutable presentation snapshot of one tracked player hazard meter.
class_name HazardStatus
extends RefCounted


var cause := &"none"
var icon: Texture2D
var bar_color := Color.WHITE
var level := 0.0
var is_active := false
var display_order := 0
var secondary_threshold := -1.0
var lethal_end := false


func _init(effect = null, level_value := 0.0, active := false) -> void:
	if effect != null:
		cause = effect.cause
		icon = effect.icon
		bar_color = effect.bar_color
		display_order = effect.display_order
		secondary_threshold = effect.secondary_threshold
		lethal_end = effect.lethal_end
	level = clampf(level_value, 0.0, 1.0)
	is_active = active
