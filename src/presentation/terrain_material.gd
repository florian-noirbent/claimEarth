@tool
## Editor-facing terrain material settings for fill rendering.
class_name TerrainMaterial
extends Resource


@export var fill_texture: Texture2D
@export_range(1.0, 1024.0, 1.0) var fill_texture_world_scale := 64.0
@export var edge_definition: TerrainEdgeDefinition
