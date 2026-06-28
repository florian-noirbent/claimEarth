## Owns static, sand, and fluid mesh layers for one visible chunk.
class_name WorldChunkRenderer
extends Node2D


var chunk_coord := Vector2i.ZERO
var chunk_rect := Rect2i()
var _static_mesh := MeshInstance2D.new()
var _sand_mesh := MeshInstance2D.new()
var _fluid_mesh := MeshInstance2D.new()
var _terrain_materials: Array[TerrainMaterial] = []
var _static_material_meshes := {}
var _static_edge_meshes := {}


func _ready() -> void:
	if _static_mesh.get_parent() == null:
		add_child(_static_mesh)
		add_child(_sand_mesh)
		add_child(_fluid_mesh)
		_static_mesh.material = _make_material(0)
		_sand_mesh.material = _make_material(1)
		_fluid_mesh.material = _make_material(2)


func configure(chunk_coord_value: Vector2i, chunk_rect_value: Rect2i, terrain_materials: Array[TerrainMaterial] = []) -> void:
	chunk_coord = chunk_coord_value
	chunk_rect = chunk_rect_value
	_terrain_materials = terrain_materials


func apply_result(result: ChunkBuildResult) -> void:
	if (result.layer_mask & TerrainLayerMask.STATIC_VISUAL) != 0:
		_static_mesh.mesh = _create_mesh(result.static_vertices, result.static_colors, result.static_uvs, result.static_indices)
		_apply_static_material_results(result.static_material_meshes)
		_apply_static_edge_results(result.static_edge_meshes)
	if (result.layer_mask & TerrainLayerMask.SAND_VISUAL) != 0:
		_sand_mesh.mesh = _create_mesh(result.sand_vertices, result.sand_colors, result.sand_uvs, result.sand_indices)
	if (result.layer_mask & TerrainLayerMask.FLUID_VISUAL) != 0:
		_fluid_mesh.mesh = _create_mesh(result.fluid_vertices, result.fluid_colors, result.fluid_uvs, result.fluid_indices)


func layer_vertex_count(layer_mask: int) -> int:
	if layer_mask == TerrainLayerMask.STATIC_VISUAL:
		var count := _layer_vertices(layer_mask).size()
		for mesh_instance_variant in _static_material_meshes.values():
			count += _mesh_vertices(mesh_instance_variant as MeshInstance2D).size()
		return count
	return _layer_vertices(layer_mask).size()


func layer_min_vertex_y(layer_mask: int) -> float:
	var vertices := _layer_vertices(layer_mask)
	if layer_mask == TerrainLayerMask.STATIC_VISUAL:
		for mesh_instance_variant in _static_material_meshes.values():
			vertices.append_array(_mesh_vertices(mesh_instance_variant as MeshInstance2D))
	if vertices.is_empty():
		return INF
	var min_y := vertices[0].y
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
	return min_y


func static_material_mesh_count() -> int:
	return _static_material_meshes.size()


func static_edge_vertex_count() -> int:
	var count := 0
	for mesh_instance_variant in _static_edge_meshes.values():
		count += _mesh_vertices(mesh_instance_variant as MeshInstance2D).size()
	return count


func _layer_vertices(layer_mask: int) -> PackedVector3Array:
	var instance := _static_mesh
	if layer_mask == TerrainLayerMask.SAND_VISUAL:
		instance = _sand_mesh
	elif layer_mask == TerrainLayerMask.FLUID_VISUAL:
		instance = _fluid_mesh
	var mesh := instance.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		return PackedVector3Array()
	return _mesh_vertices(instance)


func _mesh_vertices(instance: MeshInstance2D) -> PackedVector3Array:
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


func _apply_static_material_results(material_meshes: Dictionary) -> void:
	for material_index_variant in _static_material_meshes.keys():
		var material_index := int(material_index_variant)
		if material_meshes.has(material_index):
			continue
		(_static_material_meshes[material_index] as Node).queue_free()
		_static_material_meshes.erase(material_index)
	for material_index_variant in material_meshes.keys():
		var material_index := int(material_index_variant)
		var mesh_arrays := material_meshes[material_index] as ChunkMeshArrays
		var mesh_instance := _static_material_mesh(material_index)
		mesh_instance.mesh = _create_mesh(
			mesh_arrays.to_vertices(),
			mesh_arrays.to_colors(),
			mesh_arrays.to_uvs(),
			mesh_arrays.to_indices()
		)


func _static_material_mesh(material_index: int) -> MeshInstance2D:
	if _static_material_meshes.has(material_index):
		return _static_material_meshes[material_index] as MeshInstance2D
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.z_index = 0
	mesh_instance.material = _make_texture_material(_texture_for_material_index(material_index))
	_static_material_meshes[material_index] = mesh_instance
	add_child(mesh_instance)
	return mesh_instance


func _texture_for_material_index(material_index: int) -> Texture2D:
	if material_index <= 0 or material_index >= _terrain_materials.size():
		return null
	var terrain_material := _terrain_materials[material_index]
	return terrain_material.fill_texture if terrain_material != null else null


func _make_texture_material(texture: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D fill_texture : repeat_enable;
void fragment() {
	vec4 texel = texture(fill_texture, UV);
	COLOR = vec4(texel.rgb, COLOR.a * texel.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fill_texture", texture)
	return material


func _apply_static_edge_results(edge_meshes: Dictionary) -> void:
	for material_index_variant in _static_edge_meshes.keys():
		var material_index := int(material_index_variant)
		if edge_meshes.has(material_index):
			continue
		(_static_edge_meshes[material_index] as Node).queue_free()
		_static_edge_meshes.erase(material_index)
	for material_index_variant in edge_meshes.keys():
		var material_index := int(material_index_variant)
		var mesh_arrays := edge_meshes[material_index] as ChunkMeshArrays
		var mesh_instance := _static_edge_mesh(material_index)
		mesh_instance.mesh = _create_mesh(
			mesh_arrays.to_vertices(),
			mesh_arrays.to_colors(),
			mesh_arrays.to_uvs(),
			mesh_arrays.to_indices()
		)


func _static_edge_mesh(material_index: int) -> MeshInstance2D:
	if _static_edge_meshes.has(material_index):
		return _static_edge_meshes[material_index] as MeshInstance2D
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.z_index = 1
	mesh_instance.material = _make_edge_material()
	_static_edge_meshes[material_index] = mesh_instance
	add_child(mesh_instance)
	return mesh_instance


func _make_edge_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	COLOR = COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
