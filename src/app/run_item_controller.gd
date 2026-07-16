## Owns inventory, projectile lifecycle, explosions, and flag resolution for a run.
class_name RunItemController
extends Node


signal player_killed(cause: StringName)
signal explosion_resolved(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool)
signal flag_planted(depth: int, landing_position: Vector2)
signal flag_destroyed
signal flag_flight_changed(in_flight: bool)
signal item_thrown
signal terrain_changed(change_set: TerrainChangeSet)
signal terrain_pulse_started(origin: Vector2, definition: DirectionalTerrainPulseDefinition)
signal reward_choices_requested(title: String, choices: Array)
signal pending_reward_invalidated

const ItemInventoryScript = preload("res://src/items/item_inventory.gd")
const ItemTrajectoryServiceScript = preload("res://src/items/item_trajectory_service.gd")
const ItemProjectileScript = preload("res://src/items/item_projectile.gd")
const ExplosionServiceScript = preload("res://src/items/explosion_service.gd")

var _inventory: ItemInventory = ItemInventoryScript.new()
var _trajectory_service: ItemTrajectoryService = ItemTrajectoryServiceScript.new()
var _explosion_service: ExplosionService = ExplosionServiceScript.new()
var _player: PlayerController
var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _simulation_backend: TerrainSimulationBackend
var _hex_radius := 8.0
var _throw_lock_remaining := 0.0
var _active_flag_projectile: ItemProjectile
var _item_registry: ItemRegistry
var _pending_chest: ItemChest
var _pending_choices: Array[ItemChestOption] = []
var _pending_perk_choices: Array[PerkDefinition] = []
var _perk_controller: RunPerkController
var _is_active := false
var _explosives: Array[WorldExplosive2D] = []
var _dynamic_item_order: Array[ItemDefinition] = []
var _perk_modifiers: PerkModifierSnapshot
var _terrain_pulses: Array[DirectionalTerrainPulse] = []
var _successful_use_counts := {}
var _world_left_edge := 0.0
var _world_right_edge := 0.0


func configure_catalog(item_registry: ItemRegistry, hex_radius: float) -> void:
	_item_registry = item_registry
	_inventory.configure(item_registry)
	_hex_radius = hex_radius


func configure_perk_controller(controller: RunPerkController) -> void:
	_perk_controller = controller


func set_perk_modifiers(modifiers: PerkModifierSnapshot) -> void:
	_perk_modifiers = modifiers
	_apply_container_perk_modifiers()
	if _active_flag_projectile != null and _has_relentless_flag_survival():
		_active_flag_projectile.destroyed_by_lava = false


func configure_run(
	player: PlayerController,
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	hex_radius: float,
	simulation_backend: TerrainSimulationBackend = null,
	chest_spawns: Array[GeneratedItemChestSpawn] = [],
	geode_spawns: Array[GeneratedItemChestSpawn] = []
) -> void:
	_inventory.reset()
	_player = player
	_world = world
	_terrain_registry = terrain_registry
	_simulation_backend = simulation_backend
	_hex_radius = hex_radius
	_world_left_edge = HexMetrics.center_for_offset(0, 0, hex_radius).x - hex_radius
	_world_right_edge = HexMetrics.center_for_offset(world.dimensions.width - 1, 0, hex_radius).x + hex_radius
	_active_flag_projectile = null
	_pending_chest = null
	_pending_choices.clear()
	_pending_perk_choices.clear()
	_terrain_pulses.clear()
	_explosives.clear()
	_dynamic_item_order.clear()
	_successful_use_counts.clear()
	_throw_lock_remaining = 1.0
	_spawn_item_chests(chest_spawns)
	_spawn_item_chests(geode_spawns)
	_apply_container_perk_modifiers()
	flag_flight_changed.emit(false)


func clear_run() -> void:
	if _simulation_backend != null:
		_simulation_backend.clear_standard_light_sources()
	_player = null
	_world = null
	_simulation_backend = null
	_active_flag_projectile = null
	_pending_chest = null
	_pending_choices.clear()
	_pending_perk_choices.clear()
	_terrain_pulses.clear()
	_explosives.clear()
	for child in get_children():
		if child is WorldRigidBody2D or child is ItemChest:
			child.free()


