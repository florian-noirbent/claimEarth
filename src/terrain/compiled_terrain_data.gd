## Maps terrain stable IDs to compact behavior and style data for hot loops.
class_name CompiledTerrainData
extends RefCounted


const MOTION_STABLE := 0
const MOTION_FALLING := 1
const MOTION_LIQUID := 2
const MOTION_GAS := 3
const MOTION_DENSE_GAS := 4
const NO_BURN_PRODUCT_ID := 255

var motion_by_id := PackedByteArray()
var solid_by_id := PackedByteArray()
var passable_by_id := PackedByteArray()
var density_by_id := PackedByteArray()
var maximum_quantity_by_id := PackedByteArray()
var normal_quantity_by_id := PackedByteArray()
var storage_capacity_by_id := PackedByteArray()
var reaction_by_pair := PackedByteArray()
var reaction_product_a_by_pair := PackedByteArray()
var reaction_product_b_by_pair := PackedByteArray()
var reaction_generated_by_pair := PackedByteArray()
var persistent_burn_product_by_id := PackedByteArray()
var moving_solid_fill_threshold_by_id := PackedByteArray()
var can_fall_by_id := PackedByteArray()
var can_side_down_by_id := PackedByteArray()
var can_side_up_by_id := PackedByteArray()
var displaces_passable_moving_on_fall_by_id := PackedByteArray()
var viscosity_by_id := PackedFloat32Array()
var fall_rate_by_id := PackedByteArray()
var side_down_rate_by_id := PackedByteArray()
var side_up_rate_by_id := PackedByteArray()
var min_fill_difference_by_id := PackedByteArray()
var side_flow_offset_by_id := PackedByteArray()
var low_fill_decay_threshold_by_id := PackedByteArray()
var low_fill_decay_rate_by_id := PackedByteArray()
var light_diffusion_by_id := PackedByteArray()
var emitted_light_by_id := PackedByteArray()
var fill_color_by_id := PackedColorArray()
var accent_color_by_id := PackedColorArray()
var pattern_by_id := PackedByteArray()
var material_index_by_id := PackedInt32Array()
var fill_texture_world_scale_by_id := PackedFloat32Array()
var edge_color_by_id := PackedColorArray()
var edge_width_by_id := PackedFloat32Array()
var materials: Array[TerrainMaterial] = [null]
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
		elif motion_name == "liquid":
			result.motion_by_id[stable_id] = MOTION_LIQUID
		elif motion_name == "gas":
			result.motion_by_id[stable_id] = MOTION_GAS
		elif motion_name == "dense_gas":
			result.motion_by_id[stable_id] = MOTION_DENSE_GAS
		else:
			result.motion_by_id[stable_id] = MOTION_STABLE
		result.solid_by_id[stable_id] = 1 if definition.is_solid else 0
		result.passable_by_id[stable_id] = 1 if definition.is_passable else 0
		result.density_by_id[stable_id] = definition.block_density
		result.maximum_quantity_by_id[stable_id] = definition.maximum_quantity
		result.normal_quantity_by_id[stable_id] = definition.normal_quantity
		result.storage_capacity_by_id[stable_id] = definition.storage_capacity
		result.moving_solid_fill_threshold_by_id[stable_id] = definition.moving_solid_fill_threshold
		var motion := definition.motion_behavior
		result.can_fall_by_id[stable_id] = 1 if motion.can_fall else 0
		result.can_side_down_by_id[stable_id] = 1 if motion.can_side_down else 0
		result.can_side_up_by_id[stable_id] = 1 if motion.can_side_up else 0
		result.displaces_passable_moving_on_fall_by_id[stable_id] = 1 if motion.displaces_passable_moving_on_fall else 0
		result.viscosity_by_id[stable_id] = motion.viscosity
		result.fall_rate_by_id[stable_id] = motion.fall_rate
		result.side_down_rate_by_id[stable_id] = motion.side_down_rate
		result.side_up_rate_by_id[stable_id] = motion.side_up_rate
		result.min_fill_difference_by_id[stable_id] = motion.min_fill_difference
		result.side_flow_offset_by_id[stable_id] = motion.side_flow_offset
		result.low_fill_decay_threshold_by_id[stable_id] = motion.low_fill_decay_threshold
		result.low_fill_decay_rate_by_id[stable_id] = motion.low_fill_decay_rate
		result.light_diffusion_by_id[stable_id] = roundi(definition.light_diffusion_coefficient * 255.0)
		result.emitted_light_by_id[stable_id] = definition.emitted_light
		var style := definition.visual_style as TerrainVisualStyle
		result.fill_color_by_id[stable_id] = style.fill_color if style != null else definition.debug_color
		result.accent_color_by_id[stable_id] = style.accent_color if style != null else definition.debug_color
		result.pattern_by_id[stable_id] = _pattern_code(style.pattern_mode if style != null else "solid")
		var material := style.material if style != null else null
		var edge_definition := material.edge_definition if material != null else null
		if edge_definition != null:
			var edge_color := edge_definition.edge_color
			edge_color.a *= edge_definition.edge_alpha
			result.edge_color_by_id[stable_id] = edge_color
			result.edge_width_by_id[stable_id] = edge_definition.edge_width
		else:
			result.edge_color_by_id[stable_id] = style.outline_color if style != null else Color.TRANSPARENT
			result.edge_width_by_id[stable_id] = style.outline_width if style != null else 0.0
		if material != null and material.fill_texture != null:
			var material_index := result._material_index(material)
			result.material_index_by_id[stable_id] = material_index
			result.fill_texture_world_scale_by_id[stable_id] = maxf(material.fill_texture_world_scale, 1.0)
		else:
			result.material_index_by_id[stable_id] = 0
			result.fill_texture_world_scale_by_id[stable_id] = 64.0
		if definition.is_empty_space:
			result.air_id = stable_id
		if definition.is_liquid_contact_product:
			result.stone_id = stable_id
	for reaction in registry.contact_reactions():
		if reaction.reactant_a == null or reaction.reactant_b == null:
			continue
		result._set_reaction(reaction.reactant_a.stable_id, reaction.reactant_b.stable_id, reaction)
		if reaction.persistent_ignition and reaction.generated_product != null:
			result.persistent_burn_product_by_id[reaction.reactant_a.stable_id] = reaction.generated_product.stable_id
		if reaction.kind != TerrainContactReaction.Kind.ACID_SAND:
			result._set_reaction(reaction.reactant_b.stable_id, reaction.reactant_a.stable_id, reaction)
	return result


