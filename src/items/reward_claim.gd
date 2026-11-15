## Describes one claimed reward container: everything it offered and what was picked.
class_name RewardClaim
extends RefCounted


var container_key: StringName
## Registered item definitions offered by an item container; empty for perk containers.
var offered_items: Array[ItemDefinition] = []
var picked_item: ItemDefinition
var picked_quantity := 0
## Perks offered by a perk container; empty for item containers.
var offered_perks: Array[PerkDefinition] = []
var picked_perk: PerkDefinition
