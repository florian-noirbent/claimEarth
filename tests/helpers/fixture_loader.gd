class_name FixtureLoader
extends RefCounted


static func terrain_catalog() -> TerrainCatalog:
	return load("res://config/terrain/catalog.tres") as TerrainCatalog


static func item_catalog() -> ItemCatalog:
	return load("res://config/items/catalog.tres") as ItemCatalog
