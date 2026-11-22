@tool
## Base contract for one resource-authored GPU terrain-contact reaction.
class_name TerrainContactReaction
extends Resource


const OPCODE_CATALYTIC_LIQUID_CONVERSION := 1
const OPCODE_PERSISTENT_IGNITION := 2
const OPCODE_EROSION := 3
const OPCODE_GAS_ABSORPTION := 4
const OPCODE_MUTUAL_REPLACEMENT := 5
const OPCODE_BOILING := 6
const OPCODE_CONDENSATION := 7
## A compiled chance is a 16-bit fraction of this value, so 1.0 always succeeds.
const CHANCE_SCALE := 65535

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


## Low and high byte of a 0-1 chance for the simulation's deterministic chance roll.
static func chance_bytes(chance: float) -> PackedByteArray:
	var scaled := roundi(clampf(chance, 0.0, 1.0) * CHANCE_SCALE)
	return PackedByteArray([scaled & 255, scaled >> 8])


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
