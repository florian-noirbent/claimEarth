## Reports a completed terrain simulation commit and its dirty region.
class_name SimulationCommit
extends RefCounted


var dirty_rect := Rect2i()
var did_commit := false
var change_set: TerrainChangeSet
var revision := 0


func changed_cell_count() -> int:
	return change_set.changed_cell_count() if change_set != null else 0
