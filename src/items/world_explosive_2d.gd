@tool
## Reusable one-shot explosive state and destructive-core footprint receiver.
class_name WorldExplosive2D
extends Node2D


signal chain_armed(explosive: WorldExplosive2D)
signal detonation_requested(explosive: WorldExplosive2D)

enum State {
	UNARMED,
	CHAIN_ARMED,
	CONSUMED,
}

var definition: ExplosionDefinition
var _local_footprint := PackedVector2Array()
var _state := State.UNARMED
var _chain_fuse_remaining := 0.0
var _active := true
var _host: Node


func configure(
	definition_value: ExplosionDefinition,
	local_footprint: PackedVector2Array = PackedVector2Array(),
	host_value: Node = null
) -> void:
	definition = definition_value
	_local_footprint = local_footprint.duplicate()
	_host = host_value
	_state = State.UNARMED
	_chain_fuse_remaining = 0.0
	set_physics_process(_active)


func set_active(is_active: bool) -> void:
	_active = is_active
	set_physics_process(is_active)


func try_arm_from_lethal_cells(lethal_cells: Array[Vector2i], hex_radius: float) -> bool:
	if _state != State.UNARMED or definition == null or not _overlaps_any_cell(lethal_cells, hex_radius):
		return false
	_state = State.CHAIN_ARMED
	_chain_fuse_remaining = definition.chain_fuse_seconds
	chain_armed.emit(self)
	if _chain_fuse_remaining <= 0.0:
		request_immediate_detonation()
	return true


func try_arm_from_destructive_core_cells(cells: Array[Vector2i], hex_radius: float) -> bool:
	return try_arm_from_lethal_cells(cells, hex_radius)


func request_immediate_detonation() -> bool:
	if _state == State.CONSUMED or definition == null:
		return false
	_state = State.CONSUMED
	_chain_fuse_remaining = 0.0
	detonation_requested.emit(self)
	return true


func is_chain_armed() -> bool:
	return _state == State.CHAIN_ARMED


func disarm() -> void:
	if _state == State.CHAIN_ARMED:
		_state = State.UNARMED
		_chain_fuse_remaining = 0.0


func is_consumed() -> bool:
	return _state == State.CONSUMED


func chain_fuse_remaining() -> float:
	return _chain_fuse_remaining


func host() -> Node:
	return _host if is_instance_valid(_host) else get_parent()


func _physics_process(delta: float) -> void:
	if not _active or _state != State.CHAIN_ARMED or delta <= 0.0:
		return
	_chain_fuse_remaining = maxf(0.0, _chain_fuse_remaining - delta)
	if _chain_fuse_remaining <= 0.0:
		request_immediate_detonation()


func _overlaps_any_cell(cells: Array[Vector2i], hex_radius: float) -> bool:
	if cells.is_empty():
		return false
	if _local_footprint.is_empty():
		var own_cell := HexMetrics.offset_for_world(global_position, hex_radius)
		return cells.has(own_cell)
	var world_polygon := PackedVector2Array()
	for point in _local_footprint:
		world_polygon.append(global_transform * point)
	var hex_corners := HexMetrics.corners(hex_radius)
	for cell in cells:
		var center := HexMetrics.center_for_offset(cell.x, cell.y, hex_radius)
		var hex_polygon := PackedVector2Array()
		for corner in hex_corners:
			hex_polygon.append(center + corner)
		if _convex_polygons_overlap(world_polygon, hex_polygon):
			return true
	return false


func _convex_polygons_overlap(left: PackedVector2Array, right: PackedVector2Array) -> bool:
	return not _has_separating_axis(left, right) and not _has_separating_axis(right, left)


func _has_separating_axis(source: PackedVector2Array, other: PackedVector2Array) -> bool:
	for index in source.size():
		var edge := source[(index + 1) % source.size()] - source[index]
		if edge.length_squared() <= 0.000001:
			continue
		var axis := Vector2(-edge.y, edge.x).normalized()
		var source_range := _projection_range(source, axis)
		var other_range := _projection_range(other, axis)
		if source_range.y < other_range.x or other_range.y < source_range.x:
			return true
	return false


func _projection_range(polygon: PackedVector2Array, axis: Vector2) -> Vector2:
	var minimum := polygon[0].dot(axis)
	var maximum := minimum
	for index in range(1, polygon.size()):
		var projection := polygon[index].dot(axis)
		minimum = minf(minimum, projection)
		maximum = maxf(maximum, projection)
	return Vector2(minimum, maximum)
