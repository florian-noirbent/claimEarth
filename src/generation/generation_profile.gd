@tool
class_name GenerationProfile
extends Resource


@export var width := 100
@export var depth := 512
@export var spawn_width := 10
@export var spawn_height := 4
@export var spawn_margin_top := 0
@export var passes: Array = []


func create_dimensions() -> WorldDimensions:
	return WorldDimensions.new(width, depth)


func active_passes() -> Array:
	var result: Array = []
	for pass_variant in passes:
		var pass_resource = pass_variant
		if pass_resource != null and pass_resource.enabled:
			result.append(pass_resource)
	return result


func ensure_pass_seed_keys() -> void:
	var seen := {}
	for index in range(passes.size()):
		var pass_resource = passes[index]
		if pass_resource == null:
			continue
		if pass_resource.pass_seed_key.is_empty():
			pass_resource.pass_seed_key = "%s_%d" % [pass_resource.get_display_name().to_snake_case(), index]
		var unique_key: String = pass_resource.pass_seed_key
		var collision := 1
		while seen.has(unique_key):
			unique_key = "%s_%d" % [pass_resource.pass_seed_key, collision]
			collision += 1
		pass_resource.pass_seed_key = unique_key
		seen[unique_key] = true
