@tool
## Suppresses semantic contributions supplied by any selected perk.
class_name PerkCancellationEffect
extends PerkEffect


@export var cancelled_contribution_tags := PackedStringArray()


func cancellation_tags() -> PackedStringArray:
	return cancelled_contribution_tags


func apply(_builder: PerkModifierBuilder) -> void:
	pass


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if cancelled_contribution_tags.is_empty():
		errors.append("perk cancellation effect requires at least one contribution tag")
	return errors
