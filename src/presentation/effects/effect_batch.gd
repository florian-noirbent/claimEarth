## Simulates and draws every live particle of one blend layer in a single canvas item.
## Particles live in a fixed ring of packed slots: spawning never allocates a node, and when
## the ring is full the oldest particle is replaced.
class_name EffectBatch
extends Node2D


const STAR_POINT_COUNT := 5
const STAR_INNER_RATIO := 0.45
## Smaller stars cannot be triangulated reliably.
const MIN_STAR_RADIUS := 0.5
const MIN_RING_SEGMENTS := 24
const MAX_RING_SEGMENTS := 64

var _capacity := 0
var _head := 0
var _tail := 0
var _used := 0
var _anchor_position := Vector2.ZERO
var _glow_texture: Texture2D
var _disc_texture: Texture2D
var _rng := RandomNumberGenerator.new()

var _emitters: Array[EffectEmitter] = []
var _position := PackedVector2Array()
var _velocity := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _scale := PackedFloat32Array()
var _size_factor := PackedFloat32Array()
var _rotation := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _tint := PackedColorArray()


func _init(capacity: int = 512, additive: bool = false) -> void:
	_capacity = maxi(capacity, 1)
	_emitters.resize(_capacity)
	_position.resize(_capacity)
	_velocity.resize(_capacity)
	_age.resize(_capacity)
	_life.resize(_capacity)
	_scale.resize(_capacity)
	_size_factor.resize(_capacity)
	_rotation.resize(_capacity)
	_spin.resize(_capacity)
	_tint.resize(_capacity)
	if additive:
		var additive_material := CanvasItemMaterial.new()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive_material
	set_process(false)


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Textures of the soft glow and of the hard-edged disc; both are drawn as tinted quads.
func set_textures(glow_texture: Texture2D, disc_texture: Texture2D) -> void:
	_glow_texture = glow_texture
	_disc_texture = disc_texture


## Where anchored particles are drawn relative to.
func set_anchor_position(anchor_position: Vector2) -> void:
	_anchor_position = anchor_position


func capacity() -> int:
	return _capacity


## Slots between the oldest live particle and the newest one.
func used_count() -> int:
	return _used


## Spawns up to count particles of one emitter and returns how many it spawned.
func emit(
	emitter: EffectEmitter,
	count: int,
	origin: Vector2,
	effect_scale: float,
	tint: Color,
	direction_angle: float,
	intensity: float,
	duration: float
) -> int:
	var time_scale := duration if emitter.time_scales_with_duration else 1.0
	var speed_scale := effect_scale * (intensity if emitter.speed_scales_with_intensity else 1.0)
	var base_angle := deg_to_rad(emitter.direction_degrees)
	var offset := emitter.spawn_offset * effect_scale
	if emitter.relative_to_direction:
		base_angle += direction_angle
		offset = offset.rotated(direction_angle)
	var half_spread := deg_to_rad(emitter.spread_degrees) * 0.5
	var palette_size := emitter.tint_palette.size()
	var spawn_origin := origin - _anchor_position if emitter.anchored else origin
	for index in count:
		var slot := _claim_slot()
		var angle := base_angle + _rng.randf_range(-half_spread, half_spread)
		var heading := Vector2.from_angle(angle)
		var spawn_position := spawn_origin + offset
		if emitter.spawn_radius > 0.0:
			spawn_position += Vector2.from_angle(_rng.randf() * TAU) * (sqrt(_rng.randf()) * emitter.spawn_radius * effect_scale)
		_emitters[slot] = emitter
		_position[slot] = spawn_position
		_velocity[slot] = heading * (_rng.randf_range(emitter.speed_min, emitter.speed_max) * speed_scale)
		_age[slot] = -(_rng.randf_range(emitter.delay_min, emitter.delay_max) + emitter.delay_step * index) * time_scale
		_life[slot] = maxf(_rng.randf_range(emitter.lifetime_min, emitter.lifetime_max) * time_scale, 0.01)
		_scale[slot] = effect_scale
		_size_factor[slot] = 1.0 - _rng.randf() * emitter.size_jitter
		_rotation[slot] = _initial_rotation(emitter, angle, index, count)
		_spin[slot] = deg_to_rad(_rng.randf_range(emitter.spin_degrees_min, emitter.spin_degrees_max))
		_tint[slot] = emitter.tint_palette[_rng.randi() % palette_size] if palette_size > 0 else tint
	if count > 0:
		set_process(true)
		queue_redraw()
	return count


## Removes every particle at once.
func clear() -> void:
	for slot in _capacity:
		_emitters[slot] = null
	_head = 0
	_tail = 0
	_used = 0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## Moves and ages every particle; frees the slots of the ones that ended.
func advance(delta: float) -> void:
	var slot := _tail
	for _index in _used:
		var emitter := _emitters[slot]
		if emitter != null:
			var age := _age[slot] + delta
			_age[slot] = age
			if age >= _life[slot]:
				_emitters[slot] = null
			elif age > 0.0 and emitter.motion == EffectEmitter.Motion.BALLISTIC:
				var velocity := _velocity[slot]
				velocity.y += emitter.gravity * delta
				if emitter.drag > 0.0:
					velocity *= exp(-emitter.drag * delta)
				_velocity[slot] = velocity
				_position[slot] += velocity * delta
				_rotation[slot] += _spin[slot] * delta
			elif age > 0.0:
				_rotation[slot] += _spin[slot] * delta
		slot = (slot + 1) % _capacity
	while _used > 0 and _emitters[_tail] == null:
		_tail = (_tail + 1) % _capacity
		_used -= 1
	if _used == 0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var slot := _tail
	for _index in _used:
		var emitter := _emitters[slot]
		if emitter != null and _age[slot] > 0.0:
			_draw_particle(slot, emitter)
		slot = (slot + 1) % _capacity