func set_active(is_active: bool) -> void:
	_is_active = is_active
	for child in get_children():
		if child is WorldRigidBody2D:
			child.set_physics_process(is_active)
		elif child is ItemChest:
			(child as ItemChest).set_active(is_active, _pending_chest == null)
		elif child is ExcavatorRobot:
			(child as ExcavatorRobot).set_active(is_active)
	for explosive in _explosives:
		if is_instance_valid(explosive):
			explosive.set_active(is_active)


func apply_pending_reward(choice_index: int) -> bool:
	if _pending_chest == null:
		return false
	if not _pending_perk_choices.is_empty():
		if choice_index < 0 or choice_index >= _pending_perk_choices.size() or _perk_controller == null:
			return false
		if not _perk_controller.select_perk(_pending_perk_choices[choice_index]):
			return false
	else:
		if choice_index < 0 or choice_index >= _pending_choices.size():
			return false
		var option := _pending_choices[choice_index]
		if option == null or option.item == null or _item_registry == null:
			return false
		var registered_item := _item_registry.get_definition(option.item.stable_id)
		if registered_item == null or not _inventory.add(registered_item, option.quantity):
			return false
		if _is_dynamic_definition(registered_item) and not _dynamic_item_order.has(registered_item):
			_dynamic_item_order.append(registered_item)
	var claimed_chest := _pending_chest
	claimed_chest.set_light_emitting(false)
	_forget_explosive(claimed_chest.explosive)
	_pending_chest = null
	_pending_choices.clear()
	_pending_perk_choices.clear()
	if is_instance_valid(claimed_chest):
		claimed_chest.queue_free()
	_set_chest_interactivity(_is_active)
	return true


func cancel_pending_reward() -> void:
	_pending_chest = null
	_pending_choices.clear()
	_pending_perk_choices.clear()
	_set_chest_interactivity(_is_active)


func item_chest_count() -> int:
	var count := 0
	for child in get_children():
		if child is ItemChest and not child.is_queued_for_deletion() and (child as ItemChest).spawn_data.definition.reward_kind == ItemChestDefinition.RewardKind.ITEMS:
			count += 1
	return count

func debug_item_picker_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var definitions := _inventory.definitions()
	for index in definitions.size(): result.append({"index": index, "name": definitions[index].display_name})
	return result
func debug_grant_item(index: int) -> void:
	var definitions := _inventory.definitions()
	if index < 0 or index >= definitions.size(): return
	var definition := definitions[index]
	if _inventory.add(definition, 1.0) and _is_dynamic_definition(definition) and not _dynamic_item_order.has(definition): _dynamic_item_order.append(definition)
func debug_clear_world_items() -> void:
	for child in get_children():
		if child is WorldRigidBody2D:
			child.queue_free()


func advance(delta: float) -> void:
	_throw_lock_remaining = maxf(0.0, _throw_lock_remaining - delta)
	_advance_terrain_pulses(delta)


func select_index(index: int) -> void:
	var definitions := _inventory.definitions()
	if index < 0 or index >= definitions.size():
		return
	if _is_dynamic_index(index) and _inventory.count_for(definitions[index]) <= 0.0:
		return
	_inventory.select_index(index)


func select_dynamic_shortcut(shortcut: int) -> void:
	var dynamic_index := shortcut - 4
	if dynamic_index >= 0 and dynamic_index < _dynamic_item_order.size():
		select_index(_inventory.definitions().find(_dynamic_item_order[dynamic_index]))


func cycle_selection(direction: int) -> void:
	var definitions := _inventory.definitions()
	if definitions.is_empty() or direction == 0:
		return
	var selectable_indices: Array[int] = []
	for index in definitions.size():
		if not _is_dynamic_index(index) or _inventory.count_for(definitions[index]) > 0.0:
			selectable_indices.append(index)
	if selectable_indices.is_empty():
		return
	var selected_index := definitions.find(_inventory.selected_definition())
	var selectable_position := selectable_indices.find(selected_index)
	if selectable_position < 0:
		select_index(selectable_indices[0])
		return
	select_index(selectable_indices[posmod(selectable_position + signi(direction), selectable_indices.size())])


