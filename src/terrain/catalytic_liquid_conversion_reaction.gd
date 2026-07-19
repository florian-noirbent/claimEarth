@tool
## Converts a contacted liquid while consuming a smaller quantity of catalyst.
class_name CatalyticLiquidConversionReaction
extends TerrainContactReaction


@export var liquid_product: TerrainDefinition
@export_range(1, 255, 1) var liquid_quantity_per_catalyst_quantity := 10


func simulation_opcode() -> int:
	return OPCODE_CATALYTIC_LIQUID_CONVERSION


func product_b() -> TerrainDefinition:
	return liquid_product


func parameter_bytes() -> PackedByteArray:
	return PackedByteArray([liquid_quantity_per_catalyst_quantity, 0, 0, 0])


func validate() -> PackedStringArray:
	var errors := super()
	if liquid_product == null:
		errors.append("catalytic liquid conversion requires a liquid product")
	if liquid_quantity_per_catalyst_quantity <= 0:
		errors.append("catalytic liquid conversion ratio must be positive")
	return errors
