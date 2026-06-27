@tool
## Base resource contract for deterministic world generation passes.
class_name GenerationPassResource
extends Resource


@export var enabled := true
@export var label := ""
@export var pass_seed_key := ""
@export_range(0.0, 1.0, 0.001) var min_depth_ratio := 0.0
@export_range(0.0, 1.0, 0.001) var max_depth_ratio := 1.0
@export_range(0.0, 1.0, 0.001) var blend_distance_ratio := 0.0
@export var allowed_target_ids := PackedInt32Array()


func _init() -> void:
	if pass_seed_key.is_empty():
		pass_seed_key = _default_seed_key()


func get_display_name() -> String:
	if not label.is_empty():
		return label
	return get_pass_type_name()


func get_pass_type_name() -> String:
	return _default_display_name()


func get_progress_label() -> String:
	return "Applying %s" % get_display_name()


func apply(_context: GenerationContext) -> bool:
	return true


func terrain_id(registry: TerrainRegistry, terrain_name: String) -> int:
	return registry.stable_id_for_name(terrain_name)


func should_replace_cell(context: GenerationContext, col: int, row: int, salt: int = 0) -> bool:
	if not context.depth_gate_allows(self, col, row, salt):
		return false
	if allowed_target_ids.is_empty():
		return true
	return allowed_target_ids.has(context.world.get_committed_by_offset(col, row))


func duplicate_pass() -> Resource:
	var copy: GenerationPassResource = duplicate(true)
	if copy != null:
		copy.pass_seed_key = copy._default_seed_key()
	return copy


func _default_display_name() -> String:
	var script_name: String = get_script().get_global_name() if get_script() != null else ""
	if script_name.is_empty():
		return "Generation Pass"
	var base_name: String = script_name
	if base_name.ends_with("Resource"):
		base_name = base_name.trim_suffix("Resource")
	var result := ""
	for index in range(base_name.length()):
		var character: int = base_name.unicode_at(index)
		var is_upper := character >= 65 and character <= 90
		if index > 0 and is_upper:
			result += " "
		result += String.chr(character)
	return result


func _default_seed_key() -> String:
	return "%s_%d" % [_default_display_name().to_snake_case(), Time.get_ticks_usec()]
