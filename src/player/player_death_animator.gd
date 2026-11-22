## Plays the death sequence of the player's body: holds the anticipation on the whole rig,
## frees its parts into a GibSimulation, drives every part's death shader, lets the rope
## go, and asks for world effects by key. It steps itself once per physics step from the
## moment the death begins, because the dead player's own physics no longer runs, and it
## decides nothing about gameplay. Equal deaths play out identically.
class_name PlayerDeathAnimator
extends Node


## The sequence reached a moment that asks for the world effect declared under key.
signal cue_requested(key: StringName, world_position: Vector2, direction: Vector2, strength: float)
## A loose part hit terrain at world_position; key is the sequence's splat effect, which
## may be empty. normal points away from the surface, impact_speed is in px/s.
signal gib_landed(key: StringName, world_position: Vector2, normal: Vector2, impact_speed: float)

## Seconds a freed part takes to reach its loose size.
const POP_SECONDS := 0.08
## Widest a squashed body may spread sideways, as a multiple of its width.
const SQUASH_MAX_SPREAD := 1.7
## How fast the shader patterns drift, in pattern cells per second.
const PHASE_SPEED := 0.7

## Channels of the sampled look curves.
enum Look { DISSOLVE, MELT, SWELL, TINT, FLASH, SCORCH, EMBER, GLOW, COUNT }

@export var library: DeathSequenceLibrary
## Shaders of a part's painted sprite and of the silhouette behind it during a death.
@export var gib_shader: Shader
@export var gib_outline_shader: Shader
## Rig part whose sprite the released rope falls back to.
@export var rope_hand_part: StringName = &"Hand"
## Distance from the body's center to the surface a squash presses it against.
@export var squash_anchor_distance := 16.0
## Smallest and largest collision radius of a loose part before gib_scale, in world px.
@export var gib_radius_min := 2.5
@export var gib_radius_max := 9.0
## Collision radius of a body that stays whole, in world px.
@export var whole_body_radius := 14.0
## How far a whole body that lies flat sinks to rest on the ground, in world px.
@export var whole_body_lying_drop := 7.0

var _rig: PlayerRig
var _body_visual: Node2D
var _grapple: GrappleRopeVisual
var _sequence: DeathSequence
var _context: DeathContext
var _simulation := GibSimulation.new()
var _query: TerrainCollisionQuery
var _rng := RandomNumberGenerator.new()
var _seed_override := -1
var _playing := false
var _suspended := false
var _duration := 0.0
var _elapsed := 0.0
var _body_position := Vector2.ZERO
var _push := Vector2.ZERO
var _base_body_transform := Transform2D.IDENTITY
var _outline_color := Color.BLACK
## The squash currently applied to the whole body, without its offset.
var _squash := Transform2D.IDENTITY
## The lean currently applied to the whole body, in radians.
var _lean := 0.0
var _attached_count := 0
## Gib that carries a body that stays whole, once it is loose; -1 before and otherwise.
var _whole_gib := -1
## Turn of a whole body by its lean, with -1 or 1 for the side it faces.
var _lean_side := 1.0
var _whole_splat_wait := 0.0
var _hand_part := -1
var _materials: Array[ShaderMaterial] = []
var _outline_materials: Array[ShaderMaterial] = []
var _detach_times := PackedFloat32Array()
var _look_delays := PackedFloat32Array()
var _gib_indices := PackedInt32Array()
var _free_seconds := PackedFloat32Array()
var _part_bases: Array[Transform2D] = []
var _part_centers := PackedVector2Array()
var _part_radii := PackedFloat32Array()
var _part_featured := PackedByteArray()
var _part_gone := PackedByteArray()
var _part_solid := PackedByteArray()
## Set once a part lies still at its final size: its sprites no longer need placing.
var _part_placed := PackedByteArray()
var _part_ups := PackedVector2Array()
## The shader values last sent for each part, so unchanged parts send nothing.
var _part_signatures: Array[PackedFloat32Array] = []
var _look := PackedFloat32Array()
var _look_time := -1.0
var _trail_waits := PackedFloat32Array()
var _splat_waits := PackedFloat32Array()
var _cue_plays := PackedInt32Array()


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	advance(delta)


