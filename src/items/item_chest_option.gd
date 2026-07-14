@tool
## Configures one weighted item reward offered by an item chest.
class_name ItemChestOption
extends Resource


@export var item: ItemDefinition
@export_range(1, 9999, 1) var quantity := 1
@export_range(0.0, 1000.0, 0.01) var selection_weight := 1.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if item == null:
		errors.append("item chest option requires an item definition")
	if quantity <= 0:
		errors.append("item chest option quantity must be positive")
	if selection_weight < 0.0:
		errors.append("item chest option selection_weight must be non-negative")
	return errors
