@tool
## Defines an item chest scene and its deterministic weighted reward choices.
class_name ItemChestDefinition
extends GeneratedItemPlacementDefinition

enum RewardKind { ITEMS, PERKS }

@export var chest_scene: PackedScene
@export var explosion_definition: ExplosionDefinition
@export var destruction_pulse: DirectionalTerrainPulseDefinition
@export var container_tags := PackedStringArray(["item_chest"])
@export var emits_light := true
## Zero retains the light configured by the reusable container scene.
@export_range(0, 255, 1) var emitted_light_level_override := 0
@export var reward_kind := RewardKind.ITEMS
@export_range(1, 3, 1) var choice_count := 2
@export var options: Array[ItemChestOption] = []
@export_category("Generation")
@export_range(1, 12, 1) var chamber_radius := 3
@export_category("Motion")
@export_range(0.0, 4000.0, 1.0) var gravity := 880.0
@export_range(0.0, 4000.0, 1.0) var terminal_fall_speed := 720.0
@export_range(0.0, 64.0, 0.5) var support_probe_distance := 12.0
@export_range(0, 32, 1) var terrain_unstuck_search_ring := 8
@export_range(0.0, 4000.0, 1.0) var terrain_unstuck_push_speed := 900.0
@export_range(0.0, 90.0, 1.0) var uneven_ground_tilt_degrees := 45.0
@export var allow_support_tilt := true
@export_range(0.5, 8.0, 0.05) var sprite_width_radii := 3.5
@export_range(0.5, 8.0, 0.05) var body_width_radii := 3.25
@export_range(0.5, 8.0, 0.05) var body_height_radii := 2.0


func validate() -> PackedStringArray:
	var errors := super.validate()
	if chest_scene == null:
		errors.append("item chest definition requires a chest scene")
	if chamber_radius < 1:
		errors.append("item chest chamber_radius must be positive")
	if explosion_definition == null:
		errors.append("item chest definition requires an explosion definition")
	else:
		for error in explosion_definition.validate():
			errors.append("explosion: %s" % error)
	if gravity <= 0.0:
		errors.append("item chest gravity must be positive")
	if terminal_fall_speed <= 0.0:
		errors.append("item chest terminal_fall_speed must be positive")
	if support_probe_distance <= 0.0:
		errors.append("item chest support_probe_distance must be positive")
	if terrain_unstuck_search_ring < 0 or terrain_unstuck_push_speed <= 0.0:
		errors.append("item chest terrain unstuck tuning is invalid")
	if choice_count < 1 or choice_count > 3:
		errors.append("item chest choice_count must be between 1 and 3")
	if emitted_light_level_override < 0 or emitted_light_level_override > 255:
		errors.append("item chest emitted light override must be between 0 and 255")
	if destruction_pulse != null:
		for error in destruction_pulse.validate():
			errors.append("destruction pulse: %s" % error)
	if sprite_width_radii <= 0.0 or body_width_radii <= 0.0 or body_height_radii <= 0.0:
		errors.append("item chest geometry sizes must be positive")
	if requires_item_options():
		_validate_item_options(errors)
	return errors


func requires_item_options() -> bool:
	return true


func _validate_item_options(errors: PackedStringArray) -> void:
	var positive_weight_count := 0
	var stable_ids := {}
	for index in options.size():
		var option := options[index]
		if option == null:
			errors.append("item chest option[%d] is null" % index)
			continue
		for error in option.validate():
			errors.append("option[%d]: %s" % [index, error])
		if option.selection_weight > 0.0:
			positive_weight_count += 1
		if option.item == null:
			continue
		if stable_ids.has(option.item.stable_id):
			errors.append("item chest options contain duplicate item stable_id %d" % option.item.stable_id)
		else:
			stable_ids[option.item.stable_id] = true
	if positive_weight_count < choice_count:
		errors.append("item chest requires at least %d positive-weight options" % choice_count)


func required_edge_clearance() -> int:
	return chamber_radius


func prepare_terrain(context: GenerationContext, anchor: Vector2i) -> bool:
	var air_id := context.terrain_registry.stable_id_for_name("Air")
	if air_id < 0:
		return false
	var anchor_hex := HexCoord.from_offset_odd_q(anchor.x, anchor.y)
	var anchor_y := anchor_hex.to_world_position(1.0).y
	for delta_q in range(-chamber_radius, chamber_radius + 1):
		var min_delta_r := maxi(-chamber_radius, -delta_q - chamber_radius)
		var max_delta_r := mini(chamber_radius, -delta_q + chamber_radius)
		for delta_r in range(min_delta_r, max_delta_r + 1):
			var cell_hex := anchor_hex.add(HexCoord.new(delta_q, delta_r))
			var offset := cell_hex.to_offset_odd_q()
			if cell_hex.to_world_position(1.0).y <= anchor_y + 0.0001:
				context.world.set_committed_by_offset(offset.x, offset.y, air_id)
	return true


func record_spawn(context: GenerationContext, anchor: Vector2i, spawn_seed: int) -> bool:
	context.item_chest_spawns.append(GeneratedItemChestSpawn.new(anchor, self, spawn_seed))
	return true


func draw_choices(seed_value: int, requested_count: int = -1) -> Array[ItemChestOption]:
	var remaining: Array[ItemChestOption] = []
	for option in options:
		if option != null and option.selection_weight > 0.0:
			remaining.append(option)
	var result: Array[ItemChestOption] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var target_count := choice_count if requested_count < 0 else requested_count
	while result.size() < target_count and not remaining.is_empty():
		var total_weight := 0.0
		for option in remaining:
			total_weight += option.selection_weight
		if total_weight <= 0.0:
			break
		var roll := rng.randf() * total_weight
		var selected_index := remaining.size() - 1
		for index in remaining.size():
			roll -= remaining[index].selection_weight
			if roll < 0.0:
				selected_index = index
				break
		result.append(remaining[selected_index])
		remaining.remove_at(selected_index)
	return result