func consume_amount(definition: ItemDefinition, amount: float, allow_partial: bool = false) -> float:
	if definition != null and amount > 0.0 and _inventory.can_consume(definition) and _should_preserve_item(definition):
		return minf(amount, _inventory.count_for(definition)) if allow_partial else amount
	var consumed := _inventory.consume_amount(definition, amount, allow_partial)
	if consumed > 0.0 and _inventory.count_for(definition) <= 0.0:
		_dynamic_item_order.erase(definition)
		_select_after_dynamic_depletion(definition)
	return consumed


func throw_selected(aim_position: Vector2, bypass_cooldown: bool = false) -> bool:
	if _player == null or _world == null:
		return false
	if not bypass_cooldown and _throw_lock_remaining > 0.0:
		return false
	var definition: ItemDefinition = _inventory.selected_definition()
	if definition == null or not _inventory.can_consume(definition):
		return false
	var action: ItemAction = definition.action_factory.create_action(definition)
	if action == null:
		return false
	if action.is_immediate():
		var charge_used := action.use_immediately(self, aim_position)
		if charge_used <= 0.0:
			return false
		consume_amount(definition, charge_used, true)
		item_thrown.emit()
		return true
	if consume_amount(definition, 1.0) < 1.0:
		return false
	_spawn_projectile(action, _player.global_position, aim_position, _player.velocity)
	item_thrown.emit()
	return true


## Drops the held flag through the normal projectile path before a Relentless death settles.
func drop_flag_on_player_death() -> bool:
	if not _has_relentless_flag_survival() or _player == null or _world == null:
		return false
	if is_flag_in_flight():
		if _has_relentless_flag_survival():
			_active_flag_projectile.destroyed_by_lava = false
		return true
	var flag_definition: ItemDefinition
	for definition in _inventory.definitions():
		if definition != null and definition.perk_tags.has(&"flag") and _inventory.can_consume(definition):
			flag_definition = definition
			break
	if flag_definition == null or flag_definition.action_factory == null:
		return false
	var action := flag_definition.action_factory.create_action(flag_definition) as ItemAction
	if action == null or not action.locks_throwing_until_resolved() or consume_amount(flag_definition, 1.0) < 1.0:
		return false
	_spawn_projectile(action, _player.global_position, _player.global_position + Vector2(0.0, _hex_radius * 2.0), Vector2.ZERO)
	return true


func _spawn_projectile(action: ItemAction, origin: Vector2, aim_position: Vector2, thrower_velocity: Vector2) -> void:
	var projectile_data: Dictionary = action.create_projectile(origin, aim_position, _trajectory_service, thrower_velocity)
	if _has_relentless_flag_survival() and action.locks_throwing_until_resolved():
		projectile_data["destroyed_by_lava"] = false
	var projectile: ItemProjectile = ItemProjectileScript.new()
	projectile.action = action
	projectile.simulation_backend = _simulation_backend
	projectile.world = _world
	projectile.terrain_registry = _terrain_registry
	projectile.hex_radius = _hex_radius
	projectile.global_position = origin
	projectile.configure(projectile_data)
	projectile.configure_horizontal_bounds(_world_left_edge, _world_right_edge)
	_register_explosive(projectile.explosive)
	projectile.set_physics_process(_is_active)
	projectile.resolved.connect(_on_projectile_resolved)
	add_child(projectile)
	if action.locks_throwing_until_resolved():
		_active_flag_projectile = projectile
		flag_flight_changed.emit(true)


func _has_relentless_flag_survival() -> bool:
	return _perk_modifiers != null and bool(_perk_modifiers.flags.value("survive_lava_acid_and_drop_on_death", false))


func resolve_explosion(definition: ExplosionDefinition, impact_position: Vector2, source_item: ItemDefinition = null) -> void:
	if _world == null or definition == null or not definition.validate().is_empty():
		return
	var spec := ExplosionRuntimeSpec.from_definition(definition)
	_apply_explosion_perk_modifiers(spec, source_item)
	if _player != null and _player.global_position.distance_to(impact_position) <= spec.player_kill_radius * _hex_radius:
		player_killed.emit(DeathCause.BOMB)
	_apply_projectile_blast_impulses(spec, impact_position)
	var result := _explosion_service.resolve_spec(
		_world,
		_terrain_registry,
		impact_position,
		_hex_radius,
		spec
	)
	var change_set := result.terrain_changes
	if _simulation_backend != null:
		_simulation_backend.notify_external_changes(change_set)
	terrain_changed.emit(change_set)
	explosion_resolved.emit(impact_position, definition.effect_color, spec.blast_radius, definition.large_feedback)
	_arm_explosives_in(result.destructive_core_cells)


