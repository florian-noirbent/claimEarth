## Carries mutable world state and deterministic random sources through generation passes.
class_name GenerationContext
extends RefCounted


var profile: GenerationProfile
var run_seed: int
var terrain_registry: TerrainRegistry
var world: WorldGrid
var spawn_rect := Rect2i()
var item_chest_spawns: Array[GeneratedItemChestSpawn] = []
var _generated_item_anchor_indices := {}


func _init(
	profile_value: GenerationProfile,
	seed_value: int,
	terrain_registry_value: TerrainRegistry,
	world_value: WorldGrid
) -> void:
	profile = profile_value
	run_seed = seed_value
	terrain_registry = terrain_registry_value
	world = world_value


func depth_ratio_for_row(row: int) -> float:
	return float(row) / float(max(1, profile.depth - 1))


func try_reserve_generated_item_anchor(anchor: Vector2i) -> bool:
	if not world.dimensions.is_in_bounds_offset(anchor.x, anchor.y):
		return false
	var index := world.dimensions.offset_to_index(anchor.x, anchor.y)
	if _generated_item_anchor_indices.has(index):
		return false
	_generated_item_anchor_indices[index] = true
	return true


func release_generated_item_anchor(anchor: Vector2i) -> void:
	if not world.dimensions.is_in_bounds_offset(anchor.x, anchor.y):
		return
	_generated_item_anchor_indices.erase(world.dimensions.offset_to_index(anchor.x, anchor.y))


func depth_blend_weight(pass_resource, row: int) -> float:
	var min_ratio := clampf(minf(pass_resource.min_depth_ratio, pass_resource.max_depth_ratio), 0.0, 1.0)
	var max_ratio := clampf(maxf(pass_resource.min_depth_ratio, pass_resource.max_depth_ratio), 0.0, 1.0)
	var ratio := depth_ratio_for_row(row)
	if ratio < min_ratio or ratio > max_ratio:
		return 0.0
	var blend := maxf(0.0, pass_resource.blend_distance_ratio)
	if blend <= 0.0:
		return 1.0
	var range_size := max_ratio - min_ratio
	if range_size <= 0.0:
		return 1.0 if is_equal_approx(ratio, min_ratio) else 0.0
	var effective_blend := minf(blend, range_size * 0.5)
	if effective_blend <= 0.0:
		return 1.0
	var start_weight := clampf((ratio - min_ratio) / effective_blend, 0.0, 1.0)
	var end_weight := clampf((max_ratio - ratio) / effective_blend, 0.0, 1.0)
	return minf(start_weight, end_weight)


func depth_gate_allows(pass_resource, col: int, row: int, salt: int = 0) -> bool:
	var weight := depth_blend_weight(pass_resource, row)
	if weight <= 0.0:
		return false
	if weight >= 1.0:
		return true
	return deterministic_sample(pass_resource, col, row, salt) <= weight


func deterministic_sample(pass_resource, col: int, row: int, salt: int = 0) -> float:
	var mixed := int(run_seed)
	mixed = _mix_int(mixed ^ hash(pass_resource.pass_seed_key))
	mixed = _mix_int(mixed ^ (col * 73856093))
	mixed = _mix_int(mixed ^ (row * 19349663))
	mixed = _mix_int(mixed ^ (salt * 83492791))
	return float(mixed & 0x7fffffff) / 2147483647.0


func _mix_int(value: int) -> int:
	var mixed := value
	mixed ^= (mixed << 13)
	mixed ^= (mixed >> 17)
	mixed ^= (mixed << 5)
	return mixed
