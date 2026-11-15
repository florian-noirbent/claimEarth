@tool
## Resource-driven thresholds that decide which runs count as games and victories.
class_name StatisticsRules
extends Resource


## A run counts as a played game only when the player reached at least this depth.
@export_range(0, 4096, 1) var minimum_game_depth := 30
## A planted flag is a victory when it lands at or below this fraction of the world
## depth, inside the fully filled lava core at the bottom of the map.
@export_range(0.0, 1.0, 0.001) var victory_depth_ratio := 0.95


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if minimum_game_depth < 0:
		errors.append("statistics minimum_game_depth must be non-negative")
	if victory_depth_ratio <= 0.0 or victory_depth_ratio > 1.0:
		errors.append("statistics victory_depth_ratio must be greater than zero and at most one")
	return errors


func victory_depth(world_depth: int) -> int:
	return ceili(float(maxi(world_depth, 0)) * victory_depth_ratio)