## Makes every random choice of the next death repeatable regardless of where it happens.
func set_seed(seed_value: int) -> void:
	_seed_override = seed_value


func is_playing() -> bool:
	return _playing


## True once a death began here, whether it still moves or has settled.
func has_begun() -> bool:
	return _sequence != null


func sequence() -> DeathSequence:
	return _sequence


func simulation() -> GibSimulation:
	return _simulation


## Share of the beat that has passed, from 0 to 1.
func progress() -> float:
	if _duration <= 0.0:
		return 1.0
	return clampf(_elapsed / _duration, 0.0, 1.0)


func detached_part_count() -> int:
	var count := 0
	for gib in _gib_indices:
		if gib >= 0:
			count += 1
	return count


## True once a body that stays whole has gone loose.
func is_whole_body_loose() -> bool:
	return _whole_gib >= 0


## Where the body's center is now: a whole body that went loose moves, any other stays
## where it died.
func body_position() -> Vector2:
	return _simulation.position_of(_whole_gib) if _whole_gib >= 0 else _body_position


## Holds the sequence on its current frame, like the rest of a suspended world.
func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	set_physics_process(_playing and not _suspended)


## Starts the sequence for cause on the given rig. duration_seconds is the death beat the
## sequence is fitted into; zero plays everything at once. query is the terrain the loose
## parts collide with.
func begin(
	rig: PlayerRig,
	body_visual: Node2D,
	grapple: GrappleRopeVisual,
	cause: StringName,
	duration_seconds: float,
	context: DeathContext,
	query: TerrainCollisionQuery
) -> void:
	if has_begun() or library == null or rig == null:
		return
	_context = context if context != null else DeathContext.new()
	_sequence = library.sequence_for(cause, _context.terrain_tags)
	if _sequence == null:
		return
	_rig = rig
	_body_visual = body_visual
	_grapple = grapple
	_duration = maxf(duration_seconds, 0.0)
	_elapsed = 0.0
	_body_position = body_visual.global_position
	_base_body_transform = body_visual.transform
	_push = _context.push_direction(_body_position)
	_lean_side = -1.0 if rig.scale.x < 0.0 else 1.0
	_rng.seed = _seed_override if _seed_override >= 0 else hash([cause, Vector2i(_body_position.round())])
	_configure_simulation(query)
	_prepare_parts()
	if _rig.outline_material != null:
		_outline_color = _rig.outline_material.get_shader_parameter(&"outline_color")
	_cue_plays.resize(_sequence.cues.size())
	_cue_plays.fill(0)
	_rig.set_raised_above_terrain(true)
	if _sequence.pose != &"":
		_rig.play_state(_sequence.pose)
	if _grapple != null:
		_grapple.let_go(library.rope_release_seconds)
	_playing = true
	set_physics_process(not _suspended)
	# The first frame shows at once: a hit flash, or the whole burst of an instant sequence.
	advance(0.0)


