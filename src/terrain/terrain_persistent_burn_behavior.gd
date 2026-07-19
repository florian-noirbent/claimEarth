@tool
## Configures the persistent product marker, consumption, and production of a terrain.
class_name TerrainPersistentBurnBehavior
extends Resource


@export var product: TerrainDefinition
@export_range(1, 255, 1) var ignition_token_quantity := 1
@export_range(1, 255, 1) var base_consumption_per_tick := 1
@export_range(0, 255, 1) var bonus_consumption := 1
@export_range(0, 255, 1) var bonus_frequency_numerator := 27
@export_range(1, 255, 1) var bonus_frequency_period := 100
@export_range(0, 255, 1) var product_per_consumed_quantity := 70
@export_range(0, 255, 1) var bonus_product_quantity := 10


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if product == null:
		errors.append("persistent burn requires a product")
	if bonus_frequency_numerator > bonus_frequency_period:
		errors.append("persistent burn bonus frequency must not exceed its period")
	return errors
