@tool
## Base contract for one resource-authored GPU terrain-contact reaction.
class_name TerrainContactReaction
extends Resource


const OPCODE_CATALYTIC_LIQUID_CONVERSION := 1
const OPCODE_PERSISTENT_IGNITION := 2
const OPCODE_EROSION := 3
const OPCODE_GAS_ABSORPTION := 4
const OPCODE_MUTUAL_REPLACEMENT := 5

@export var reactant_a: TerrainDefinition
@export var reactant_b: TerrainDefinition


func simulation_opcode() -> int:
	return 0


func product_a() -> TerrainDefinition:
	return null


func product_b() -> TerrainDefinition:
	return null


func parameter_bytes() -> PackedByteArray:
	return PackedByteArray([0, 0, 0, 0])


func is_bidirectional() -> bool:
	return true


func referenced_terrains() -> Array[TerrainDefinition]:
	var references: Array[TerrainDefinition] = [reactant_a, reactant_b]
	if product_a() != null:
		references.append(product_a())
	if product_b() != null:
		references.append(product_b())
	return references


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if reactant_a == null or reactant_b == null:
		errors.append("contact reaction requires both reactants")
	if simulation_opcode() <= 0 or simulation_opcode() > 255:
		errors.append("contact reaction requires a valid simulation opcode")
	if parameter_bytes().size() != 4:
		errors.append("contact reaction must compile exactly four parameter bytes")
	return errors
