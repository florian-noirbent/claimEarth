## Moves terrain-overlapped bodies toward the nearest Air cell without shape-specific policy.
class_name TerrainBodyUnstuckSolver
extends RefCounted


func resolve_circle(
	position: Vector2,
	velocity: Vector2,
	delta: float,
	query: TerrainCollisionQuery,
	radius: float,
	search_ring: int,
	push_speed: float
) -> TerrainBodyUnstuckResult:
	var result := TerrainBodyUnstuckResult.new(position, velocity)
	if query == null or delta <= 0.0 or not query.circle_overlaps_solid(position, radius):
		return result
	return _move_toward_air(result, delta, query, search_ring, push_speed)


func resolve_polygon(
	position: Vector2,
	velocity: Vector2,
	delta: float,
	query: TerrainCollisionQuery,
	local_polygon: PackedVector2Array,
	rotation: float,
	search_ring: int,
	push_speed: float
) -> TerrainBodyUnstuckResult:
	var result := TerrainBodyUnstuckResult.new(position, velocity)
	if query == null or delta <= 0.0:
		return result
	var transform := Transform2D(rotation, position)
	var world_polygon := PackedVector2Array()
	for point in local_polygon:
		world_polygon.append(transform * point)
	if not query.convex_polygon_overlaps_solid(world_polygon):
		return result
	return _move_toward_air(result, delta, query, search_ring, push_speed)


func _move_toward_air(
	result: TerrainBodyUnstuckResult,
	delta: float,
	query: TerrainCollisionQuery,
	search_ring: int,
	push_speed: float
) -> TerrainBodyUnstuckResult:
	var air_center_variant = query.nearest_air_cell_center(result.position, search_ring)
	if air_center_variant == null:
		return result
	var escape_vector := (air_center_variant as Vector2) - result.position
	var distance := escape_vector.length()
	if distance <= 0.001:
		return result
	var escape_direction := escape_vector / distance
	result.position += escape_direction * minf(distance, maxf(push_speed, 0.0) * delta)
	var escape_speed := result.velocity.dot(escape_direction)
	if escape_speed < 0.0:
		result.velocity -= escape_direction * escape_speed
	result.moved = true
	return result
