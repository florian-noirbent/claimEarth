class_name FixtureLoader
extends RefCounted


static func terrain_catalog() -> TerrainCatalog:
	return load("res://config/terrain/catalog.tres") as TerrainCatalog


static func item_catalog() -> ItemCatalog:
	return load("res://config/items/catalog.tres") as ItemCatalog


static func terrain_registry() -> TerrainRegistry:
	var registry := TerrainRegistry.new()
	registry.try_configure(terrain_catalog())
	return registry


static func terrain_definition_named(display_name: String) -> TerrainDefinition:
	var registry := terrain_registry()
	for definition in registry.all_definitions():
		if definition.display_name == display_name:
			return definition
	return null


static func terrain_id(display_name: String) -> int:
	var definition := terrain_definition_named(display_name)
	return definition.stable_id if definition != null else -1
