## Owns static, sand, and fluid mesh layers for one visible chunk.
class_name WorldChunkRenderer
extends Node2D


var chunk_coord := Vector2i.ZERO
var chunk_rect := Rect2i()
var _static_mesh := MeshInstance2D.new()
var _sand_mesh := MeshInstance2D.new()
var _fluid_mesh := MeshInstance2D.new()


func _ready() -> void:
	if _static_mesh.get_parent() == null:
		add_child(_static_mesh)
		add_child(_sand_mesh)
		add_child(_fluid_mesh)
		_static_mesh.material = _make_material(0)
		_sand_mesh.material = _make_material(1)
		_fluid_mesh.material = _make_material(2)


func configure(chunk_coord_value: Vector2i, chunk_rect_value: Rect2i) -> void:
	chunk_coord = chunk_coord_value
	chunk_rect = chunk_rect_value


func apply_result(result: ChunkBuildResult) -> void:
	if (result.layer_mask & TerrainLayerMask.STATIC_VISUAL) != 0:
		_static_mesh.mesh = _create_mesh(result.static_vertices, result.static_colors, result.static_uvs, result.static_indices)
	if (result.layer_mask & TerrainLayerMask.SAND_VISUAL) != 0:
		_sand_mesh.mesh = _create_mesh(result.sand_vertices, result.sand_colors, result.sand_uvs, result.sand_indices)
	if (result.layer_mask & TerrainLayerMask.FLUID_VISUAL) != 0:
		_fluid_mesh.mesh = _create_mesh(result.fluid_vertices, result.fluid_colors, result.fluid_uvs, result.fluid_indices)


func layer_vertex_count(layer_mask: int) -> int:
	var vertices := _layer_vertices(layer_mask)
	return vertices.size()


func layer_min_vertex_y(layer_mask: int) -> float:
	var vertices := _layer_vertices(layer_mask)
	if vertices.is_empty():
		return INF
	var min_y := vertices[0].y
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
	return min_y


func _layer_vertices(layer_mask: int) -> PackedVector3Array:
	var instance := _static_mesh
	if layer_mask == TerrainLayerMask.SAND_VISUAL:
		instance = _sand_mesh
	elif layer_mask == TerrainLayerMask.FLUID_VISUAL:
		instance = _fluid_mesh
	var mesh := instance.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		return PackedVector3Array()
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _create_mesh(vertices: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_material(layer_kind: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform int layer_kind = 0;
void fragment() {
	vec4 base = COLOR;
	float pattern = 0.0;
	if (layer_kind == 1) {
		pattern = step(0.72, fract(UV.x * 13.0 + UV.y * 7.0)) * 0.10;
	} else if (layer_kind == 2) {
		pattern = sin((UV.y + TIME * 0.18) * 32.0 + sin(UV.x * 18.0)) * 0.055;
	} else {
		pattern = step(0.88, fract(UV.x * 9.0 + UV.y * 11.0)) * 0.07;
	}
	COLOR = vec4(base.rgb + pattern, base.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("layer_kind", layer_kind)
	return material
