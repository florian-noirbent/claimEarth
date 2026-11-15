@tool
## Expands a contacted liquid into a gas at a deterministic per-second rate.
class_name BoilingReaction
extends TerrainContactReaction


@export var steam_product: TerrainDefinition
@export_range(1, 255, 1) var steam_per_water := 10
@export_range(1, 255, 1) var steam_quantity_per_second := 127


func simulation_opcode() -> int:
	return OPCODE_BOILING


func product_a() -> TerrainDefinition:
	return steam_product


func parameter_bytes() -> PackedByteArray:
	return PackedByteArray([steam_per_water, steam_quantity_per_second, 0, 0])


func is_bidirectional() -> bool:
	return false


func validate() -> PackedStringArray:
	var errors := super()
	if steam_product == null:
		errors.append("boiling requires a Steam product")
	if steam_per_water <= 0:
		errors.append("boiling Steam-per-Water ratio must be positive")
	if steam_quantity_per_second <= 0:
		errors.append("boiling speed must be positive")
	return errors
