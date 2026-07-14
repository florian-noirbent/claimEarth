## Complete outcome of one explosion, including non-terrain chain-reaction reach.
class_name ExplosionResult
extends RefCounted


var terrain_changes: TerrainChangeSet
var lethal_cells: Array[Vector2i] = []


func _init(changes: TerrainChangeSet = null, cells: Array[Vector2i] = []) -> void:
	terrain_changes = changes
	lethal_cells = cells
