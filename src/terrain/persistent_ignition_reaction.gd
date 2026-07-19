@tool
## Starts the persistent-burn behavior authored by the first reactant.
class_name PersistentIgnitionReaction
extends TerrainContactReaction


func simulation_opcode() -> int:
	return OPCODE_PERSISTENT_IGNITION


func validate() -> PackedStringArray:
	var errors := super()
	if reactant_a != null and reactant_a.persistent_burn_behavior == null:
		errors.append("persistent ignition requires the first reactant to define persistent burn behavior")
	return errors
