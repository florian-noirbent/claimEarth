@tool
## Resource-authored terrain quantity released by a gameplay event.
class_name TerrainEmissionDefinition
extends Resource


@export var product: TerrainDefinition
@export_range(1, 65535, 1) var quantity := 1
## When enabled, the authored quantity represents a full source cell and is
## scaled by the source primary fill before it is emitted.
@export var scale_by_source_quantity := false


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if product == null:
		errors.append("terrain emission requires a product")
	if quantity <= 0:
		errors.append("terrain emission quantity must be positive")
	return errors
