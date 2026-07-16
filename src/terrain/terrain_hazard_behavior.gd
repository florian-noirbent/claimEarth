@tool
## Base resource contract for resolving quantity-aware terrain hazards.
class_name TerrainHazardBehavior
extends Resource

const HazardEffectScript = preload("res://src/terrain/hazard_effect.gd")

@export var behavior_name := ""
@export var icon: Texture2D
@export var bar_color := Color.WHITE
@export_range(0.01, 60.0, 0.01, "or_greater") var fill_seconds := 1.0
@export_range(0.01, 60.0, 0.01, "or_greater") var recovery_seconds := 1.0
@export var display_order := 0
@export_range(0, 255, 1) var minimum_quantity := 1
@export_range(0.01, 1.0, 0.01) var quantity_rate_at_minimum := 1.0
@export_range(0.01, 1.0, 0.01) var quantity_rate_at_full := 1.0


func resolve():
	return HazardEffectScript.new()


func resolve_for_quantity(quantity: int):
	var effect = resolve()
	if effect == null or not effect.applies_at_quantity(quantity):
		return null
	effect.fill_rate_multiplier = quantity_rate_multiplier(quantity)
	return effect


func configure_meter(effect: HazardEffect) -> void:
	effect.icon = icon
	effect.bar_color = bar_color
	effect.fill_seconds = fill_seconds
	effect.recovery_seconds = recovery_seconds
	effect.display_order = display_order
	effect.minimum_quantity = minimum_quantity


func quantity_rate_multiplier(quantity: int) -> float:
	var clamped_quantity := clampi(quantity, minimum_quantity, 127)
	var range := maxi(1, 127 - minimum_quantity)
	var progress := float(clamped_quantity - minimum_quantity) / float(range)
	return lerpf(quantity_rate_at_minimum, quantity_rate_at_full, progress)
