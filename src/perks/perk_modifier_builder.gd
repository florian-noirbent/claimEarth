## Internal compiler for deterministic, order-independent perk modifier snapshots.
class_name PerkModifierBuilder
extends RefCounted


var _snapshot := PerkModifierSnapshot.new()


func apply_contribution(domain_kind: PerkModifierEffect.Domain, key: String, operation: PerkModifierEffect.Operation, value: float) -> void:
	var domain := _snapshot.domain_for(domain_kind)
	var current: Variant = domain.value(key, _default_for(operation))
	match operation:
		PerkModifierEffect.Operation.ADD:
			domain._set_value(key, float(current) + value)
		PerkModifierEffect.Operation.MULTIPLY:
			domain._set_value(key, float(current) * value)
		PerkModifierEffect.Operation.SET:
			domain._set_value(key, value)


func build() -> PerkModifierSnapshot:
	return _snapshot


func _default_for(operation: PerkModifierEffect.Operation) -> Variant:
	return 1.0 if operation == PerkModifierEffect.Operation.MULTIPLY else 0.0