func _draw_particle(slot: int, emitter: EffectEmitter) -> void:
	var progress := clampf(_age[slot] / _life[slot], 0.0, 1.0)
	var color := emitter.colors.sample(progress)
	if color.a <= 0.004:
		return
	var tint_amount := 1.0 if not emitter.tint_palette.is_empty() else emitter.tint_amount
	if tint_amount > 0.0:
		var tint := _tint[slot]
		color.r *= lerpf(1.0, tint.r, tint_amount)
		color.g *= lerpf(1.0, tint.g, tint_amount)
		color.b *= lerpf(1.0, tint.b, tint_amount)
	var effect_scale := _scale[slot]
	var eased := ease(progress, emitter.size_ease)
	var size := lerpf(emitter.size_start, emitter.size_end, eased) * effect_scale * _size_factor[slot]
	var center := _position[slot]
	if emitter.anchored:
		center += _anchor_position
	if emitter.motion == EffectEmitter.Motion.ORBIT:
		var orbit_angle := _rotation[slot] + deg_to_rad(emitter.orbit_degrees_per_second) * _age[slot]
		var orbit_radius := emitter.orbit_radius * effect_scale
		center += Vector2(cos(orbit_angle) * orbit_radius, sin(orbit_angle) * orbit_radius * emitter.orbit_flatten)
	if size <= 0.0:
		return
	match emitter.shape:
		EffectEmitter.Shape.DISC:
			if _disc_texture != null:
				draw_texture_rect(_disc_texture, Rect2(center - Vector2(size, size), Vector2(size, size) * 2.0), false, color)
			else:
				draw_circle(center, size, color)
		EffectEmitter.Shape.GLOW:
			if _glow_texture != null:
				draw_texture_rect(_glow_texture, Rect2(center - Vector2(size, size), Vector2(size, size) * 2.0), false, color)
		EffectEmitter.Shape.RING:
			var width := maxf(lerpf(emitter.thickness_start, emitter.thickness_end, eased) * effect_scale, 1.0)
			var half_arc := deg_to_rad(emitter.arc_degrees) * 0.5
			var segments := clampi(int(size * 0.5), MIN_RING_SEGMENTS, MAX_RING_SEGMENTS)
			var middle := _rotation[slot] if emitter.arc_degrees < 360.0 else 0.0
			draw_arc(center, size, middle - half_arc, middle + half_arc, segments, color, width)
		EffectEmitter.Shape.STREAK:
			var velocity := _velocity[slot]
			var speed := velocity.length()
			var length := maxf(size, speed * emitter.streak_seconds)
			var along := velocity / speed if speed > 0.001 else Vector2.from_angle(_rotation[slot])
			var streak_width := maxf(lerpf(emitter.thickness_start, emitter.thickness_end, eased) * effect_scale, 1.0)
			draw_line(center - along * length, center, color, streak_width)
		EffectEmitter.Shape.CHUNK:
			var axis_x := Vector2.from_angle(_rotation[slot]) * size * emitter.aspect
			var axis_y := Vector2.from_angle(_rotation[slot] + PI * 0.5) * size
			draw_primitive(PackedVector2Array([
				center - axis_x - axis_y, center + axis_x - axis_y, center + axis_x + axis_y, center - axis_x + axis_y,
			]), PackedColorArray([color]), PackedVector2Array())
		EffectEmitter.Shape.SHARD:
			var rotation_angle := _rotation[slot]
			draw_primitive(PackedVector2Array([
				center + Vector2.from_angle(rotation_angle) * size * 1.4,
				center + Vector2.from_angle(rotation_angle + 2.4) * size * 0.8,
				center + Vector2.from_angle(rotation_angle - 2.4) * size * 0.8,
			]), PackedColorArray([color]), PackedVector2Array())
		EffectEmitter.Shape.STAR:
			if size >= MIN_STAR_RADIUS:
				draw_colored_polygon(_star_points(center, size, _rotation[slot]), color)


func _claim_slot() -> int:
	if _used == _capacity:
		_tail = (_tail + 1) % _capacity
		_used -= 1
	var slot := _head
	_head = (_head + 1) % _capacity
	_used += 1
	return slot


func _initial_rotation(emitter: EffectEmitter, heading_angle: float, index: int, count: int) -> float:
	if emitter.motion == EffectEmitter.Motion.ORBIT:
		return TAU * index / maxf(count, 1.0)
	if emitter.random_rotation:
		return _rng.randf() * TAU
	return heading_angle


func _star_points(center: Vector2, radius: float, rotation_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(STAR_POINT_COUNT * 2)
	for index in STAR_POINT_COUNT * 2:
		var point_radius := radius if index % 2 == 0 else radius * STAR_INNER_RATIO
		points[index] = center + Vector2.from_angle(rotation_angle - PI * 0.5 + PI * index / STAR_POINT_COUNT) * point_radius
	return points
