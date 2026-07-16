@tool
## Base contract for one resource-authored perk contribution.
class_name PerkEffect
extends Resource


## Tags identify one semantic contribution rather than a perk.  They let a later
## effect (Glass Cannon, for example) suppress a precise contribution without
## relying on acquisition order or perk names in gameplay code.
@export var contribution_tag := ""


func cancellation_tags() -> PackedStringArray:
	return PackedStringArray()


func apply(_builder: PerkModifierBuilder) -> void:
	push_error("PerkEffect.apply must be implemented by a concrete effect")


func validate() -> PackedStringArray:
	return PackedStringArray()
