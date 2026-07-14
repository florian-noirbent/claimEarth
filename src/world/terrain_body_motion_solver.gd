## Moves circular bodies through committed terrain using TerrainCollisionQuery.
class_name TerrainBodyMotionSolver
extends RefCounted


const TerrainBodyMotionResultScript = preload("res://src/world/terrain_body_motion_result.gd")

const MAX_RESOLVE_ITERATIONS := 5
const MAX_STEP_DISTANCE := 6.0
const GROUND_NORMAL_Y := -0.35

var query


func configure(query_value) -> void:
	query = query_value


func move_circle(
	position: Vector2,
	velocity: Vector2,
	delta: float,
	radius: float,
	step_up_height: float,
	support_probe_distance: float,
	allow_step_up: bool = true
):
	var result = TerrainBodyMotionResultScript.new(position, velocity, false)
	if query == null or not query.is_configured() or delta <= 0.0:
		return result

	var motion := velocity * delta
	var current_position := position
	if allow_step_up and absf(motion.x) > 0.001:
		current_position = _try_step_up(current_position, Vector2(motion.x, 0.0), radius, step_up_height)

	var step_count := maxi(1, ceili(motion.length() / MAX_STEP_DISTANCE))
	var step_motion := motion / float(step_count)
	var current_velocity := velocity
	for _step_index in range(step_count):
		current_position += step_motion
		var resolved := _resolve_overlaps(current_position, current_velocity, radius)
		current_position = resolved["position"] as Vector2
		current_velocity = resolved["velocity"] as Vector2
		_apply_contacts_to_result(result, resolved["contacts"] as Array[Dictionary])

	var contact_grounded := _contacts_include_floor(result.hit_normals)
	var can_probe_support := absf(velocity.y) <= 0.001
	var grounded := contact_grounded or (can_probe_support and _has_floor_support(
		current_position,
		radius,
		support_probe_distance
	))

	result.position = current_position
	result.velocity = current_velocity
	result.grounded = grounded
	if result.collided:
		result.velocity_change = current_velocity - velocity
	if result.grounded and result.floor_normal == Vector2.UP:
		result.floor_normal = _best_floor_normal(result.hit_normals)
	return result


func resolve_circle(position: Vector2, velocity: Vector2, radius: float):
	var resolved := _resolve_overlaps(position, velocity, radius)
	var contacts := resolved["contacts"] as Array[Dictionary]
	var result = TerrainBodyMotionResultScript.new(
		resolved["position"] as Vector2,
		resolved["velocity"] as Vector2,
		_contacts_include_floor(_contact_normals(contacts))
	)
	_apply_contacts_to_result(result, contacts)
	if result.collided:
		result.velocity_change = result.velocity - velocity
	return result


func _try_step_up(position: Vector2, horizontal_motion: Vector2, radius: float, step_up_height: float) -> Vector2:
	if step_up_height <= 0.0 or not query.circle_overlaps_solid(position + horizontal_motion, radius):
		return position
	var step_increments := [step_up_height * 0.34, step_up_height * 0.67, step_up_height]
	for step_height in step_increments:
		var raised := position + Vector2(0.0, -step_height)
		if query.circle_overlaps_solid(raised, radius):
			continue
		if query.circle_overlaps_solid(raised + horizontal_motion, radius):
			continue
		return raised
	return position


func _resolve_overlaps(position: Vector2, velocity: Vector2, radius: float) -> Dictionary:
	var current_position := position
	var current_velocity := velocity
	var all_contacts: Array[Dictionary] = []
	for _iteration in range(MAX_RESOLVE_ITERATIONS):
		var contacts: Array[Dictionary] = query.circle_contacts(current_position, radius)
		if contacts.is_empty():
			break
		var strongest := _strongest_contact(contacts)
		var normal := strongest["normal"] as Vector2
		var depth := float(strongest["depth"])
		current_position += normal * (depth + 0.01)
		var inward_speed := current_velocity.dot(normal)
		if inward_speed < 0.0:
			current_velocity -= normal * inward_speed
		all_contacts.append(strongest)
	return {
		"position": current_position,
		"velocity": current_velocity,
		"contacts": all_contacts,
	}


func _has_floor_support(position: Vector2, radius: float, support_probe_distance: float) -> bool:
	if support_probe_distance <= 0.0:
		return false
	return not query.support_contact(position, radius, support_probe_distance).is_empty()


func _strongest_contact(contacts: Array[Dictionary]) -> Dictionary:
	var strongest := contacts[0]
	for contact in contacts:
		if float(contact["depth"]) > float(strongest["depth"]):
			strongest = contact
	return strongest


func _apply_contacts_to_result(result, contacts: Array[Dictionary]) -> void:
	for contact in contacts:
		var normal := contact["normal"] as Vector2
		result.collided = true
		result.hit_normals.append(normal)
		if normal.y < GROUND_NORMAL_Y and normal.y < result.floor_normal.y:
			result.floor_normal = normal


func _contact_normals(contacts: Array[Dictionary]) -> Array[Vector2]:
	var normals: Array[Vector2] = []
	for contact in contacts:
		normals.append(contact["normal"] as Vector2)
	return normals


func _contacts_include_floor(normals: Array[Vector2]) -> bool:
	for normal in normals:
		if normal.y < GROUND_NORMAL_Y:
			return true
	return false


func _best_floor_normal(normals: Array[Vector2]) -> Vector2:
	var best := Vector2.UP
	for normal in normals:
		if normal.y < best.y:
			best = normal
	return best