## Advances the sequence by hand; the node calls this itself every physics step.
func advance(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var time := progress()
	_advance_rope(delta)
	if _sequence.keep_whole and _whole_gib < 0 and time >= _sequence.burst_at:
		_let_whole_body_go()
	if _attached_count > 0:
		_advance_whole_body(time, delta)
	if not _sequence.keep_whole:
		for part in _gib_indices.size():
			if _gib_indices[part] < 0 and time >= _detach_times[part]:
				_detach(part)
	var settle := smoothstep(library.settle_from, 1.0, time)
	_simulation.restitution_scale = 1.0 - settle
	_simulation.settle_drag = library.settle_drag * settle
	_simulation.step(delta)
	_look_time = -1.0
	for part in _gib_indices.size():
		_update_part(part, time, delta)
	_play_cues(time)
	_report_gibs(time, delta)
	if time >= 1.0 and (_attached_count == 0 or _sequence.keep_whole) and _is_rope_stowed():
		if _simulation.all_asleep() or _elapsed >= _duration + library.settle_grace_seconds:
			_playing = false
			set_physics_process(false)


func _configure_simulation(query: TerrainCollisionQuery) -> void:
	_query = query if query != null and query.is_configured() else null
	_simulation = GibSimulation.new()
	_simulation.configure(_query, _body_position)
	_simulation.gravity = _sequence.gravity
	_simulation.air_drag = _sequence.air_drag
	_simulation.spin_drag = _sequence.spin_drag
	_simulation.friction = _sequence.friction
	_simulation.liquid_drag_scale = _sequence.liquid_drag_scale
	_simulation.buoyancy = _sequence.buoyancy


## Gives every part its own death materials and its place in the detach order.
func _prepare_parts() -> void:
	var count := _rig.part_count()
	_attached_count = count
	_look.resize(Look.COUNT)
	_hand_part = -1
	var heights: Array[Vector2] = []
	for part in count:
		var sprite := _rig.part_sprite(part)
		var size := sprite.texture.get_size() if sprite.texture != null else Vector2.ZERO
		var center := sprite.offset + (Vector2.ZERO if sprite.centered else size * 0.5)
		_part_centers.append(center)
		var featured := _sequence.is_featured(_rig.part_name(part))
		_part_featured.append(1 if featured else 0)
		_part_gone.append(0)
		_part_solid.append(1 if featured and _sequence.featured_stay_solid else 0)
		_part_placed.append(0)
		var up := sprite.global_transform.affine_inverse().basis_xform(Vector2.UP)
		_part_ups.append(up.normalized() if up.length_squared() > 0.0 else Vector2.UP)
		_part_signatures.append(PackedFloat32Array())
		_gib_indices.append(-1)
		_free_seconds.append(0.0)
		_part_bases.append(Transform2D.IDENTITY)
		_part_radii.append(gib_radius_min)
		_trail_waits.append(_sequence.trail_interval_seconds * float(part) / float(maxi(count, 1)))
		_splat_waits.append(0.0)
		# Both materials of a part share one seed, so the silhouette dissolves with it.
		var part_seed := _rng.randf() * 40.0
		_materials.append(_create_material(gib_shader, center, part_seed))
		_outline_materials.append(_create_material(gib_outline_shader, center, part_seed))
		sprite.material = _materials[part]
		_rig.part_outline(part).material = _outline_materials[part]
		if _rig.part_name(part) == rope_hand_part:
			_hand_part = part
		heights.append(Vector2((sprite.global_transform * center).y, float(part)))
		_detach_times.append(0.0)
		_look_delays.append(0.0)
	# Random order keeps the draw order; the other two sort by height on screen.
	if _sequence.detach_order == DeathSequence.DetachOrder.RANDOM:
		for index in range(count - 1, 0, -1):
			var other := _rng.randi_range(0, index)
			var swapped := heights[index]
			heights[index] = heights[other]
			heights[other] = swapped
	else:
		heights.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.x < b.x if a.x != b.x else a.y < b.y
		)
		if _sequence.detach_order == DeathSequence.DetachOrder.BOTTOM_UP:
			heights.reverse()
	for rank in count:
		var part := int(heights[rank].y)
		var share := float(rank) / float(maxi(count - 1, 1))
		_detach_times[part] = _sequence.burst_at + _sequence.detach_stagger * share
		_look_delays[part] = _sequence.look_stagger * share


