## Plain mesh arrays for one chunk visual batch.
class_name ChunkMeshArrays
extends RefCounted


var vertices: Array[Vector3] = []
var colors: Array[Color] = []
var uvs: Array[Vector2] = []
var indices: Array[int] = []


func vertex_count() -> int:
	return vertices.size()


func to_vertices() -> PackedVector3Array:
	return PackedVector3Array(vertices)


func to_colors() -> PackedColorArray:
	return PackedColorArray(colors)


func to_uvs() -> PackedVector2Array:
	return PackedVector2Array(uvs)


func to_indices() -> PackedInt32Array:
	return PackedInt32Array(indices)
