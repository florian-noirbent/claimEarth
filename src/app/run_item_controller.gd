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
signal reward_choices_requested(choices: Array)
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
var _is_active := false
var _explosives: Array[WorldExplosive2D] = []


func configure_catalog(item_registry: ItemRegistry, hex_radius: float) -> void:
	_item_registry = item_registry
	_inventory.configure(item_registry)
	_hex_radius = hex_radius


func configure_run(
	player: PlayerController,
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	hex_radius: float,
	simulation_backend: TerrainSimulationBackend = null,
	chest_spawns: Array[GeneratedItemChestSpawn] = []
) -> void:
	_inventory.reset()
	_player = player
	_world = world
	_terrain_registry = terrain_registry
	_simulation_backend = simulation_backend
	_hex_radius = hex_radius
	_active_flag_projectile = null
	_pending_chest = null
	_pending_choices.clear()
	_explosives.clear()
	_throw_lock_remaining = 1.0
	_spawn_item_chests(chest_spawns)
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
	_explosives.clear()
	for child in get_children():
		if child is ItemProjectile or child is ItemChest:
			child.free()


func set_active(is_active: bool) -> void:
	_is_active = is_active
	for child in get_children():
		if child is ItemProjectile:
			child.set_physics_process(is_active)
		elif child is ItemChest:
			(child as ItemChest).set_active(is_active, _pending_chest == null)
	for explosive in _explosives:
		if is_instance_valid(explosive):
			explosive.set_active(is_active)


func apply_pending_reward(choice_index: int) -> bool:
	if _pending_chest == null or choice_index < 0 or choice_index >= _pending_choices.size():
		return false
	var option := _pending_choices[choice_index]
	if option == null or option.item == null or _item_registry == null:
		return false
	var registered_item := _item_registry.get_definition(option.item.stable_id)
	if registered_item == null or not _inventory.add(registered_item, option.quantity):
		return false
	var claimed_chest := _pending_chest
	claimed_chest.set_light_emitting(false)
	_forget_explosive(claimed_chest.explosive)
	_pending_chest = null
	_pending_choices.clear()
	if is_instance_valid(claimed_chest):
		claimed_chest.queue_free()
	_set_chest_interactivity(_is_active)
	return true


func cancel_pending_reward() -> void:
	_pending_chest = null
	_pending_choices.clear()
	_set_chest_interactivity(_is_active)


func item_chest_count() -> int:
	var count := 0
	for child in get_children():
		if child is ItemChest and not child.is_queued_for_deletion():
			count += 1
	return count


func advance(delta: float) -> void:
	_throw_lock_remaining = maxf(0.0, _throw_lock_remaining - delta)


func select_index(index: int) -> void:
	_inventory.select_index(index)


func cycle_selection(direction: int) -> void:
	var definitions := _inventory.definitions()
	if definitions.is_empty() or direction == 0:
		return
	var selected_definition := _inventory.selected_definition()
	var selected_index := definitions.find(selected_definition)
	_inventory.select_index(posmod(selected_index + signi(direction), definitions.size()))


func throw_selected(aim_position: Vector2, bypass_cooldown: bool = false) -> bool:
	if _player == null or _world == null:
		return false
	if not bypass_cooldown and _throw_lock_remaining > 0.0:
		return false
	var definition: ItemDefinition = _inventory.selected_definition()
	if definition == null or not _inventory.consume(definition):
		return false
	var action: ItemAction = definition.action_factory.create_action(definition)
	var projectile_data: Dictionary = action.create_projectile(_player.global_position, aim_position, _trajectory_service, _player.velocity)
	var projectile: ItemProjectile = ItemProjectileScript.new()
	projectile.action = action
	projectile.world = _world
	projectile.terrain_registry = _terrain_registry
	projectile.hex_radius = _hex_radius
	projectile.global_position = _player.global_position
	projectile.configure(projectile_data)
	_register_explosive(projectile.explosive)
	projectile.set_physics_process(_is_active)
	projectile.resolved.connect(_on_projectile_resolved)
	add_child(projectile)
	item_thrown.emit()
	if action.locks_throwing_until_resolved():
		_active_flag_projectile = projectile
		flag_flight_changed.emit(true)
	return true


