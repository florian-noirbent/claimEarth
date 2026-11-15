@tool
## Generated world barrel composed from the shared dynamic body and a reusable explosive.
## It rolls as a circle through committed terrain and sleeps while it rests.
class_name ExplosiveBarrel
extends WorldRigidBody2D


const FOOTPRINT_SEGMENTS := 12
## Points on the body rim sampled for detonating terrain, in addition to the center.
const TERRAIN_SAMPLE_RIM_POINTS := 8
## A rebound slower than this many frames of gravity would end within a pixel; it is dropped.
const REBOUND_GRAVITY_FRAMES := 2.0
## Fraction of the body radius that must still overlap terrain after a step for the barrel to count as enclosed;
## contact resolution can leave hairline overlaps between two terrain corners.
const STUCK_OVERLAP_RADIUS_FRACTION := 0.9

@onready var explosive: WorldExplosive2D = %WorldExplosive

var spawn_data: GeneratedExplosiveBarrelSpawn
var _interactive := false
var _active := false
var _runtime_physics := false
var _motion_solver := TerrainBodyMotionSolver.new()
var _sleep := WorldBodySleep.new()
var _grapple_target: ExplosiveBarrelGrappleTarget
var _grounded := false
var _resting := false
var _rest_check_remaining := 0.0


func _ready() -> void:
	sprite = %Sprite as Sprite2D
	super._ready()
	_sleep.woken.connect(_on_sleep_woken)
	_hide_inherited_visuals()
	_apply_geometry()
	set_physics_process(false)


func configure(
	data: GeneratedExplosiveBarrelSpawn,
	hex_radius_value: float,
	interactive: bool,
	simulation_backend_value: TerrainSimulationBackend = null,
	world_value: WorldGrid = null,
	terrain_registry_value: TerrainRegistry = null,
	compiled_terrain_value: CompiledTerrainData = null
) -> void:
	spawn_data = data
	hex_radius = hex_radius_value
	simulation_backend = simulation_backend_value
	world = world_value
	terrain_registry = terrain_registry_value
	compiled_terrain = compiled_terrain_value
	velocity = Vector2.ZERO
	rotation = 0.0
	_grounded = false
	_resting = false
	_rest_check_remaining = 0.0
	var definition := barrel_definition()
	if definition != null:
		gravity = definition.gravity
		bounce_damping = definition.bounce_damping
		destructive_terrain_tags = definition.detonating_terrain_tags.duplicate()
		_sleep.configure(
			self,
			definition.grounded_check_interval_seconds,
			definition.offscreen_check_interval_seconds,
			definition.stuck_check_interval_seconds,
			definition.screen_margin_radii * hex_radius
		)
	_interactive = interactive
	_runtime_physics = interactive and world != null and terrain_registry != null and definition != null
	if _runtime_physics:
		if compiled_terrain == null:
			compiled_terrain = CompiledTerrainData.compile(terrain_registry)
		_terrain_query.configure(world, compiled_terrain, hex_radius)
		_motion_solver.configure(_terrain_query)
	_apply_geometry()
	if data != null:
		global_position = generated_center_position(data.anchor_offset)
	if explosive != null and definition != null:
		explosive.configure(
			definition.explosion_definition,
			explosive_footprint(),
			self,
			definition.detonates_in_blast_radius
		)
	set_active(interactive)


## Freezes or resumes the barrel and its explosive; a preview barrel never activates.
func set_active(is_active: bool) -> void:
	_active = is_active and _interactive
	set_physics_process(_active and _runtime_physics and not _sleep.is_sleeping())
	if explosive != null:
		explosive.set_active(_active)


func is_active() -> bool:
	return _active


func is_interactive() -> bool:
	return _interactive


func barrel_definition() -> ExplosiveBarrelDefinition:
	return spawn_data.definition if spawn_data != null else null


## Returns the adapter the grapple hook uses to attach to and pull this barrel.
func grapple_target() -> GrappleTarget:
	if _grapple_target == null:
		_grapple_target = ExplosiveBarrelGrappleTarget.new(self)
	return _grapple_target


## Returns the sleep state a WorldBodySleepScheduler tracks for this barrel.
func sleep_state() -> WorldBodySleep:
	return _sleep


## Lets a resting barrel stop its physics steps; the caller must then deliver terrain wake checks.
func set_sleep_enabled(enabled: bool) -> void:
	_sleep.set_enabled(enabled)


func is_sleeping() -> bool:
	return _sleep.is_sleeping()


## Returns whether the barrel came to rest; a resting barrel only rechecks its terrain.
func is_resting() -> bool:
	return _resting


func is_grounded() -> bool:
	return _grounded


