@tool
## Describes one directed terrain-contact reaction for the packed simulator.
class_name TerrainContactReaction
extends Resource


enum Kind {
	SULFUR_WATER,
	SULFUR_LAVA,
	ACID_SAND,
	GAS_WATER,
	WATER_LAVA,
}


@export var reactant_a: TerrainDefinition
@export var reactant_b: TerrainDefinition
@export var product_a: TerrainDefinition
@export var product_b: TerrainDefinition
@export var generated_product: TerrainDefinition
@export_enum("Sulfur Water", "Sulfur Lava", "Acid Sand", "Gas Water", "Water Lava") var kind: int = Kind.SULFUR_WATER
@export_range(0.0, 120.0, 0.1) var duration_seconds := 0.0
@export_range(0, 255, 1) var input_a_units := 1
@export_range(0, 255, 1) var input_b_units := 0
@export_range(0, 255, 1) var output_units := 0
@export var persistent_ignition := false


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if reactant_a == null or reactant_b == null:
		errors.append("contact reaction requires both reactants")
	if kind == Kind.SULFUR_LAVA and (generated_product == null or not persistent_ignition):
		errors.append("sulfur-lava reaction requires a persistent generated product")
	return errors