func _apply_projectile_blast_impulses(spec: ExplosionRuntimeSpec, impact_position: Vector2) -> void:
	var world_radius := spec.blast_radius * _hex_radius
	for child in get_children():
		if child is WorldRigidBody2D and not child.is_queued_for_deletion():
			(child as WorldRigidBody2D).apply_blast_impulse(impact_position, spec.blast_impulse, world_radius)
	if _player != null and _perk_modifiers != null and bool(_perk_modifiers.explosions.value("player_explosion_impulse_enabled", false)):
		_player.apply_blast_impulse(impact_position, spec.blast_impulse, world_radius)


func resolve_flag_landing(_item_action: ItemAction, impact_position: Vector2, _projectile: ItemProjectile, resolution_kind: StringName) -> void:
	_active_flag_projectile = null
	flag_flight_changed.emit(false)
	if resolution_kind == &"lava":
		flag_destroyed.emit()
	elif resolution_kind == &"impact":
		var landing_depth := maxi(0, HexMetrics.offset_for_world(impact_position, _hex_radius).y)
		flag_planted.emit(landing_depth, impact_position)


func resolve_terrain_tool_use(transformations: Array[TerrainTransformRule], aim_position: Vector2) -> float:
	if _player == null or _world == null or _terrain_registry == null:
		return 0.0
	var change_set := TerrainChangeSet.new(_world.dimensions)
	var cost := 0.0
	for target in _aimed_tool_targets(aim_position):
		if not _world.dimensions.is_in_bounds_offset(target.x, target.y):
			continue
		var source_id := _world.get_committed_by_offset(target.x, target.y)
		var target_id := -1
		for rule in transformations:
			if rule != null and rule.source != null and rule.target != null and rule.source.stable_id == source_id:
				target_id = rule.target.stable_id
				break
		if target_id < 0:
			continue
		var quantity := _world.get_committed_quantity_by_offset(target.x, target.y)
		var source := _terrain_registry.get_definition(source_id)
		var cell_cost := float(quantity) / float(source.maximum_quantity)
		if cell_cost <= 0.0:
			continue
		var resolved_target_id := target_id
		if _should_vaporize_tool_dirt(source, target_id, target):
			resolved_target_id = 0
		var change := _world.set_committed_by_offset(target.x, target.y, resolved_target_id, WorldGrid.AIR_QUANTITY if resolved_target_id == 0 else quantity)
		change_set.add_cell_change(change)
		cost += cell_cost
	_commit_external_terrain_changes(change_set)
	return minf(cost, 3.0)


func _should_vaporize_tool_dirt(source: TerrainDefinition, target_id: int, target: Vector2i) -> bool:
	if _perk_modifiers == null or source == null or not source.perk_tags.has("dirt"):
		return false
	if target_id == 0:
		return false
	var chance := clampf(float(_perk_modifiers.terrain.value("dirt_vaporize_chance", 0.0)), 0.0, 1.0)
	if chance <= 0.0:
		return false
	var seed := SeedUtils.derive_seed(_world.dimensions.width * 1000003 + _world.dimensions.depth, "tool-dirt:%d:%d" % [target.x, target.y])
	return float(posmod(seed, 1000000)) / 1000000.0 < chance


func resolve_fluid_bottle_impact(deposited_terrain: TerrainDefinition, impact_position: Vector2) -> void:
	if _world == null or _terrain_registry == null or deposited_terrain == null:
		return
	var origin := HexMetrics.offset_for_world(impact_position, _hex_radius)
	if not _world.dimensions.is_in_bounds_offset(origin.x, origin.y):
		return
	var change_set := TerrainChangeSet.new(_world.dimensions)
	var found := 0
	var ring := 0
	var max_ring := _world.dimensions.width + _world.dimensions.depth
	while found < 3 and ring <= max_ring:
		for offset in _offsets_at_ring(origin, ring):
			if not _world.dimensions.is_in_bounds_offset(offset.x, offset.y):
				continue
			var existing := _terrain_registry.get_definition(_world.get_committed_by_offset(offset.x, offset.y))
			if existing == null or not existing.is_empty_space:
				continue
			var change := _world.set_committed_by_offset(offset.x, offset.y, deposited_terrain.stable_id, deposited_terrain.maximum_quantity)
			change_set.add_cell_change(change)
			found += 1
			if found == 3:
				break
		ring += 1
	_commit_external_terrain_changes(change_set)

