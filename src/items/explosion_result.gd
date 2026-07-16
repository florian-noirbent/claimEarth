## Complete outcome of one explosion, including non-terrain chain-reaction reach.
class_name ExplosionResult
extends RefCounted


var terrain_changes: TerrainChangeSet
## Cells that vaporize terrain and can arm another explosive.
var destructive_core_cells: Array[Vector2i] = []

## Compatibility alias. New code should use destructive_core_cells: a player kill
## radius may differ and is not a chain-reaction footprint.
var lethal_cells: Array[Vector2i] = []


func _init(changes: TerrainChangeSet = null, cells: Array[Vector2i] = []) -> void:
	terrain_changes = changes
	destructive_core_cells = cells
	lethal_cells = destructive_core_cells
