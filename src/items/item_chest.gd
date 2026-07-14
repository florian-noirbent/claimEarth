@tool
## Vertically falling, terrain-aware item chest with touch, light, and explosive components.
class_name ItemChest
extends Node2D


signal touched(chest: ItemChest)
signal explosion_armed(chest: ItemChest)

const TerrainCollisionQueryScript = preload("res://src/world/terrain_collision_query.gd")
const TerrainBodyUnstuckSolverScript = preload("res://src/world/terrain_body_unstuck_solver.gd")
const GROUNDED_CHECK_INTERVAL := 0.1

@onready var visual_root: Node2D = %VisualRoot
@onready var sprite: Sprite2D = %Sprite
@onready var touch_area: Area2D = %TouchArea
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var light_source: WorldLightSource2D = %WorldLightSource
@onready var explosive: WorldExplosive2D = %WorldExplosive

var spawn_data: GeneratedItemChestSpawn
var fall_velocity := 0.0
var _interactive_requested := false
var _hex_radius := 8.0
var _terrain_query = TerrainCollisionQueryScript.new()
var _unstuck_solver = TerrainBodyUnstuckSolverScript.new()
var _body_polygon := PackedVector2Array()
var _runtime_physics := false
var _active := false
var _grounded := false
var _grounded_check_remaining := 0.0


func _ready() -> void:
	touch_area.body_entered.connect(_on_body_entered)
	explosive.chain_armed.connect(_on_explosion_chain_armed)
	_apply_geometry()
	set_physics_process(false)


func configure(
	data: GeneratedItemChestSpawn,
	hex_radius: float,
	interactive: bool,
	simulation_backend: TerrainSimulationBackend = null,
	world: WorldGrid = null,
	terrain_registry: TerrainRegistry = null
) -> void:
	spawn_data = data
	_hex_radius = hex_radius
	_apply_geometry()
	if data != null:
		global_position = generated_center_position(data.anchor_offset)
	if light_source != null and data != null and data.definition != null:
		light_source.configure(simulation_backend, _hex_radius, _chest_light_source_id(data))
	if explosive != null and data != null and data.definition != null:
		explosive.configure(data.definition.explosion_definition, _body_polygon, self)
	_runtime_physics = world != null and terrain_registry != null
	if _runtime_physics:
		_terrain_query.configure(world, CompiledTerrainData.compile(terrain_registry), _hex_radius)
	set_active(interactive, interactive)


func set_active(is_active: bool, interactive_allowed: bool = true) -> void:
	_active = is_active
	set_physics_process(is_active and _runtime_physics)
	if explosive != null:
		explosive.set_active(is_active)
	set_interactive(is_active and interactive_allowed)


func set_interactive(interactive: bool) -> void:
	_interactive_requested = interactive
	var enabled := interactive and (explosive == null or not explosive.is_chain_armed())
	if touch_area == null:
		return
	if is_inside_tree():
		touch_area.set_deferred("monitoring", enabled)
	else:
		touch_area.monitoring = enabled


func displayed_size() -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	return sprite.texture.get_size() * sprite.scale.abs()


func generated_center_position(anchor_offset: Vector2i) -> Vector2:
	return HexMetrics.center_for_offset(anchor_offset.x, anchor_offset.y, _hex_radius) + Vector2(
		0.0,
		sqrt(3.0) * 0.5 * _hex_radius - displayed_size().y * 0.5
	)


func set_light_emitting(is_emitting: bool) -> void:
	if light_source != null:
		light_source.set_emitting(is_emitting)


func is_grounded() -> bool:
	return _grounded


func _physics_process(delta: float) -> void:
	if not _active or not _runtime_physics or delta <= 0.0 or spawn_data == null or spawn_data.definition == null:
		return
	if _grounded:
		_grounded_check_remaining = maxf(0.0, _grounded_check_remaining - delta)
		if _grounded_check_remaining > 0.0:
			return
		_grounded_check_remaining = GROUNDED_CHECK_INTERVAL
	var definition := spawn_data.definition
	var supported := _polygon_overlaps_at(global_position + Vector2(0.0, 0.75), visual_root.rotation)
	if not supported:
		_grounded = false
		visual_root.rotation = 0.0
		fall_velocity = minf(definition.terminal_fall_speed, fall_velocity + definition.gravity * delta)
		_sweep_down(fall_velocity * delta)
	else:
		_grounded = true
		_grounded_check_remaining = GROUNDED_CHECK_INTERVAL
		fall_velocity = 0.0
		_apply_support_tilt()
	_apply_terrain_unstuck(delta)


