@tool
## Absorbs a gas into a contacted liquid and replaces that liquid with a product.
class_name GasAbsorptionReaction
extends TerrainContactReaction


@export var absorbed_product: TerrainDefinition
@export_range(1, 255, 1) var minimum_gas_quantity := 3
@export_range(1, 255, 1) var maximum_gas_consumed_per_contact := 63
@export_range(1, 255, 1) var gas_input_quantity := 189
@export_range(1, 255, 1) var product_output_quantity := 127


func simulation_opcode() -> int:
	return OPCODE_GAS_ABSORPTION


func product_b() -> TerrainDefinition:
	return absorbed_product


func parameter_bytes() -> PackedByteArray:
	return PackedByteArray([
		minimum_gas_quantity,
		maximum_gas_consumed_per_contact,
		gas_input_quantity,
		product_output_quantity,
	])


func validate() -> PackedStringArray:
	var errors := super()
	if absorbed_product == null:
		errors.append("gas absorption requires a liquid product")
	if minimum_gas_quantity > maximum_gas_consumed_per_contact:
		errors.append("gas absorption minimum quantity must not exceed its contact maximum")
	return errors