func _create_material(shader: Shader, center: Vector2, part_seed: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"stretch_pivot", center)
	material.set_shader_parameter(&"seed", part_seed)
	material.set_shader_parameter(&"dissolve_edge_width", _sequence.dissolve_edge_width)
	material.set_shader_parameter(&"dissolve_top_down", _sequence.dissolve_top_down)
	if shader == gib_shader:
		material.set_shader_parameter(&"flash_color", _sequence.flash_color)
		material.set_shader_parameter(&"tint_color", _sequence.tint_color)
		material.set_shader_parameter(&"scorch_color", _sequence.scorch_color)
		material.set_shader_parameter(&"ember_color", _sequence.ember_color)
		material.set_shader_parameter(&"dissolve_edge_color", _sequence.dissolve_edge_color)
	elif _rig.outline_material != null:
		for parameter: StringName in [&"outline_color", &"width"]:
			material.set_shader_parameter(parameter, _rig.outline_material.get_shader_parameter(parameter))
	return material


## Steps the rig while parts still hang on it, and squashes and shakes the whole body.
func _advance_whole_body(time: float, delta: float) -> void:
	var loose := _whole_gib >= 0
	var lean := deg_to_rad(DeathSequence.sample(_sequence.lean, time, 0.0)) * _lean_side
	if delta > 0.0:
		_rig.advance(delta)
		var velocity := _simulation.velocity_of(_whole_gib) if loose else Vector2.ZERO
		var lying := loose and _simulation.is_grounded(_whole_gib)
		_rig.update_ragdoll(_sequence.limp and (loose or not _sequence.keep_whole), lying, velocity, (lean - _lean) / delta, delta)
		_rig.update_aim(false, Vector2.ZERO, delta)
	_lean = lean
	var length := maxf(DeathSequence.sample(_sequence.squash, time, 1.0), 0.05)
	var spread := minf(1.0 / sqrt(length), SQUASH_MAX_SPREAD)
	var axis := _push if _push != Vector2.ZERO else Vector2.UP
	var side := axis.orthogonal()
	var x_axis := axis * axis.x * length + side * side.x * spread
	var y_axis := axis * axis.y * length + side * side.y * spread
	# The body flattens onto the surface behind it instead of shrinking toward its center.
	var anchor := -axis * squash_anchor_distance
	var origin := anchor - (x_axis * anchor.x + y_axis * anchor.y)
	var shake := DeathSequence.sample(_sequence.shake, time, 0.0)
	if shake > 0.0 and delta > 0.0:
		origin += Vector2(_rng.randf_range(-shake, shake), _rng.randf_range(-shake, shake))
	_squash = Transform2D(x_axis, y_axis, Vector2.ZERO)
	if loose:
		# The body's parent no longer moves, so the offset is in its frame.
		origin += _simulation.position_of(_whole_gib) - _body_position
		origin.y += whole_body_lying_drop * absf(sin(lean))
	_body_visual.transform = Transform2D(x_axis, y_axis, origin) * Transform2D(lean, Vector2.ZERO) * _base_body_transform


## Turns a body that stays whole into one loose body.
func _let_whole_body_go() -> void:
	_whole_gib = _simulation.add_gib(
		_body_position,
		_context.velocity * _sequence.inherit_velocity,
		0.0,
		0.0,
		whole_body_radius,
		_sequence.restitution
	)
	if _sequence.loose_pose != &"":
		_rig.play_state(_sequence.loose_pose)