## Returns whether the barrel can still move, detonate, or be pushed and pulled.
func is_live() -> bool:
	return explosive != null and not explosive.is_consumed() and not is_queued_for_deletion()


## Resumes per-frame physics after a push, pull, impulse, or terrain change.
func wake() -> void:
	_resting = false
	_rest_check_remaining = 0.0
	if _sleep.is_sleeping():
		_sleep.wake()


func apply_blast_impulse(origin: Vector2, maximum_impulse: float, radius: float) -> void:
	var previous_velocity := velocity
	super.apply_blast_impulse(origin, maximum_impulse, radius)
	if velocity != previous_velocity:
		wake()


## Moves the barrel horizontally out of an overlapping body and hands it part of that
## body's horizontal velocity. Returns false without work when the circles do not overlap.
func push_from(body_position: Vector2, body_radius_value: float, body_velocity: Vector2) -> bool:
	var reach := body_radius_value + body_radius()
	var offset := global_position - body_position
	if offset.length_squared() >= reach * reach or not _active or not is_live():
		return false
	var definition := barrel_definition()
	if definition == null:
		return false
	var direction := signf(offset.x)
	if is_zero_approx(direction):
		direction = signf(body_velocity.x) if not is_zero_approx(body_velocity.x) else 1.0
	wake()
	var separated_x := body_position.x + direction * sqrt(maxf(0.0, reach * reach - offset.y * offset.y))
	_slide_horizontally(separated_x - global_position.x)
	var push_speed := clampf(
		body_velocity.x * definition.push_velocity_ratio,
		-definition.max_push_speed,
		definition.max_push_speed
	)
	if push_speed * direction > velocity.x * direction:
		velocity.x = push_speed
	return true


## Accelerates the barrel toward a point while a rope attached to it is overstretched.
func pull_toward(point: Vector2, overshoot: float, delta: float) -> void:
	var definition := barrel_definition()
	if definition == null or overshoot <= 0.0 or delta <= 0.0 or not _active or not is_live():
		return
	var offset := point - global_position
	if offset.length_squared() <= 0.0001:
		return
	var direction := offset.normalized()
	wake()
	velocity += direction * definition.hook_pull_acceleration * delta
	var toward_speed := velocity.dot(direction)
	if toward_speed > definition.max_hook_pull_speed:
		velocity -= direction * (toward_speed - definition.max_hook_pull_speed)


## Returns the collision circle radius in world units.
func body_radius() -> float:
	var definition := barrel_definition()
	return (definition.body_radius_radii if definition != null else 1.2) * hex_radius


func displayed_size() -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	return sprite.texture.get_size() * sprite.scale.abs()


## Returns where a barrel generated at the anchor rests without overlapping the
## preserved floor: on the anchor's bottom edge when the circle fits inside the hex,
## otherwise raised until it clears the anchor's lower edges and lower neighbors.
func generated_center_position(anchor_offset: Vector2i) -> Vector2:
	var radius := body_radius()
	var inradius := sqrt(3.0) * 0.5 * hex_radius
	var lift := minf(inradius - radius, 2.0 * (inradius - radius))
	lift = minf(lift, -sqrt(maxf(0.0, radius * radius - hex_radius * hex_radius)))
	return HexMetrics.center_for_offset(anchor_offset.x, anchor_offset.y, hex_radius) + Vector2(0.0, lift)


## Returns the local polygon approximating the body circle for explosion overlap tests.
func explosive_footprint() -> PackedVector2Array:
	var radius := body_radius()
	var polygon := PackedVector2Array()
	for index in FOOTPRINT_SEGMENTS:
		polygon.append(Vector2.RIGHT.rotated(TAU * float(index) / float(FOOTPRINT_SEGMENTS)) * radius)
	return polygon


func _physics_process(delta: float) -> void:
	if not _active or not _runtime_physics or delta <= 0.0 or not is_live():
		return
	if _resting:
		# A resting barrel that nobody lets sleep rechecks its terrain on the grounded interval.
		_rest_check_remaining = maxf(0.0, _rest_check_remaining - delta)
		if _rest_check_remaining > 0.0:
			return
	_step(delta)


func _step(delta: float) -> void:
	var definition := barrel_definition()
	if _detonate_on_terrain_contact():
		return
	var start_velocity := velocity
	if _grounded:
		velocity.x *= exp(-definition.ground_friction * delta)
	velocity.y = minf(definition.terminal_fall_speed, velocity.y + definition.gravity * delta)
	var previous_position := global_position
	var result := _motion_solver.move_circle(
		global_position,
		velocity,
		delta,
		body_radius(),
		0.0,
		definition.support_contact_distance,
		false
	) as TerrainBodyMotionResult
	global_position = result.position
	velocity = result.velocity
	_grounded = result.grounded
	if result.collided:
		if result.velocity_change.length() >= definition.impact_detonation_speed:
			explosive.request_immediate_detonation()
			return
		var rebound := result.velocity_change * definition.bounce_damping
		if rebound.length() > definition.gravity * delta * REBOUND_GRAVITY_FRAMES:
			velocity += rebound
	if _grounded and sprite != null:
		sprite.rotation = wrapf(sprite.rotation + (global_position.x - previous_position.x) / body_radius(), -PI, PI)
	if _detonate_on_terrain_contact():
		return
	_update_rest(start_velocity, delta)