func spawn_excavator(position: Vector2, factory: ExcavatorItemActionFactory) -> void:
	var robot := ExcavatorRobot.new()
	add_child(robot)
	robot.configure(self, factory, position, _world, _terrain_registry, _hex_radius)
	if _perk_modifiers != null:
		robot.tick_interval_multiplier = float(_perk_modifiers.items.value("excavator_tick_interval_multiplier", 1.0))
	_register_explosive(robot.explosive)
	robot.set_active(_is_active)

func excavator_tick(robot: ExcavatorRobot, factory: ExcavatorItemActionFactory) -> void:
	if _world == null or _terrain_registry == null: return
	var origin := HexMetrics.offset_for_world(robot.global_position, _hex_radius)
	var targets := [origin + Vector2i(0, 1), origin + Vector2i(-1, 1), origin + Vector2i(1, 1)]
	var changes := TerrainChangeSet.new(_world.dimensions)
	var clear := true
	for cell in targets:
		if not _world.dimensions.is_in_bounds_offset(cell.x, cell.y): continue
		var terrain := _terrain_registry.get_definition(_world.get_committed_by_offset(cell.x, cell.y))
		if terrain != null and terrain.hazard_behavior.resolve_for_quantity(_world.get_committed_quantity_by_offset(cell.x, cell.y)) != null and terrain.blast_reaction.resolve().detonate_immediately:
			resolve_explosion(factory.explosion_definition, robot.global_position); robot.queue_free(); return
		if terrain == null or terrain.is_empty_space or terrain.is_passable: continue
		clear = false
		var next_id := -1
		if terrain.stable_id == 1: next_id = 2
		elif terrain.stable_id == 2: next_id = 3
		elif terrain.stable_id == 3: next_id = 0
		if next_id >= 0:
			var change := _world.set_committed_by_offset(cell.x, cell.y, next_id, WorldGrid.AIR_QUANTITY if next_id == 0 else _world.get_committed_quantity_by_offset(cell.x, cell.y))
			changes.add_cell_change(change)
	_commit_external_terrain_changes(changes)
	if clear: robot.global_position = HexMetrics.center_for_offset(origin.x, origin.y + 1, _hex_radius)


func _commit_external_terrain_changes(change_set: TerrainChangeSet) -> void:
	if change_set == null or change_set.is_empty():
		return
	if _simulation_backend != null:
		_simulation_backend.notify_external_changes(change_set)
	terrain_changed.emit(change_set)


func _advance_terrain_pulses(delta: float) -> void:
	if _terrain_pulses.is_empty() or _world == null or _terrain_registry == null:
		return
	var air_id := _terrain_registry.stable_id_for_name("Air")
	var merged := TerrainChangeSet.new(_world.dimensions)
	for pulse in _terrain_pulses.duplicate():
		var changes: TerrainChangeSet = pulse.advance(delta, _world, air_id)
		merged.merge(changes)
		if pulse.is_complete():
			_terrain_pulses.erase(pulse)
	_commit_external_terrain_changes(merged)


func _aimed_neighbor(aim_position: Vector2) -> Vector2i:
	var targets := _aimed_tool_targets(aim_position)
	return targets[0] if not targets.is_empty() else Vector2i(-1, -1)


func _aimed_tool_targets(aim_position: Vector2) -> Array[Vector2i]:
	var origin := HexMetrics.offset_for_world(_player.global_position, _hex_radius)
	var origin_hex := HexCoord.from_offset_odd_q(origin.x, origin.y)
	var direction := (aim_position - _player.global_position).normalized()
	if direction.length_squared() <= 0.001:
		return []
	var best_direction := 0
	var best_dot := -INF
	for index in HexCoord.NEIGHBOR_OFFSETS.size():
		var neighbor := origin_hex.neighbor(index)
		var candidate := neighbor.to_offset_odd_q()
		var candidate_direction := (HexMetrics.center_for_offset(candidate.x, candidate.y, _hex_radius) - _player.global_position).normalized()
		var alignment := direction.dot(candidate_direction)
		if alignment > best_dot:
			best_dot = alignment
			best_direction = index
	var result: Array[Vector2i] = []
	var forward := origin_hex.neighbor(best_direction)
	result.append(forward.to_offset_odd_q())
	result.append(forward.neighbor(best_direction - 1).to_offset_odd_q())
	result.append(forward.neighbor(best_direction + 1).to_offset_odd_q())
	return result


