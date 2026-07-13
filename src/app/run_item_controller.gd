## Owns inventory, projectile lifecycle, explosions, and flag resolution for a run.
class_name RunItemController
extends Node


signal player_killed(cause: StringName)
signal bomb_exploded(impact_position: Vector2, color: Color, blast_radius: int, is_large: bool)
signal flag_planted(depth: int, landing_position: Vector2)
signal flag_destroyed
signal flag_flight_changed(in_flight: bool)
signal item_thrown
signal terrain_changed(change_set: TerrainChangeSet)

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


func configure_catalog(item_registry: ItemRegistry, hex_radius: float) -> void:
	_inventory.configure(item_registry)
	_hex_radius = hex_radius


func configure_run(player: PlayerController, world: WorldGrid, terrain_registry: TerrainRegistry, hex_radius: float, simulation_backend: TerrainSimulationBackend = null) -> void:
	_inventory.reset()
	_player = player
	_world = world
	_terrain_registry = terrain_registry
	_simulation_backend = simulation_backend
	_hex_radius = hex_radius
	_active_flag_projectile = null
	_throw_lock_remaining = 1.0
	flag_flight_changed.emit(false)


func clear_run() -> void:
	_player = null
	_world = null
	_simulation_backend = null
	_active_flag_projectile = null
	for child in get_children():
		if child is ItemProjectile:
			child.free()


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
	projectile.resolved.connect(_on_projectile_resolved)
	add_child(projectile)
	item_thrown.emit()
	if action.locks_throwing_until_resolved():
		_active_flag_projectile = projectile
		flag_flight_changed.emit(true)
	return true


func resolve_bomb_explosion(item_action: ItemAction, impact_position: Vector2, _projectile: ItemProjectile) -> void:
	if _world == null:
		return
	if _player != null and _player.global_position.distance_to(impact_position) <= item_action.factory.lethal_radius * _hex_radius:
		player_killed.emit(DeathCause.BOMB)
	var change_set := _explosion_service.explode_with_changes(_world, _terrain_registry, impact_position, _hex_radius, item_action.factory.blast_radius, item_action.factory.lethal_radius)
	if _simulation_backend != null:
		_simulation_backend.notify_external_changes(change_set)
	terrain_changed.emit(change_set)
	var is_large: bool = item_action.factory.blast_radius >= 4
	bomb_exploded.emit(impact_position, item_action.factory.projectile_color, item_action.factory.blast_radius, is_large)


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
