@tool
## Expands a contacted liquid into a gas at a deterministic per-second rate. Each time
## the heat source boils the liquid it may solidify into an authored product.
class_name BoilingReaction
extends TerrainContactReaction


@export var steam_product: TerrainDefinition
@export_range(1, 255, 1) var steam_per_water := 10
@export_range(1, 255, 1) var steam_quantity_per_second := 127
## Terrain that replaces the heat source (reactant B) when it solidifies. Leave empty
## to keep the heat source unchanged.
@export var heat_source_solidified_product: TerrainDefinition
## Chance per tick that the heat source solidifies while it boils a liquid cell.
@export_range(0.0, 1.0, 0.001) var heat_source_solidify_chance := 0.0


func simulation_opcode() -> int:
	return OPCODE_BOILING


func product_a() -> TerrainDefinition:
	return steam_product


func product_b() -> TerrainDefinition:
	return heat_source_solidified_product


func parameter_bytes() -> PackedByteArray:
	var chance := chance_bytes(heat_source_solidify_chance if heat_source_solidified_product != null else 0.0)
	return PackedByteArray([steam_per_water, steam_quantity_per_second, chance[0], chance[1]])


## Both pair orders compile so the heat source can solidify on either side of a pair.
## Only reactant A boils.
func is_bidirectional() -> bool:
	return true


func validate() -> PackedStringArray:
	var errors := super()
	if steam_product == null:
		errors.append("boiling requires a Steam product")
	if steam_per_water <= 0:
		errors.append("boiling Steam-per-Water ratio must be positive")
	if steam_quantity_per_second <= 0:
		errors.append("boiling speed must be positive")
	if heat_source_solidify_chance < 0.0 or heat_source_solidify_chance > 1.0:
		errors.append("boiling heat-source solidify chance must be between 0 and 1")
	if heat_source_solidify_chance > 0.0 and heat_source_solidified_product == null:
		errors.append("boiling heat-source solidify chance requires a solidified product")
	return errors