func _offsets_at_ring(origin: Vector2i, ring: int) -> Array[Vector2i]:
	if ring == 0:
		return [origin]
	var result: Array[Vector2i] = []
	var origin_hex := HexCoord.from_offset_odd_q(origin.x, origin.y)
	for delta_q in range(-ring, ring + 1):
		for delta_r in range(-ring, ring + 1):
			var candidate := origin_hex.add(HexCoord.new(delta_q, delta_r))
			if origin_hex.distance_to(candidate) == ring:
				result.append(candidate.to_offset_odd_q())
	return result


func inventory_status() -> Dictionary:
	var selected_definition: ItemDefinition = _inventory.selected_definition()
	var counts := PackedStringArray()
	var items: Array[Dictionary] = []
	var definitions := _inventory.definitions()
	for index in mini(3, definitions.size()):
		var definition := definitions[index]
		var count := _inventory.count_for(definition)
		counts.append("%s:%s" % [definition.display_name, _format_count(definition, count)])
		items.append({
			"name": definition.display_name,
			"icon": definition.icon,
			"count": count,
			"count_text": _format_count(definition, count),
			"catalog_index": index,
			"selected": definition == selected_definition,
			"shortcut": index + 1,
		})
	for dynamic_index in _dynamic_item_order.size():
		var definition := _dynamic_item_order[dynamic_index]
		var count := _inventory.count_for(definition)
		counts.append("%s:%s" % [definition.display_name, _format_count(definition, count)])
		if count <= 0.0:
			continue
		items.append({
			"name": definition.display_name,
			"icon": definition.icon,
			"count": count,
			"count_text": _format_count(definition, count),
			"catalog_index": definitions.find(definition),
			"selected": definition == selected_definition,
			"shortcut": dynamic_index + 4,
		})
	return {"selected_name": selected_definition.display_name if selected_definition != null else "", "counts": counts, "items": items, "flag_in_flight": is_flag_in_flight()}.duplicate(true)


func active_projectile_count() -> int:
	var count := 0
	for child in get_children():
		if child is WorldRigidBody2D:
			count += 1
	return count


func is_flag_in_flight() -> bool:
	return is_instance_valid(_active_flag_projectile)


func _is_dynamic_index(index: int) -> bool:
	return index >= 3


func _is_dynamic_definition(definition: ItemDefinition) -> bool:
	return _is_dynamic_index(_inventory.definitions().find(definition))


func _select_after_dynamic_depletion(definition: ItemDefinition) -> void:
	var definitions := _inventory.definitions()
	var depleted_index := definitions.find(definition)
	if depleted_index < 3 or _inventory.selected_definition() != definition:
		return
	for offset in range(1, definitions.size() + 1):
		var candidate_index := posmod(depleted_index + offset, definitions.size())
		var candidate := definitions[candidate_index]
		if not _is_dynamic_index(candidate_index) or _inventory.count_for(candidate) > 0.0:
			_inventory.select_index(candidate_index)
			return


func _format_count(definition: ItemDefinition, count: float) -> String:
	if definition != null and definition.count_display == ItemDefinition.CountDisplay.CEILING:
		return str(ceili(count))
	return str(roundi(count))


func _on_projectile_resolved(projectile: ItemProjectile, impact_position: Vector2, resolution_kind: StringName) -> void:
	projectile.action.resolve(self, impact_position, projectile, resolution_kind)


