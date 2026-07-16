@tool
## Editor-facing registry of the generated item definitions that a pass can place.
class_name GeneratedItemPlacementCatalog
extends Resource


@export var definitions: Array[GeneratedItemPlacementDefinition] = []