func resolve_explosion(definition: ExplosionDefinition, impact_position: Vector2) -> void:
	if _world == null or definition == null or not definition.validate().is_empty():
		return
	if _player != null and _player.global_position.distance_to(impact_position) <= definition.lethal_radius * _hex_radius:
		player_killed.emit(DeathCause.BOMB)
	_apply_projectile_blast_impulses(definition, impact_position)
	var result := _explosion_service.resolve(
		_world,
		_terrain_registry,
		impact_position,
		_hex_radius,
		definition.blast_radius,
		definition.lethal_radius
	)
	var change_set := result.terrain_changes
	if _simulation_backend != null:
		_simulation_backend.notify_external_changes(change_set)
	terrain_changed.emit(change_set)
	explosion_resolved.emit(impact_position, definition.effect_color, definition.blast_radius, definition.large_feedback)
	_arm_explosives_in(result.lethal_cells)


func _apply_projectile_blast_impulses(definition: ExplosionDefinition, impact_position: Vector2) -> void:
	var world_radius := definition.blast_radius * _hex_radius
	for child in get_children():
		if child is ItemProjectile and not child.is_queued_for_deletion():
			(child as ItemProjectile).apply_blast_impulse(impact_position, definition.blast_impulse, world_radius)


func resolve_flag_landing(_item_action: ItemAction, impact_position: Vector2, _projectile: ItemProjectile, resolution_kind: StringName) -> void:
	_active_flag_projectile = null
	flag_flight_changed.emit(false)
	if resolution_kind == &"lava":
		flag_destroyed.emit()
	elif resolution_kind == &"impact":
		var landing_depth := maxi(0, HexMetrics.offset_for_world(impact_position, _hex_radius).y)
		flag_planted.emit(landing_depth, impact_position)


func inventory_status() -> Dictionary:
	var selected_definition: ItemDefinition = _inventory.selected_definition()
	var counts := PackedStringArray()
	var items: Array[Dictionary] = []
	var definitions := _inventory.definitions()
	for index in definitions.size():
		var definition := definitions[index]
		var count := _inventory.count_for(definition)
		counts.append("%s:%d" % [definition.display_name, _inventory.count_for(definition)])
		items.append({
			"name": definition.display_name,
			"icon": definition.icon,
			"count": count,
			"selected": definition == selected_definition,
			"shortcut": index + 1,
		})
	return {"selected_name": selected_definition.display_name if selected_definition != null else "", "counts": counts, "items": items, "flag_in_flight": is_flag_in_flight()}.duplicate(true)


func active_projectile_count() -> int:
	var count := 0
	for child in get_children():
		if child is ItemProjectile:
			count += 1
	return count


func is_flag_in_flight() -> bool:
	return is_instance_valid(_active_flag_projectile)


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


func _on_item_chest_touched(chest: ItemChest) -> void:
	if not _is_active or _pending_chest != null or chest == null or chest.spawn_data == null:
		return
	var definition := chest.spawn_data.definition
	if definition == null:
		return
	var choices := definition.draw_choices(chest.spawn_data.choice_seed)
	if choices.size() != definition.choice_count:
		return
	_pending_chest = chest
	_pending_choices = choices
	_set_chest_interactivity(false)
	var view_choices: Array[RewardChoiceViewData] = []
	for option in choices:
		view_choices.append(RewardChoiceViewData.new(
			option.item.display_name,
			option.item.description,
			option.item.icon,
			"+%d" % option.quantity
		))
	reward_choices_requested.emit(view_choices)


func _set_chest_interactivity(interactive: bool) -> void:
	for child in get_children():
		if child is ItemChest:
			(child as ItemChest).set_interactive(interactive)


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
	if is_instance_valid(explosive_host):
		explosive_host.queue_free()
	resolve_explosion(definition, impact_position)


func _on_item_chest_explosion_armed(chest: ItemChest) -> void:
	if chest == _pending_chest:
		_invalidate_pending_reward()


func _invalidate_pending_reward() -> void:
	_pending_chest = null
	_pending_choices.clear()
	_set_chest_interactivity(_is_active)
	pending_reward_invalidated.emit()
