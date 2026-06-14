class_name CompiledTerrainData
extends RefCounted


const MOTION_STABLE := 0
const MOTION_FALLING := 1
const MOTION_LIQUID := 2

var motion_by_id := PackedByteArray()
var layer_by_id := PackedByteArray()
var solid_by_id := PackedByteArray()
var passable_by_id := PackedByteArray()
var fill_color_by_id := PackedColorArray()
var accent_color_by_id := PackedColorArray()
var pattern_by_id := PackedByteArray()
var air_id := 0
var stone_id := 0


static func compile(registry: TerrainRegistry) -> CompiledTerrainData:
	var result := CompiledTerrainData.new()
	result._resize_tables(256)
	for definition in registry.all_definitions():
		var stable_id := definition.stable_id
		var motion_name := definition.motion_behavior.behavior_name
		if motion_name == "falling":
			result.motion_by_id[stable_id] = MOTION_FALLING
			result.layer_by_id[stable_id] = TerrainLayerMask.SAND_VISUAL
		elif motion_name == "liquid":
			result.motion_by_id[stable_id] = MOTION_LIQUID
			result.layer_by_id[stable_id] = TerrainLayerMask.FLUID_VISUAL
		else:
			result.motion_by_id[stable_id] = MOTION_STABLE
			result.layer_by_id[stable_id] = TerrainLayerMask.STATIC_VISUAL if definition.debug_color.a > 0.0 else TerrainLayerMask.NONE
		result.solid_by_id[stable_id] = 1 if definition.is_solid else 0
		result.passable_by_id[stable_id] = 1 if definition.is_passable else 0
		var style := definition.visual_style as TerrainVisualStyle
		result.fill_color_by_id[stable_id] = style.fill_color if style != null else definition.debug_color
		result.accent_color_by_id[stable_id] = style.accent_color if style != null else definition.debug_color
		result.pattern_by_id[stable_id] = _pattern_code(style.pattern_mode if style != null else "solid")
		if definition.is_empty_space:
			result.air_id = stable_id
		if definition.is_liquid_contact_product:
			result.stone_id = stable_id
	return result


func visual_layer(cell_id: int) -> int:
	return int(layer_by_id[cell_id]) if cell_id >= 0 and cell_id < layer_by_id.size() else TerrainLayerMask.NONE


func is_solid(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < solid_by_id.size() and solid_by_id[cell_id] != 0


func is_passable(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < passable_by_id.size() and passable_by_id[cell_id] != 0


func motion(cell_id: int) -> int:
	return int(motion_by_id[cell_id]) if cell_id >= 0 and cell_id < motion_by_id.size() else MOTION_STABLE


func _resize_tables(size: int) -> void:
	motion_by_id.resize(size)
	layer_by_id.resize(size)
	solid_by_id.resize(size)
	passable_by_id.resize(size)
	fill_color_by_id.resize(size)
	accent_color_by_id.resize(size)
	pattern_by_id.resize(size)


static func _pattern_code(pattern_mode: String) -> int:
	match pattern_mode:
		"grain":
			return 1
		"flow":
			return 2
		"cross":
			return 3
	return 0