func is_solid(cell_id: int, quantity: int = 127) -> bool:
	if cell_id < 0 or cell_id >= solid_by_id.size() or solid_by_id[cell_id] == 0:
		return false
	if motion(cell_id) == MOTION_STABLE:
		return true
	return quantity >= int(moving_solid_fill_threshold_by_id[cell_id])


func is_passable(cell_id: int) -> bool:
	return cell_id >= 0 and cell_id < passable_by_id.size() and passable_by_id[cell_id] != 0


func density(cell_id: int) -> int:
	return int(density_by_id[cell_id]) if cell_id >= 0 and cell_id < density_by_id.size() else 0

func maximum_quantity(cell_id: int) -> int:
	return int(maximum_quantity_by_id[cell_id]) if cell_id >= 0 and cell_id < maximum_quantity_by_id.size() else 127


func normal_quantity(cell_id: int) -> int:
	return int(normal_quantity_by_id[cell_id]) if cell_id >= 0 and cell_id < normal_quantity_by_id.size() else 127


func storage_capacity(cell_id: int) -> int:
	return int(storage_capacity_by_id[cell_id]) if cell_id >= 0 and cell_id < storage_capacity_by_id.size() else 255



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


func viscosity(cell_id: int) -> float:
	return float(viscosity_by_id[cell_id]) if cell_id >= 0 and cell_id < viscosity_by_id.size() else 0.0


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


func low_fill_decay_threshold(cell_id: int) -> int:
	return int(low_fill_decay_threshold_by_id[cell_id]) if cell_id >= 0 and cell_id < low_fill_decay_threshold_by_id.size() else 0


func low_fill_decay_rate(cell_id: int) -> int:
	return int(low_fill_decay_rate_by_id[cell_id]) if cell_id >= 0 and cell_id < low_fill_decay_rate_by_id.size() else 0


func light_diffusion(cell_id: int) -> int:
	return int(light_diffusion_by_id[cell_id]) if cell_id >= 0 and cell_id < light_diffusion_by_id.size() else 0


func emitted_light(cell_id: int) -> int:
	return int(emitted_light_by_id[cell_id]) if cell_id >= 0 and cell_id < emitted_light_by_id.size() else 0


func _resize_tables(size: int) -> void:
	motion_by_id.resize(size)
	solid_by_id.resize(size)
	passable_by_id.resize(size)
	density_by_id.resize(size)
	maximum_quantity_by_id.resize(size)
	normal_quantity_by_id.resize(size)
	storage_capacity_by_id.resize(size)
	reaction_by_pair.resize(256)
	reaction_product_a_by_pair.resize(256)
	reaction_product_b_by_pair.resize(256)
	reaction_generated_by_pair.resize(256)
	persistent_burn_product_by_id.resize(size)
	persistent_burn_product_by_id.fill(NO_BURN_PRODUCT_ID)
	moving_solid_fill_threshold_by_id.resize(size)
	can_fall_by_id.resize(size)
	can_side_down_by_id.resize(size)
	can_side_up_by_id.resize(size)
	displaces_passable_moving_on_fall_by_id.resize(size)
	viscosity_by_id.resize(size)
	fall_rate_by_id.resize(size)
	side_down_rate_by_id.resize(size)
	side_up_rate_by_id.resize(size)
	min_fill_difference_by_id.resize(size)
	side_flow_offset_by_id.resize(size)
	low_fill_decay_threshold_by_id.resize(size)
	low_fill_decay_rate_by_id.resize(size)
	light_diffusion_by_id.resize(size)
	emitted_light_by_id.resize(size)
	fill_color_by_id.resize(size)
	accent_color_by_id.resize(size)
	pattern_by_id.resize(size)
	material_index_by_id.resize(size)
	fill_texture_world_scale_by_id.resize(size)
	edge_color_by_id.resize(size)
	edge_width_by_id.resize(size)


static func _pattern_code(pattern_mode: String) -> int:
	match pattern_mode:
		"grain":
			return 1
		"flow":
			return 2
		"cross":
			return 3
	return 0


func _material_index(material: TerrainMaterial) -> int:
	for index in range(1, materials.size()):
		if materials[index] == material:
			return index
	materials.append(material)
	return materials.size() - 1


func _set_reaction(a: int, b: int, reaction: TerrainContactReaction) -> void:
	var index := (a & 15) * 16 + (b & 15)
	reaction_by_pair[index] = reaction.kind + 1
	reaction_product_a_by_pair[index] = reaction.product_a.stable_id if reaction.product_a != null else 0
	reaction_product_b_by_pair[index] = reaction.product_b.stable_id if reaction.product_b != null else 0
	reaction_generated_by_pair[index] = reaction.generated_product.stable_id if reaction.generated_product != null else 0
