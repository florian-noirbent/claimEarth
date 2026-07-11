@tool
## Base resource contract for resolving fill-aware terrain hazards.
class_name TerrainHazardBehavior
extends Resource

const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")

@export var behavior_name := ""
@export var icon: Texture2D
@export var bar_color := Color.WHITE
@export_range(0.01, 60.0, 0.01, "or_greater") var fill_seconds := 1.0
@export_range(0.01, 60.0, 0.01, "or_greater") var recovery_seconds := 1.0
@export var display_order := 0
@export_range(0, 255, 1) var minimum_fill := 1
@export_range(0.01, 1.0, 0.01) var fill_rate_at_minimum_fill := 1.0
@export_range(0.01, 1.0, 0.01) var fill_rate_at_full_fill := 1.0


func resolve():
	return HazardEffectScript.new()


func resolve_for_fill(fill: int):
	var effect = resolve()
	if effect == null or not effect.applies_at_fill(fill):
		return null
	effect.fill_rate_multiplier = fill_rate_multiplier_for_fill(fill)
	return effect


func configure_meter(effect: HazardEffect) -> void:
	effect.icon = icon
	effect.bar_color = bar_color
	effect.fill_seconds = fill_seconds
	effect.recovery_seconds = recovery_seconds
	effect.display_order = display_order
	effect.minimum_fill = minimum_fill


func fill_rate_multiplier_for_fill(fill: int) -> float:
	var clamped_fill := clampi(fill, minimum_fill, 255)
	var range := maxi(1, 255 - minimum_fill)
	var progress := float(clamped_fill - minimum_fill) / float(range)
	return lerpf(fill_rate_at_minimum_fill, fill_rate_at_full_fill, progress)