## Comes to rest when a slow grounded step barely accelerated the barrel, or when terrain
## encloses it; a sleep-enabled barrel then stops its physics steps.
func _update_rest(start_velocity: Vector2, delta: float) -> void:
	var definition := barrel_definition()
	var stuck := velocity.length() <= definition.rest_speed and _terrain_query.circle_overlaps_solid(
		global_position,
		body_radius() * STUCK_OVERLAP_RADIUS_FRACTION
	)
	var supported := (
		_grounded
		and start_velocity.length() <= definition.rest_speed
		and velocity.length() <= definition.rest_speed
		and (velocity - start_velocity).length()
			<= definition.gravity * sin(deg_to_rad(definition.rest_max_slope_degrees)) * delta
	)
	if not stuck and not supported:
		_resting = false
		return
	velocity = Vector2.ZERO
	_resting = true
	_rest_check_remaining = definition.grounded_check_interval_seconds
	# The watch flags Air but not fluid replacing fluid, so a submerged barrel keeps polling.
	if _sleep.is_enabled() and not _touches_non_air_fluid():
		_sleep.fall_asleep(_terrain_query, _watched_bounds(delta), true, stuck)
		set_physics_process(false)


## Returns the world rectangle containing all terrain a resting physics step of this length reads.
func _watched_bounds(delta: float) -> Rect2:
	var definition := barrel_definition()
	var radius := body_radius()
	var fall_reach := minf(definition.terminal_fall_speed, definition.gravity * delta) * delta
	return Rect2(
		global_position - Vector2(radius, radius),
		Vector2(radius * 2.0, radius * 2.0 + maxf(definition.support_contact_distance, fall_reach))
	)


func _detonate_on_terrain_contact() -> bool:
	for sample in _terrain_sample_positions():
		var kind := _destructive_terrain_kind(_sample_terrain(sample), _sample_quantity(sample))
		if not kind.is_empty():
			explosive.request_immediate_detonation()
			return true
	return false


func _touches_non_air_fluid() -> bool:
	for sample in _terrain_sample_positions():
		var offset := HexMetrics.offset_for_world(sample, hex_radius)
		if not world.dimensions.is_in_bounds_offset(offset.x, offset.y):
			continue
		var cell_id := world.get_committed_by_offset(offset.x, offset.y)
		if cell_id != compiled_terrain.air_id and not _terrain_query.is_solid_cell(offset.x, offset.y):
			return true
	return false


func _terrain_sample_positions() -> PackedVector2Array:
	var radius := body_radius()
	var samples := PackedVector2Array([global_position])
	for index in TERRAIN_SAMPLE_RIM_POINTS:
		var angle := TAU * float(index) / float(TERRAIN_SAMPLE_RIM_POINTS)
		samples.append(global_position + Vector2.RIGHT.rotated(angle) * radius)
	return samples


## Slides the body sideways through the motion solver, so it rides over small bumps and stops at walls.
func _slide_horizontally(distance: float) -> void:
	if is_zero_approx(distance):
		return
	if not _runtime_physics:
		global_position.x += distance
		return
	var result := _motion_solver.move_circle(
		global_position,
		Vector2(distance, 0.0),
		1.0,
		body_radius(),
		0.0,
		0.0,
		false
	) as TerrainBodyMotionResult
	global_position = result.position


func _on_sleep_woken() -> void:
	_resting = false
	_rest_check_remaining = 0.0
	set_physics_process(_active and _runtime_physics)


func _apply_geometry() -> void:
	if not is_node_ready() or sprite == null or sprite.texture == null:
		return
	var definition := barrel_definition()
	var target_width := (definition.sprite_width_radii if definition != null else 2.4) * hex_radius
	sprite.scale = Vector2.ONE * (target_width / maxf(1.0, sprite.texture.get_width()))
	sprite.position = Vector2.ZERO
	_pending_polygon = explosive_footprint()
	_ensure_visuals()
	_hide_inherited_visuals()


## The shared body draws a debug polygon and outline; the barrel shows only its sprite.
func _hide_inherited_visuals() -> void:
	if body != null:
		body.visible = false
	if outline != null:
		outline.visible = false