## Frees one part from the rig and throws it.
func _detach(part: int) -> void:
	var sprite := _rig.part_sprite(part)
	var placed := sprite.global_transform
	_rig.release_part(part)
	_attached_count -= 1
	var center := placed * _part_centers[part]
	# A part leaves the squashed body at its own shape again.
	_part_bases[part] = _squash.affine_inverse() * Transform2D(placed.x, placed.y, Vector2.ZERO)
	var content := Vector2.ZERO
	if sprite.texture != null:
		content = (sprite.texture.get_size() - Vector2.ONE * _rig.part_texture_margin * 2.0).maxf(1.0)
	var extent := minf(content.x * _part_bases[part].x.length(), content.y * _part_bases[part].y.length()) * 0.5
	_part_radii[part] = clampf(extent, gib_radius_min, gib_radius_max)

	var featured := _part_featured[part] != 0
	var inherited := _context.velocity * _sequence.inherit_velocity
	var normal := _context.surface_normal
	if normal.length_squared() > 0.0001:
		normal = normal.normalized()
		var into := inherited.dot(normal)
		if into < 0.0:
			inherited -= normal * into * (1.0 + _sequence.surface_bounce)
	var outward := center - _body_position
	outward = outward.normalized() if outward.length_squared() > 1.0 else Vector2.from_angle(_rng.randf() * TAU)
	var thrown := outward * _rng.randf_range(_sequence.radial_speed_min, _sequence.radial_speed_max)
	if _push != Vector2.ZERO:
		var spread := deg_to_rad(_sequence.push_spread_degrees)
		thrown += _push.rotated(_rng.randf_range(-spread, spread)) \
			* _rng.randf_range(_sequence.push_speed_min, _sequence.push_speed_max)
		thrown += _push.orthogonal() \
			* _rng.randf_range(-_sequence.surface_scatter_speed, _sequence.surface_scatter_speed)
	thrown += Vector2.UP * _rng.randf_range(_sequence.lift_speed_min, _sequence.lift_speed_max)
	var spin := deg_to_rad(_rng.randf_range(_sequence.spin_degrees_min, _sequence.spin_degrees_max))
	if _rng.randf() < 0.5:
		spin = -spin
	if featured:
		thrown *= _sequence.featured_speed_scale
	_gib_indices[part] = _simulation.add_gib(
		_clear_start(center, _part_radii[part]),
		inherited + thrown,
		0.0,
		spin,
		_part_radii[part],
		_sequence.featured_restitution if featured else _sequence.restitution
	)


## Where a part starts its flight: its own center, or the nearest point toward the body's
## center that is clear when a limb reached into terrain. A buried body has no clear
## point and its parts stay where they are.
func _clear_start(center: Vector2, radius: float) -> Vector2:
	if _query == null or not _query.circle_overlaps_solid(center, radius):
		return center
	for step in range(1, 5):
		var candidate := center.lerp(_body_position, step / 4.0)
		if not _query.circle_overlaps_solid(candidate, radius):
			return candidate
	return center


