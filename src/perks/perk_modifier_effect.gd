@tool
## A typed scalar/flag contribution to one runtime perk modifier domain.
class_name PerkModifierEffect
extends PerkEffect


enum Domain {
	PLAYER,
	HAZARD,
	ITEM,
	EXPLOSION,
	REWARD,
	CONTAINER,
	PRESENTATION,
	FLAG,
	TERRAIN,
}

enum Operation {
	ADD,
	MULTIPLY,
	SET,
}

@export var domain := Domain.PLAYER
@export var modifier_key := ""
@export var operation := Operation.ADD
@export var value := 0.0


func apply(builder: PerkModifierBuilder) -> void:
	builder.apply_contribution(domain, modifier_key, operation, value)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if modifier_key.is_empty():
		errors.append("perk modifier effect requires modifier_key")
	if not is_finite(value):
		errors.append("perk modifier effect value must be finite")
	return errors