func _spawn_item_chests(chest_spawns: Array[GeneratedItemChestSpawn]) -> void:
	for spawn_data in chest_spawns:
		if spawn_data == null or spawn_data.definition == null or spawn_data.definition.chest_scene == null:
			continue
		var chest := spawn_data.definition.chest_scene.instantiate() as ItemChest
		if chest == null:
			continue
		add_child(chest)
		chest.configure(
			spawn_data,
			_hex_radius,
			_is_active,
			_simulation_backend,
			_world,
			_terrain_registry
		)
		_register_explosive(chest.explosive)
		chest.touched.connect(_on_item_chest_touched)
		chest.explosion_armed.connect(_on_item_chest_explosion_armed)
	_apply_container_perk_modifiers()


func _on_item_chest_touched(chest: ItemChest) -> void:
	if not _is_active or _pending_chest != null or chest == null or chest.spawn_data == null:
		return
	var definition := chest.spawn_data.definition
	if definition == null:
		return
	_pending_chest = chest
	_set_chest_interactivity(false)
	var view_choices: Array[RewardChoiceViewData] = []
	var choice_count := _reward_choice_count(definition)
	if definition.reward_kind == ItemChestDefinition.RewardKind.PERKS:
		if _perk_controller == null:
			_invalidate_pending_reward()
			return
		_pending_perk_choices = _perk_controller.draw_choices(chest.spawn_data.choice_seed, choice_count)
		if _pending_perk_choices.is_empty():
			chest.set_interactive(false)
			chest.set_light_emitting(false)
			_pending_chest = null
			return
		for perk in _pending_perk_choices:
			view_choices.append(RewardChoiceViewData.new(perk.display_name, perk.description, perk.icon, ""))
		reward_choices_requested.emit("Choose a perk", view_choices)
		return
	_pending_choices = definition.draw_choices(chest.spawn_data.choice_seed, choice_count)
	if _pending_choices.size() != choice_count:
		_invalidate_pending_reward()
		return
	for option in _pending_choices:
		view_choices.append(RewardChoiceViewData.new(option.item.display_name, option.item.description, option.item.icon, "+%d" % option.quantity))
	reward_choices_requested.emit("Choose an item", view_choices)


func _reward_choice_count(definition: ItemChestDefinition) -> int:
	var count := definition.choice_count
	if _perk_modifiers != null:
		count += int(_perk_modifiers.rewards.value("choice_count_add", 0))
	return clampi(count, 1, 3)


func _set_chest_interactivity(interactive: bool) -> void:
	for child in get_children():
		if child is ItemChest:
			(child as ItemChest).set_interactive(interactive)


func _apply_container_perk_modifiers() -> void:
	var container_domain = _perk_modifiers.containers if _perk_modifiers != null else null
	var indestructible := bool(container_domain.value("indestructible", false)) if container_domain != null else false
	var chest_light_add := int(container_domain.value("light_level_add", 0)) if container_domain != null else 0
	for child in get_children():
		var chest := child as ItemChest
		if chest == null:
			continue
		chest.set_destructible(not indestructible)
		if chest_light_add > 0 and chest.spawn_data != null and chest.spawn_data.definition != null and chest.spawn_data.definition.container_tags.has("item_chest"):
			chest.set_light_level_override(90 + chest_light_add)


func _apply_explosion_perk_modifiers(spec: ExplosionRuntimeSpec, source_item: ItemDefinition = null) -> void:
	if spec == null or _perk_modifiers == null:
		return
	var explosion_domain = _perk_modifiers.explosions
	spec.player_kill_radius = maxi(0, spec.player_kill_radius + int(explosion_domain.value("player_kill_radius_add", 0)))
	var terrain_bonus := int(explosion_domain.value("sand_liquid_vaporize_radius_add", 0))
	if source_item != null and source_item.perk_tags.has("small_bomb"):
		spec.blast_radius += int(explosion_domain.value("small_bomb_blast_radius_add", 0))
	if source_item != null and source_item.perk_tags.has("large_bomb"):
		spec.blast_radius += int(explosion_domain.value("large_bomb_blast_radius_add", 0))
		spec.vaporize_radius += int(explosion_domain.value("large_bomb_vaporize_radius_add", 0))
		spec.player_kill_radius += int(explosion_domain.value("large_bomb_player_kill_radius_add", 0))
	spec.vaporize_radius = clampi(spec.vaporize_radius, 0, spec.blast_radius)
	spec.player_kill_radius = clampi(spec.player_kill_radius, 0, spec.blast_radius)
	if terrain_bonus > 0:
		spec.fluid_vaporize_radius_bonus = func(definition: TerrainDefinition) -> int:
			return terrain_bonus if definition != null and (definition.perk_tags.has("sand") or definition.perk_tags.has("liquid")) else 0
	var dirt_vaporize_chance := float(_perk_modifiers.terrain.value("dirt_vaporize_chance", 0.0))
	if dirt_vaporize_chance > 0.0 and source_item != null and (source_item.perk_tags.has("small_bomb") or source_item.perk_tags.has("large_bomb")):
		spec.blast_vaporize_chance = func(terrain: TerrainDefinition, _cell: Vector2i) -> float:
			return dirt_vaporize_chance if terrain != null and terrain.perk_tags.has("dirt") else 0.0


