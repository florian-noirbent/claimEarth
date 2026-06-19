class_name GenerationContext
extends RefCounted


var profile: GenerationProfile
var run_seed: int
var terrain_registry: TerrainRegistry
var world: WorldGrid
var spawn_rect := Rect2i()


func _init(
	profile_value: GenerationProfile,
	seed_value: int,
	terrain_registry_value: TerrainRegistry,
	world_value: WorldGrid
) -> void:
	profile = profile_value
	run_seed = seed_value
	terrain_registry = terrain_registry_value
	world = world_value
