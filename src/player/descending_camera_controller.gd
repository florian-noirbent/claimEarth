## Applies descending camera model output to the active Camera2D.
class_name DescendingCameraController
extends Camera2D


## Smallest share of the resting view a shaking camera keeps when it zooms in.
const MIN_SHAKE_VIEW_SHARE := 0.8

@export var target: Node2D
@export var top_anchor_ratio := 1.0 / 3.0
@export_range(0.0, 1.0, 0.01) var upward_recovery_screen_ratio_per_second := 0.25
@export_range(0.0, 10.0, 0.25) var upward_recovery_margin_hexes := 2.0
@export var min_y := -10000.0
@export var max_y := 100000.0
@export var fixed_x := 0.0
@export_group("Shake")
## Scales every camera shake; 0 turns shake off. A settings screen sets this.
@export_range(0.0, 2.0, 0.05) var shake_intensity_multiplier := 1.0:
	set(value):
		shake_intensity_multiplier = value
		_shake.intensity_multiplier = value
## Camera offset in world px at full trauma.
@export_range(0.0, 128.0, 0.5) var shake_max_offset := 26.0
@export_range(0.0, 10.0, 0.05) var shake_max_rotation_degrees := 1.2
## Exponential trauma decay per second.
@export_range(0.1, 20.0, 0.1) var shake_trauma_decay := 3.2
## Noise wiggles per second.
@export_range(1.0, 60.0, 0.5) var shake_frequency := 18.0
## Share of a shake's intensity that pushes the camera away from its cause.
@export_range(0.0, 2.0, 0.05) var shake_kick_ratio := 0.6
@export_range(0.1, 60.0, 0.1) var shake_kick_decay := 14.0
## Causes closer than this to the target shake at full strength; world px.
@export_range(0.0, 10000.0, 1.0) var shake_full_distance := 220.0
## Causes at or beyond this distance from the target do not shake; world px.
@export_range(1.0, 20000.0, 1.0) var shake_zero_distance := 1500.0
@export var shake_seed := 1

var _model := DescendingCameraModel.new()
var _shake := CameraShakeModel.new()
var _world_bottom_edge := INF
## Zoom without shake; the camera zooms in from it while shaking.
var _base_zoom := Vector2.ONE
## Holds the shake at its current offset while gameplay is suspended.
var _shake_suspended := false


func _ready() -> void:
	_model.top_anchor_ratio = top_anchor_ratio
	_model.upward_recovery_screen_ratio_per_second = upward_recovery_screen_ratio_per_second
	_model.min_y = min_y
	_model.max_y = max_y
	_model.fixed_x = fixed_x
	_model.reset(global_position.y)
	_shake = CameraShakeModel.new(shake_seed)
	_shake.max_offset = shake_max_offset
	_shake.max_rotation = deg_to_rad(shake_max_rotation_degrees)
	_shake.trauma_decay = shake_trauma_decay
	_shake.frequency = shake_frequency
	_shake.kick_ratio = shake_kick_ratio
	_shake.kick_decay = shake_kick_decay
	_shake.full_distance = shake_full_distance
	_shake.zero_distance = shake_zero_distance
	_shake.intensity_multiplier = shake_intensity_multiplier
	ignore_rotation = false
	_base_zoom = zoom


func _process(delta: float) -> void:
	if target == null:
		return
	var viewport_size := get_viewport_rect().size
	var visible_world_size := Vector2(
		viewport_size.x / maxf(absf(_base_zoom.x), 0.001),
		viewport_size.y / maxf(absf(_base_zoom.y), 0.001)
	)
	_apply_world_bottom_edge(visible_world_size.y)
	var target_position := _model.update(target.global_position, visible_world_size, delta)
	if not _shake_suspended:
		_shake.advance(delta)
	var shake_zoom := _shake_zoom(visible_world_size)
	global_position = _shaken_position(target_position, visible_world_size / shake_zoom)
	global_rotation = _shake.rotation()
	zoom = _base_zoom * shake_zoom


func configure_bounds(min_y_value: float, max_y_value: float) -> void:
	min_y = min_y_value
	max_y = max_y_value
	_model.min_y = min_y_value
	_model.max_y = max_y_value


func configure_world_bottom_edge(bottom_edge: float) -> void:
	_world_bottom_edge = bottom_edge


func _apply_world_bottom_edge(visible_world_height: float) -> void:
	if is_inf(_world_bottom_edge):
		return
	_model.max_y = _world_bottom_edge - maxf(visible_world_height, 0.0) * 0.5


func configure_horizontal_lock(fixed_x_value: float, zoom_value: Vector2) -> void:
	fixed_x = fixed_x_value
	_model.fixed_x = fixed_x_value
	_base_zoom = zoom_value
	zoom = zoom_value


func configure_upward_recovery_margin(hex_radius: float) -> void:
	_model.upward_recovery_margin_y = upward_recovery_margin_hexes * hex_radius * sqrt(3.0)


## Adds a shake whose peak offset is about intensity world px. source_position is where
## the cause happened: far causes shake less and the camera is pushed away from it.
func apply_shake(intensity: float, source_position: Vector2 = Vector2.INF) -> void:
	if not source_position.is_finite():
		_shake.add_shake(intensity)
		return
	var listener := target.global_position if is_instance_valid(target) else global_position
	_shake.add_shake(intensity, source_position - listener)


func set_shake_intensity_multiplier(multiplier: float) -> void:
	shake_intensity_multiplier = clampf(multiplier, 0.0, 2.0)


## Freezes (true) or resumes (false) the shake. A suspended shake keeps its offset, roll, and
## zoom, like the frozen world behind a pause screen, and decays on from there when resumed.
func set_shake_suspended(is_suspended: bool) -> void:
	_shake_suspended = is_suspended


## Current shake trauma from 0 to 1.
func shake_trauma() -> float:
	return _shake.trauma


## Zoom factor that keeps a shaking view between the sides of the resting view, so shake
## never reveals what lies beside the map. It follows the shake's envelope, not its noise.
func _shake_zoom(visible_world_size: Vector2) -> float:
	var half_size := visible_world_size * 0.5
	var margin := _shake.offset_envelope() + sin(_shake.rotation_envelope()) * half_size.y
	var kept := (half_size.x - margin) / maxf(half_size.x, 0.001)
	return 1.0 / clampf(kept, MIN_SHAKE_VIEW_SHARE, 1.0)


## Adds the shake to the followed position without showing anything below the world's
## bottom edge. shown_world_size is the world area the zoomed-in shaking view covers.
func _shaken_position(follow_position: Vector2, shown_world_size: Vector2) -> Vector2:
	var shaken := follow_position + _shake.offset()
	if not is_inf(_world_bottom_edge):
		var roll_drop := sin(_shake.rotation_envelope()) * shown_world_size.x * 0.5
		shaken.y = minf(shaken.y, _world_bottom_edge - shown_world_size.y * 0.5 - roll_drop)
	return shaken
