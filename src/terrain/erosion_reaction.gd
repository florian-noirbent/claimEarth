@tool
## Consumes a fluid and a contacted solid, replacing the fluid with a spent product.
class_name ErosionReaction
extends TerrainContactReaction


@export var spent_fluid_product: TerrainDefinition
@export var removed_solid_product: TerrainDefinition
@export_range(1, 255, 1) var solid_quantity_per_fluid_quantity := 2
@export_range(1, 255, 1) var minimum_fluid_consumed_per_contact := 1
@export_range(1, 255, 1) var maximum_fluid_consumed_per_contact := 255


func simulation_opcode() -> int:
	return OPCODE_EROSION


func product_a() -> TerrainDefinition:
	return spent_fluid_product


func product_b() -> TerrainDefinition:
	return removed_solid_product


func parameter_bytes() -> PackedByteArray:
	return PackedByteArray([
		solid_quantity_per_fluid_quantity,
		minimum_fluid_consumed_per_contact,
		maximum_fluid_consumed_per_contact,
		0,
	])


func is_bidirectional() -> bool:
	return false


func validate() -> PackedStringArray:
	var errors := super()
	if spent_fluid_product == null or removed_solid_product == null:
		errors.append("erosion requires spent-fluid and removed-solid products")
	if solid_quantity_per_fluid_quantity <= 0:
		errors.append("erosion solid-to-fluid ratio must be positive")
	if minimum_fluid_consumed_per_contact > maximum_fluid_consumed_per_contact:
		errors.append("erosion minimum consumption must not exceed its maximum")
	return errors
