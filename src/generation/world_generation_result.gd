## Carries generated world data, dimensions, spawn, and final seed.
class_name WorldGenerationResult
extends RefCounted


var world: WorldGrid
var final_seed := 0
var attempts := 0
var spawn_rect := Rect2i()
var item_chest_spawns: Array[GeneratedItemChestSpawn] = []
var perk_geode_spawns: Array[GeneratedItemChestSpawn] = []
var world_hash := 0
