@tool
## Condenses a gas resting directly beneath a ceiling terrain into a liquid by chance.
## Reactant A is the ceiling and reactant B is the gas below it.
class_name CondensationReaction
extends TerrainContactReaction


@export var liquid_product: TerrainDefinition
## Chance per tick that a gas cell under the ceiling condenses.
@export_range(0.0, 1.0, 0.001) var condensation_chance := 0.1
## Gas quantity removed by one condensation. A cell holding less loses what it has
## and yields no liquid.
@export_range(1, 255, 1) var gas_quantity_per_condensation := 10
@export_range(1, 255, 1) var liquid_quantity_per_condensation := 1


func simulation_opcode() -> int:
	return OPCODE_CONDENSATION


func product_b() -> TerrainDefinition:
	return liquid_product


func parameter_bytes() -> PackedByteArray:
	var chance := chance_bytes(condensation_chance)
	return PackedByteArray([
		gas_quantity_per_condensation,
		liquid_quantity_per_condensation,
		chance[0],
		chance[1],
	])


func is_bidirectional() -> bool:
	return false


func validate() -> PackedStringArray:
	var errors := super()
	if liquid_product == null:
		errors.append("condensation requires a liquid product")
	if condensation_chance < 0.0 or condensation_chance > 1.0:
		errors.append("condensation chance must be between 0 and 1")
	if gas_quantity_per_condensation <= 0:
		errors.append("condensation gas quantity must be positive")
	if liquid_quantity_per_condensation <= 0:
		errors.append("condensation liquid quantity must be positive")
	return errors
