## Carries chunk mesh output back to the presenter.
class_name ChunkBuildResult
extends RefCounted


var chunk_coord := Vector2i.ZERO
var revision := 0
var layer_mask := TerrainLayerMask.NONE
var static_vertices := PackedVector3Array()
var static_colors := PackedColorArray()
var static_uvs := PackedVector2Array()
var static_indices := PackedInt32Array()
var static_material_meshes := {}
var static_edge_meshes := {}
var sand_vertices := PackedVector3Array()
var sand_colors := PackedColorArray()
var sand_uvs := PackedVector2Array()
var sand_indices := PackedInt32Array()
var fluid_vertices := PackedVector3Array()
var fluid_colors := PackedColorArray()
var fluid_uvs := PackedVector2Array()
var fluid_indices := PackedInt32Array()
var build_usec := 0
