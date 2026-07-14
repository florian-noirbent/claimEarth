@tool
## Reusable world-space emitter for normal and high-frequency terrain lighting.
class_name WorldLightSource2D
extends Node2D


@export var definition: WorldLightSourceDefinition:
	set(value):
		if definition != null and definition.changed.is_connected(_on_definition_changed):
			definition.changed.disconnect(_on_definition_changed)
		definition = value
		if definition != null and not definition.changed.is_connected(_on_definition_changed):
			definition.changed.connect(_on_definition_changed)
		_restart_source()
@export var emitting := true:
	set(value):
		emitting = value
		_sync_source()

var _simulation_backend: TerrainSimulationBackend
var _hex_radius := 8.0
var _source_id := StringName()
var _light_level_override := -1
var _registered_offset := Vector2i.ZERO
var _registered_light_level := 0
var _registered_update_radius := 0
var _registered_mode := -1
var _is_registered := false


func _ready() -> void:
	set_process(_simulation_backend != null)
	_sync_source()


func _process(_delta: float) -> void:
	sync_now()


func _exit_tree() -> void:
	_unregister_source()


func configure(
	simulation_backend: TerrainSimulationBackend,
	hex_radius: float,
	source_id: StringName = StringName()
) -> void:
	_unregister_source()
	_simulation_backend = simulation_backend
	_hex_radius = maxf(hex_radius, 0.001)
	_source_id = source_id if source_id != StringName() else StringName("world_light:%d" % get_instance_id())
	set_process(is_inside_tree() and _simulation_backend != null)
	_sync_source()


func deconfigure() -> void:
	_unregister_source()
	_simulation_backend = null
	set_process(false)


func set_emitting(is_emitting: bool) -> void:
	emitting = is_emitting


func set_light_level(light_level: int) -> void:
	_light_level_override = clampi(light_level, 1, 255)
	_sync_source()


func clear_light_level_override() -> void:
	_light_level_override = -1
	_sync_source()


## Synchronizes the backend immediately when an owner must consume this frame's position.
func sync_now() -> void:
	_sync_source()


func registered_offset() -> Vector2i:
	return _registered_offset


func is_registered() -> bool:
	return _is_registered


func _sync_source() -> void:
	if not is_inside_tree() or _simulation_backend == null or _source_id == StringName() or not emitting or definition == null:
		_unregister_source()
		return
	var current_offset := HexMetrics.offset_for_world(global_position, _hex_radius)
	var current_level := _effective_light_level()
	var current_mode := definition.update_mode
	var current_radius := definition.update_radius
	if (
		_is_registered
		and current_offset == _registered_offset
		and current_level == _registered_light_level
		and current_mode == _registered_mode
		and current_radius == _registered_update_radius
	):
		return
	var can_update_in_place := _is_registered and current_mode == _registered_mode
	if not can_update_in_place:
		_unregister_source()
	var registered := _register_source(current_mode, current_offset, current_level, current_radius)
	if not registered and can_update_in_place:
		_unregister_source()
	if registered:
		_registered_offset = current_offset
		_registered_light_level = current_level
		_registered_update_radius = current_radius
		_registered_mode = current_mode
		_is_registered = true


func _register_source(mode: int, offset: Vector2i, light_level: int, update_radius: int) -> bool:
	if mode == WorldLightSourceDefinition.UpdateMode.HIGH_FREQUENCY:
		return _simulation_backend.set_high_frequency_light_source(
			_source_id,
			offset,
			light_level,
			update_radius
		)
	return _simulation_backend.set_standard_light_source(_source_id, offset, light_level)


func _unregister_source() -> void:
	if _is_registered and _simulation_backend != null:
		if _registered_mode == WorldLightSourceDefinition.UpdateMode.HIGH_FREQUENCY:
			_simulation_backend.remove_high_frequency_light_source(_source_id)
		else:
			_simulation_backend.remove_standard_light_source(_source_id)
	_is_registered = false
	_registered_light_level = 0
	_registered_update_radius = 0
	_registered_mode = -1


func _restart_source() -> void:
	_unregister_source()
	_sync_source()


func _effective_light_level() -> int:
	return _light_level_override if _light_level_override > 0 else definition.light_level


func _on_definition_changed() -> void:
	_restart_source()
