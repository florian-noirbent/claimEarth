## Read-only-at-runtime modifier data compiled once when the selected perks change.
class_name PerkModifierSnapshot
extends RefCounted


var player := PerkModifierDomain.new()
var hazards := PerkModifierDomain.new()
var items := PerkModifierDomain.new()
var explosions := PerkModifierDomain.new()
var rewards := PerkModifierDomain.new()
var containers := PerkModifierDomain.new()
var presentation := PerkModifierDomain.new()
var flags := PerkModifierDomain.new()
var terrain := PerkModifierDomain.new()


func domain_for(kind: PerkModifierEffect.Domain) -> PerkModifierDomain:
	match kind:
		PerkModifierEffect.Domain.PLAYER: return player
		PerkModifierEffect.Domain.HAZARD: return hazards
		PerkModifierEffect.Domain.ITEM: return items
		PerkModifierEffect.Domain.EXPLOSION: return explosions
		PerkModifierEffect.Domain.REWARD: return rewards
		PerkModifierEffect.Domain.CONTAINER: return containers
		PerkModifierEffect.Domain.PRESENTATION: return presentation
		PerkModifierEffect.Domain.FLAG: return flags
		PerkModifierEffect.Domain.TERRAIN: return terrain
	return player


class PerkModifierDomain extends RefCounted:
	var _values: Dictionary = {}

	func value(key: String, fallback: Variant = null) -> Variant:
		return _values.get(key, fallback)

	func has(key: String) -> bool:
		return _values.has(key)

	func _set_value(key: String, value: Variant) -> void:
		_values[key] = value
