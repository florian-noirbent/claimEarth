## Simulates the loose parts of a dismembered body as circles against the hex terrain:
## gravity, drag, bounce, friction, rolling, slowdown in liquids, and rest. It is pure
## state stepped by its owner, uses no physics bodies, and is repeatable for equal input.
class_name GibSimulation
extends RefCounted


## Contacts at least this upright count as ground a gib can rest on.
const FLOOR_NORMAL_Y := -0.35
## Share of its radius a gib may travel per substep, so it cannot skip a terrain cell.
const SUBSTEP_TRAVEL := 0.8
const MAX_SUBSTEPS := 6
const RESOLVE_PASSES := 3
## Gap left between a pushed-out gib and the surface it touched.
const CONTACT_SLOP := 0.01

## Downward acceleration in px/s².
var gravity := 1400.0
## Exponential velocity loss per second in open air.
var air_drag := 0.4
## Exponential spin loss per second.
var spin_drag := 0.6
## Share of the tangential speed a contact removes per unit of normal speed it stops.
var friction := 0.3
## Multiplies every gib's restitution; the owner lowers it to bring the gibs to rest.
var restitution_scale := 1.0
## Extra sideways drag; the owner raises it to bring the gibs to rest without slowing
## their fall.
var settle_drag := 0.0
## How strongly a contact turns sliding into rolling, from 0 to 1.
var roll_coupling := 0.5
## Multiplies the fill-weighted viscosity of the terrain a gib is inside.
var liquid_drag_scale := 1.0
## Share of gravity a liquid cancels; 1 floats, above 1 rises.
var buoyancy := 0.0
## A normal speed below this no longer bounces.
var bounce_min_speed := 60.0
## A grounded gib slower than this for rest_seconds falls asleep.
var rest_speed := 30.0
var rest_seconds := 0.2
## Physics steps between two support checks of a sleeping gib.
var support_check_steps := 10
## A gib farther than this from the origin is lost: it stops for good.
var maximum_distance := 4000.0

var _query: TerrainCollisionQuery
var _origin := Vector2.ZERO
var _positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _angles := PackedFloat32Array()
var _spins := PackedFloat32Array()
var _radii := PackedFloat32Array()
var _restitutions := PackedFloat32Array()
var _rest_times := PackedFloat32Array()
var _asleep := PackedByteArray()
var _grounded := PackedByteArray()
var _impact_speeds := PackedFloat32Array()
var _impact_normals := PackedVector2Array()
var _step_count := 0


## Sets the terrain the gibs collide with and the point distances are measured from. A
## null or unconfigured query leaves the gibs in free fall until they are lost.
func configure(query: TerrainCollisionQuery, origin: Vector2) -> void:
	_query = query if query != null and query.is_configured() else null
	_origin = origin


## Adds a gib and returns its index. spin is in radians per second.
func add_gib(
	position: Vector2,
	velocity: Vector2,
	angle: float,
	spin: float,
	radius: float,
	restitution: float
) -> int:
	_positions.append(position)
	_velocities.append(velocity)
	_angles.append(angle)
	_spins.append(spin)
	_radii.append(maxf(radius, 0.5))
	_restitutions.append(clampf(restitution, 0.0, 1.0))
	_rest_times.append(0.0)
	_asleep.append(0)
	_grounded.append(0)
	_impact_speeds.append(0.0)
	_impact_normals.append(Vector2.ZERO)
	return _positions.size() - 1


func count() -> int:
	return _positions.size()


func position_of(index: int) -> Vector2:
	return _positions[index]


func velocity_of(index: int) -> Vector2:
	return _velocities[index]


func angle_of(index: int) -> float:
	return _angles[index]


func spin_of(index: int) -> float:
	return _spins[index]


func radius_of(index: int) -> float:
	return _radii[index]


func set_radius(index: int, radius: float) -> void:
	_radii[index] = maxf(radius, 0.5)


func is_asleep(index: int) -> bool:
	return _asleep[index] != 0


func is_grounded(index: int) -> bool:
	return _grounded[index] != 0


func all_asleep() -> bool:
	for flag in _asleep:
		if flag == 0:
			return false
	return true


## Normal speed the gib lost against terrain in the last step, or 0 without a hit.
func impact_speed_of(index: int) -> float:
	return _impact_speeds[index]