## Places a loose part's sprites on its gib and feeds the part's death shader. A part that
## lies still with an unchanged look costs nothing.
func _update_part(part: int, time: float, delta: float) -> void:
	if _part_gone[part] != 0:
		return
	var sprite := _rig.part_sprite(part)
	var outline := _rig.part_outline(part)
	var gib := _gib_indices[part]
	if gib >= 0 and _part_placed[part] == 0:
		_free_seconds[part] += delta
		var pop := clampf(_free_seconds[part] / POP_SECONDS, 0.0, 1.0)
		var size := lerpf(1.0, _sequence.gib_scale, pop)
		_simulation.set_radius(gib, _part_radii[part] * size)
		var turned := Transform2D(_simulation.angle_of(gib), Vector2.ZERO) * _part_bases[part]
		var x_axis := turned.x * size
		var y_axis := turned.y * size
		var center := _part_centers[part]
		var placed := Transform2D(x_axis, y_axis, _simulation.position_of(gib) - (x_axis * center.x + y_axis * center.y))
		sprite.global_transform = placed
		outline.global_transform = placed
		# The part's up direction in its own texture, for drips and top-down dissolving.
		var up := placed.affine_inverse().basis_xform(Vector2.UP)
		_part_ups[part] = up.normalized() if up.length_squared() > 0.0 else Vector2.UP
	if gib >= 0:
		_part_placed[part] = 1 if _simulation.is_asleep(gib) and _free_seconds[part] >= POP_SECONDS else 0

	var look := _look_at(clampf(time - _look_delays[part], 0.0, 1.0))
	var stays_solid := _part_solid[part] != 0
	var dissolve := 0.0 if stays_solid else look[Look.DISSOLVE]
	if dissolve >= 1.0:
		_part_gone[part] = 1
		sprite.visible = false
		outline.visible = false
		return
	var melt := 0.0 if stays_solid else look[Look.MELT]
	var swell := look[Look.SWELL]
	if _sequence.swell_wobble > 0.0 and swell > 1.0:
		swell += (swell - 1.0) * _sequence.swell_wobble * sin(TAU * _sequence.swell_wobble_hz * _elapsed + float(part))
	var tint := look[Look.TINT] * (_sequence.featured_tint_scale if _part_featured[part] != 0 else 1.0)
	# The patterns only drift while something that shows them is on screen.
	var drifting := dissolve > 0.0 or look[Look.EMBER] > 0.0
	var phase := _elapsed * PHASE_SPEED if drifting else 0.0
	var up := _part_ups[part]
	var signature := PackedFloat32Array([
		dissolve, melt, swell, tint, look[Look.FLASH], look[Look.SCORCH], look[Look.EMBER], look[Look.GLOW],
		up.x, up.y, phase,
	])
	if signature == _part_signatures[part]:
		return
	_part_signatures[part] = signature
	var material := _materials[part]
	var outline_material := _outline_materials[part]
	var stretch := Vector2(swell, swell)
	for shared: ShaderMaterial in [material, outline_material]:
		shared.set_shader_parameter(&"stretch", stretch)
		shared.set_shader_parameter(&"dissolve", dissolve)
		shared.set_shader_parameter(&"melt", melt)
		shared.set_shader_parameter(&"up_uv", up)
		shared.set_shader_parameter(&"phase", phase)
	outline_material.set_shader_parameter(&"outline_color", _outline_color.lerp(_sequence.outline_glow_color, look[Look.GLOW]))
	material.set_shader_parameter(&"flash", look[Look.FLASH])
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"scorch", look[Look.SCORCH])
	material.set_shader_parameter(&"ember", look[Look.EMBER])


## The look curves sampled at a share of the beat, indexed by Look. Parts that share a
## look time share one sampling per step.
func _look_at(look_time: float) -> PackedFloat32Array:
	if look_time == _look_time:
		return _look
	_look_time = look_time
	_look[Look.DISSOLVE] = DeathSequence.sample(_sequence.dissolve, look_time, 0.0)
	_look[Look.MELT] = DeathSequence.sample(_sequence.melt, look_time, 0.0)
	_look[Look.SWELL] = DeathSequence.sample(_sequence.swell, look_time, 1.0)
	_look[Look.TINT] = DeathSequence.sample(_sequence.tint, look_time, 0.0)
	_look[Look.FLASH] = DeathSequence.sample(_sequence.flash, look_time, 0.0)
	_look[Look.SCORCH] = DeathSequence.sample(_sequence.scorch, look_time, 0.0)
	_look[Look.EMBER] = DeathSequence.sample(_sequence.ember, look_time, 0.0)
	_look[Look.GLOW] = DeathSequence.sample(_sequence.outline_glow, look_time, 0.0)
	return _look


func _play_cues(time: float) -> void:
	for index in _sequence.cues.size():
		var cue := _sequence.cues[index]
		if cue == null:
			continue
		# Without a beat there is nothing to spread repeats over.
		var plays := cue.plays if _duration > 0.0 else 1
		while _cue_plays[index] < plays and time >= cue.at + cue.interval * _cue_plays[index]:
			_cue_plays[index] += 1
			_play_cue(cue)


