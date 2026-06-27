class_name CompiledTerrainData
extends RefCounted


const MOTION_STABLE := 0
const MOTION_FALLING := 1
const MOTION_LIQUID := 2

var motion_by_id := PackedByteArray()
var layer_by_id := PackedByteArray()
var solid_by_id := PackedByteArray()
var passable_by_id := PackedByteArray()
var moving_solid_fill_threshold_by_id := PackedByteArray()
var can_fall_by_id := PackedByteArray()
var can_side_down_by_id := PackedByteArray()
var can_side_up_by_id := PackedByteArray()
var displaces_passable_moving_on_fall_by_id := PackedByteArray()
var fall_rate_by_id := PackedByteArray()
var side_down_rate_by_id := PackedByteArray()
var side_up_rate_by_id := PackedByteArray()
var min_fill_difference_by_id := PackedByteArray()
var side_flow_offset_by_id := PackedByteArray()
var side_up_source_threshold_by_id := PackedByteArray()
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
		result.moving_solid_fill_threshold_by_id[stable_id] = definition.moving_solid_fill_threshold
		var motion := definition.motion_behavior
		result.can_fall_by_id[stable_id] = 1 if motion.can_fall else 0
		result.can_side_down_by_id[stable_id] = 1 if motion.can_side_down else 0
		result.can_side_up_by_id[stable_id] = 1 if motion.can_side_up else 0
		result.displaces_passable_moving_on_fall_by_id[stable_id] = 1 if motion.displaces_passable_moving_on_fall else 0
		result.fall_rate_by_id[stable_id] = motion.fall_rate
		result.side_down_rate_by_id[stable_id] = motion.side_down_rate
		result.side_up_rate_by_id[stable_id] = motion.side_up_rate
		result.min_fill_difference_by_id[stable_id] = motion.min_fill_difference
		result.side_flow_offset_by_id[stable_id] = motion.side_flow_offset
		result.side_up_source_threshold_by_id[stable_id] = motion.side_up_source_threshold
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


func is_solid(cell_id: int, fill: int = 255) -> bool:
	if cell_id < 0 or cell_id >= solid_by_id.size() or solid_by_id[cell_id] == 0:
		return false
	if motion(cell_id) == MOTION_STABLE:
		return true
	return fill >= int(moving_solid_fill_threshold_by_id[cell_id])


func is_passable(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < passable_by_id.size() and passable_by_id[cell_id] != 0


func motion(cell_id: int) -> int:
	return int(motion_by_id[cell_id]) if cell_id >= 0 and cell_id < motion_by_id.size() else MOTION_STABLE


func is_moving(cell_id: int) -> bool:
	return motion(cell_id) != MOTION_STABLE


func can_fall(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < can_fall_by_id.size() and can_fall_by_id[cell_id] != 0


func can_side_down(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < can_side_down_by_id.size() and can_side_down_by_id[cell_id] != 0


func can_side_up(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < can_side_up_by_id.size() and can_side_up_by_id[cell_id] != 0


func displaces_passable_moving_on_fall(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < displaces_passable_moving_on_fall_by_id.size() and displaces_passable_moving_on_fall_by_id[cell_id] != 0


func transfer_rate(cell_id: int, direction_kind: int) -> int:
	match direction_kind:
		0:
			return int(fall_rate_by_id[cell_id]) if cell_id >= 0 and cell_id < fall_rate_by_id.size() else 0
		1:
			return int(side_down_rate_by_id[cell_id]) if cell_id >= 0 and cell_id < side_down_rate_by_id.size() else 0
		2:
			return int(side_up_rate_by_id[cell_id]) if cell_id >= 0 and cell_id < side_up_rate_by_id.size() else 0
	return 0


func min_fill_difference(cell_id: int) -> int:
	return int(min_fill_difference_by_id[cell_id]) if cell_id >= 0 and cell_id < min_fill_difference_by_id.size() else 0


func side_flow_offset(cell_id: int) -> int:
	return int(side_flow_offset_by_id[cell_id]) if cell_id >= 0 and cell_id < side_flow_offset_by_id.size() else 50


func side_up_source_threshold(cell_id: int) -> int:
	return int(side_up_source_threshold_by_id[cell_id]) if cell_id >= 0 and cell_id < side_up_source_threshold_by_id.size() else 128


func _resize_tables(size: int) -> void:
	motion_by_id.resize(size)
	layer_by_id.resize(size)
	solid_by_id.resize(size)
	passable_by_id.resize(size)
	moving_solid_fill_threshold_by_id.resize(size)
	can_fall_by_id.resize(size)
	can_side_down_by_id.resize(size)
	can_side_up_by_id.resize(size)
	displaces_passable_moving_on_fall_by_id.resize(size)
	fall_rate_by_id.resize(size)
	side_down_rate_by_id.resize(size)
	side_up_rate_by_id.resize(size)
	min_fill_difference_by_id.resize(size)
	side_flow_offset_by_id.resize(size)
	side_up_source_threshold_by_id.resize(size)
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