func _sweep_down(distance: float) -> void:
	if distance <= 0.0:
		return
	var step_count := maxi(1, ceili(distance / maxf(1.0, _hex_radius * 0.375)))
	var step_distance := distance / float(step_count)
	for _step in step_count:
		var previous := global_position
		var candidate := previous + Vector2(0.0, step_distance)
		if not _polygon_overlaps_at(candidate, 0.0):
			global_position = candidate
			continue
		var lower := previous
		var upper := candidate
		for _iteration in 8:
			var middle := lower.lerp(upper, 0.5)
			if _polygon_overlaps_at(middle, 0.0):
				upper = middle
			else:
				lower = middle
		global_position = lower
		fall_velocity = 0.0
		_grounded = true
		_grounded_check_remaining = GROUNDED_CHECK_INTERVAL
		_apply_support_tilt()
		return


func _apply_support_tilt() -> void:
	var definition := spawn_data.definition
	var half_size := _body_half_size()
	var left_distance := _support_distance(-half_size.x * 0.72, half_size.y, definition.support_probe_distance)
	var right_distance := _support_distance(half_size.x * 0.72, half_size.y, definition.support_probe_distance)
	var target := 0.0
	var tolerance := maxf(1.0, _hex_radius * 0.15)
	if left_distance < INF and right_distance < INF and absf(left_distance - right_distance) > tolerance:
		target = deg_to_rad(definition.uneven_ground_tilt_degrees) * signf(right_distance - left_distance)
	elif left_distance < INF and right_distance == INF:
		target = deg_to_rad(definition.uneven_ground_tilt_degrees)
	elif right_distance < INF and left_distance == INF:
		target = -deg_to_rad(definition.uneven_ground_tilt_degrees)
	visual_root.rotation = target
	if is_zero_approx(target):
		return
	for _step in ceili(_hex_radius * 2.0):
		if not _polygon_overlaps_at(global_position, target):
			break
		global_position.y -= 1.0


func _support_distance(local_x: float, local_bottom: float, maximum: float) -> float:
	var step_count := ceili(maximum)
	for distance in range(step_count + 1):
		var sample := global_position + Vector2(local_x, local_bottom + float(distance))
		if _terrain_query.is_solid_at_world(sample):
			return float(distance)
	return INF


func _apply_terrain_unstuck(delta: float) -> void:
	var definition := spawn_data.definition
	var result := _unstuck_solver.resolve_polygon(
		global_position,
		Vector2(0.0, fall_velocity),
		delta,
		_terrain_query,
		_body_polygon,
		visual_root.rotation,
		definition.terrain_unstuck_search_ring,
		definition.terrain_unstuck_push_speed
	)
	global_position = result.position
	fall_velocity = result.velocity.y
	if result.moved:
		_grounded = false
		_grounded_check_remaining = 0.0


func _polygon_overlaps_at(center: Vector2, rotation_value: float) -> bool:
	var transform := Transform2D(rotation_value, center)
	var polygon := PackedVector2Array()
	for point in _body_polygon:
		polygon.append(transform * point)
	return _terrain_query.convex_polygon_overlaps_solid(polygon)


func _body_half_size() -> Vector2:
	return Vector2(3.25 * _hex_radius, 2.0 * _hex_radius) * 0.5


func _apply_geometry() -> void:
	if not is_node_ready() or sprite.texture == null:
		return
	var target_width := 3.5 * _hex_radius
	var uniform_scale := target_width / maxf(1.0, sprite.texture.get_width())
	sprite.scale = Vector2.ONE * uniform_scale
	sprite.position = Vector2.ZERO
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(3.25 * _hex_radius, 2.0 * _hex_radius)
	var half_size := _body_half_size()
	_body_polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
func _on_body_entered(body: Node) -> void:
	if not _interactive_requested or (explosive != null and explosive.is_chain_armed()) or not body is PlayerController:
		return
	_interactive_requested = false
	touch_area.set_deferred("monitoring", false)
	touched.emit(self)


func _on_explosion_chain_armed(_source: WorldExplosive2D) -> void:
	set_interactive(false)
	explosion_armed.emit(self)


func _chest_light_source_id(data: GeneratedItemChestSpawn) -> StringName:
	return StringName("item_chest:%d:%d" % [data.anchor_offset.x, data.anchor_offset.y])