func _play_cue(cue: DeathCue) -> void:
	if cue.anchor == DeathCue.Anchor.BODY:
		var direction := Vector2.UP
		if cue.aim == DeathCue.Aim.PUSH and _push != Vector2.ZERO:
			direction = _push
		elif cue.aim == DeathCue.Aim.OUTWARD and cue.offset != Vector2.ZERO:
			direction = cue.offset.normalized()
		elif cue.aim == DeathCue.Aim.MOTION and _context.velocity != Vector2.ZERO:
			direction = _context.velocity.normalized()
		cue_requested.emit(cue.effect_key, body_position() + cue.offset, direction, cue.strength)
		return
	var parts := PackedInt32Array()
	for part in _part_gone.size():
		if _part_gone[part] != 0:
			continue
		if cue.anchor == DeathCue.Anchor.FEATURED_PARTS and _part_featured[part] == 0:
			continue
		parts.append(part)
	if parts.is_empty():
		return
	if cue.anchor == DeathCue.Anchor.RANDOM_PART:
		parts = PackedInt32Array([parts[_rng.randi_range(0, parts.size() - 1)]])
	for part in parts:
		var position := _part_position(part)
		var direction := Vector2.UP
		if cue.aim == DeathCue.Aim.PUSH and _push != Vector2.ZERO:
			direction = _push
		elif cue.aim == DeathCue.Aim.OUTWARD and position.distance_squared_to(_body_position) > 1.0:
			direction = (position - _body_position).normalized()
		elif cue.aim == DeathCue.Aim.MOTION and _gib_indices[part] >= 0:
			var velocity := _simulation.velocity_of(_gib_indices[part])
			if velocity.length_squared() > 1.0:
				direction = velocity.normalized()
		cue_requested.emit(cue.effect_key, position, direction, cue.strength)


## Reports the trails of flying parts and the hits of parts that struck terrain.
func _report_gibs(time: float, delta: float) -> void:
	if _whole_gib >= 0:
		_whole_splat_wait -= delta
		var body_impact := _simulation.impact_speed_of(_whole_gib)
		if body_impact >= _sequence.splat_min_speed and _whole_splat_wait <= 0.0:
			_whole_splat_wait = _sequence.splat_cooldown_seconds
			var body_normal := _simulation.impact_normal_of(_whole_gib)
			var touched := _simulation.position_of(_whole_gib) - body_normal * _simulation.radius_of(_whole_gib)
			gib_landed.emit(_sequence.splat_effect_key, touched, body_normal, body_impact)
	var trailing := _sequence.trail_effect_key != &"" and time <= _sequence.trail_until
	for part in _gib_indices.size():
		var gib := _gib_indices[part]
		if gib < 0 or _part_gone[part] != 0:
			continue
		_trail_waits[part] -= delta
		_splat_waits[part] -= delta
		var velocity := _simulation.velocity_of(gib)
		if trailing and _trail_waits[part] <= 0.0 and velocity.length() >= _sequence.trail_min_speed:
			_trail_waits[part] = _sequence.trail_interval_seconds
			cue_requested.emit(_sequence.trail_effect_key, _simulation.position_of(gib), velocity.normalized(), 1.0)
		var impact_speed := _simulation.impact_speed_of(gib)
		if impact_speed >= _sequence.splat_min_speed and _splat_waits[part] <= 0.0:
			_splat_waits[part] = _sequence.splat_cooldown_seconds
			var normal := _simulation.impact_normal_of(gib)
			var contact := _simulation.position_of(gib) - normal * _simulation.radius_of(gib)
			gib_landed.emit(_sequence.splat_effect_key, contact, normal, impact_speed)


## World position of a part's center, on the rig or loose.
func _part_position(part: int) -> Vector2:
	if _gib_indices[part] >= 0:
		return _simulation.position_of(_gib_indices[part])
	return _rig.part_sprite(part).global_transform * _part_centers[part]


func _advance_rope(delta: float) -> void:
	if _is_rope_stowed():
		return
	_grapple.advance(false, Vector2.ZERO, delta)
	var grip := _body_position
	if _hand_part >= 0:
		grip = _part_position(_hand_part)
	_grapple.pose(grip, delta)


func _is_rope_stowed() -> bool:
	return _grapple == null or not _grapple.is_out()