func _should_preserve_item(definition: ItemDefinition) -> bool:
	if _perk_modifiers == null or definition == null:
		return false
	var chance := 0.0
	if definition.perk_tags.has("small_bomb"):
		chance = float(_perk_modifiers.items.value("small_bomb_preserve_chance", 0.0))
	elif definition.perk_tags.has("large_bomb"):
		chance = float(_perk_modifiers.items.value("large_bomb_preserve_chance", 0.0))
	elif definition.perk_tags.has("shovel") or definition.perk_tags.has("pickaxe"):
		chance = float(_perk_modifiers.items.value("shovel_pickaxe_preserve_chance", 0.0))
	if chance <= 0.0:
		return false
	var ordinal := int(_successful_use_counts.get(definition.stable_id, 0)) + 1
	_successful_use_counts[definition.stable_id] = ordinal
	var rng := RandomNumberGenerator.new()
	rng.seed = SeedUtils.derive_seed(_world.dimensions.width * 1000003 + _world.dimensions.depth, "%d:%d" % [definition.stable_id, ordinal])
	return rng.randf() < chance


func _register_explosive(explosive: WorldExplosive2D) -> void:
	if explosive == null or _explosives.has(explosive):
		return
	_explosives.append(explosive)
	explosive.set_active(_is_active)
	explosive.detonation_requested.connect(_on_explosive_detonation_requested)


func _forget_explosive(explosive: WorldExplosive2D) -> void:
	if explosive == null:
		return
	_explosives.erase(explosive)
	if explosive.detonation_requested.is_connected(_on_explosive_detonation_requested):
		explosive.detonation_requested.disconnect(_on_explosive_detonation_requested)


func _arm_explosives_in(lethal_cells: Array[Vector2i]) -> void:
	for explosive in _explosives.duplicate():
		if is_instance_valid(explosive):
			explosive.try_arm_from_lethal_cells(lethal_cells, _hex_radius)


func _on_explosive_detonation_requested(explosive: WorldExplosive2D) -> void:
	if explosive == null or not _explosives.has(explosive):
		return
	var definition := explosive.definition
	var impact_position := explosive.global_position
	var explosive_host := explosive.host()
	_forget_explosive(explosive)
	if explosive_host == _pending_chest:
		_invalidate_pending_reward()
	if explosive_host is ItemChest:
		var container := explosive_host as ItemChest
		if container.spawn_data != null and container.spawn_data.definition != null and container.spawn_data.definition.destruction_pulse != null:
			var origin := HexMetrics.offset_for_world(container.global_position, _hex_radius)
			var pulse_definition := container.spawn_data.definition.destruction_pulse
			_terrain_pulses.append(DirectionalTerrainPulse.new(pulse_definition, origin))
			terrain_pulse_started.emit(HexMetrics.center_for_offset(origin.x, origin.y, _hex_radius), pulse_definition)
	if is_instance_valid(explosive_host):
		explosive_host.queue_free()
	var source_item: ItemDefinition
	if explosive_host is ItemProjectile:
		var projectile := explosive_host as ItemProjectile
		if projectile.action != null:
			source_item = projectile.action.definition
	resolve_explosion(definition, impact_position, source_item)


func _on_item_chest_explosion_armed(chest: ItemChest) -> void:
	if chest == _pending_chest:
		_invalidate_pending_reward()


func _invalidate_pending_reward() -> void:
	_pending_chest = null
	_pending_choices.clear()
	_set_chest_interactivity(_is_active)
	pending_reward_invalidated.emit()
