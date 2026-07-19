@tool
## Replaces both contacted components with authored terrain and quantities.
class_name MutualReplacementReaction
extends TerrainContactReaction


@export var replacement_a: TerrainDefinition
@export var replacement_b: TerrainDefinition
@export_range(1, 255, 1) var replacement_a_quantity := 64
@export_range(1, 255, 1) var replacement_b_quantity := 127


func simulation_opcode() -> int:
	return OPCODE_MUTUAL_REPLACEMENT


func product_a() -> TerrainDefinition:
	return replacement_a


func product_b() -> TerrainDefinition:
	return replacement_b


func parameter_bytes() -> PackedByteArray:
	return PackedByteArray([replacement_a_quantity, replacement_b_quantity, 0, 0])


func validate() -> PackedStringArray:
	var errors := super()
	if replacement_a == null or replacement_b == null:
		errors.append("mutual replacement requires both products")
	return errors
