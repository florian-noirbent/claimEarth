class_name ChunkBuildResult
extends RefCounted


var chunk_coord := Vector2i.ZERO
var revision := 0
var layer_mask := TerrainLayerMask.NONE
var static_vertices := PackedVector3Array()
var static_colors := PackedColorArray()
var static_uvs := PackedVector2Array()
var static_indices := PackedInt32Array()
var sand_vertices := PackedVector3Array()
var sand_colors := PackedColorArray()
var sand_uvs := PackedVector2Array()
var sand_indices := PackedInt32Array()
var fluid_vertices := PackedVector3Array()
var fluid_colors := PackedColorArray()
var fluid_uvs := PackedVector2Array()
var fluid_indices := PackedInt32Array()
var collision_segments := PackedVector2Array()
var collision_full_rebuild := false
var collision_edge_keys := PackedInt64Array()
var collision_edge_enabled := PackedByteArray()
var collision_edge_points := PackedVector2Array()
var build_usec := 0