## Surface normal of the hit impact_speed_of reports.
func impact_normal_of(index: int) -> Vector2:
	return _impact_normals[index]


func step(delta: float) -> void:
	if delta <= 0.0:
		return
	_step_count += 1
	for index in _positions.size():
		_impact_speeds[index] = 0.0
		if _asleep[index] != 0:
			if (_step_count + index) % maxi(support_check_steps, 1) == 0 and _lost_support(index):
				_asleep[index] = 0
				_rest_times[index] = 0.0
			continue
		_step_gib(index, delta)


func _step_gib(index: int, delta: float) -> void:
	var position := _positions[index]
	var velocity := _velocities[index]
	var spin := _spins[index]
	var radius := _radii[index]
	var viscosity := 0.0
	if _query != null:
		viscosity = _query.quantity_weighted_viscosity_at_world(position) * liquid_drag_scale
	var sink := 1.0 - buoyancy if viscosity > 0.0 else 1.0
	velocity.y += gravity * sink * delta
	velocity *= exp(-(air_drag + viscosity) * delta)
	velocity.x *= exp(-settle_drag * delta)
	spin *= exp(-(spin_drag + viscosity) * delta)
	var substep_travel := radius * SUBSTEP_TRAVEL
	velocity = velocity.limit_length(substep_travel * MAX_SUBSTEPS / delta)
	var substeps := clampi(ceili(velocity.length() * delta / substep_travel), 1, MAX_SUBSTEPS)
	var substep_delta := delta / substeps
	var grounded := false
	for _substep in substeps:
		var previous := position
		position += velocity * substep_delta
		if _query == null:
			continue
		var clear := false
		for _pass in RESOLVE_PASSES:
			var contact := _deepest_contact(position, radius)
			if contact.is_empty():
				clear = true
				break
			var normal := contact["normal"] as Vector2
			position += normal * (float(contact["depth"]) + CONTACT_SLOP)
			if normal.y < FLOOR_NORMAL_Y:
				grounded = true
			var normal_speed := velocity.dot(normal)
			if normal_speed >= 0.0:
				continue
			var stopped := -normal_speed
			if stopped > _impact_speeds[index]:
				_impact_speeds[index] = stopped
				_impact_normals[index] = normal
			var bounce := _restitutions[index] * restitution_scale if stopped > bounce_min_speed else 0.0
			var tangent := Vector2(-normal.y, normal.x)
			var slide := velocity.dot(tangent)
			var grip := minf(absf(slide), friction * (1.0 + bounce) * stopped)
			slide -= signf(slide) * grip
			velocity = tangent * slide + normal * (stopped * bounce)
			spin = lerpf(spin, slide / radius, roll_coupling)
		if not clear and _query.circle_overlaps_solid(position, radius):
			# Enclosed by terrain: stay at the last position rather than tunnel through it.
			position = previous
			velocity = Vector2.ZERO
			spin = 0.0
			_asleep[index] = 1
			break
	_angles[index] += spin * delta
	if grounded and velocity.length() < rest_speed:
		_rest_times[index] += delta
		if _rest_times[index] >= rest_seconds:
			_asleep[index] = 1
			velocity = Vector2.ZERO
			spin = 0.0
	else:
		_rest_times[index] = 0.0
	if not position.is_finite() or position.distance_to(_origin) > maximum_distance:
		position = _positions[index]
		velocity = Vector2.ZERO
		spin = 0.0
		_asleep[index] = 1
	_positions[index] = position
	_velocities[index] = velocity
	_spins[index] = spin
	_grounded[index] = 1 if grounded else 0


func _deepest_contact(position: Vector2, radius: float) -> Dictionary:
	var deepest := {}
	for contact in _query.circle_contacts(position, radius):
		if deepest.is_empty() or float(contact["depth"]) > float(deepest["depth"]):
			deepest = contact
	return deepest


## True when a sleeping gib no longer touches the terrain it rested on or in.
func _lost_support(index: int) -> bool:
	if _query == null:
		return false
	var position := _positions[index]
	if position.distance_to(_origin) > maximum_distance:
		return false
	return not _query.circle_overlaps_solid(position + Vector2(0.0, 2.0), _radii[index])
