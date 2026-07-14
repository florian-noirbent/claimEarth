## Defines the replaceable terrain simulation backend contract.
class_name TerrainSimulationBackend
extends RefCounted


func initialize(_world: WorldGrid, _registry: TerrainRegistry, _seed: int) -> void:
	pass


func queue_change(_change: CellChange) -> void:
	pass


func advance(_max_passes: int) -> SimulationProgress:
	return SimulationProgress.new()


func commit_if_ready() -> SimulationCommit:
	return SimulationCommit.new()


func read_region(_region: Rect2i) -> PackedByteArray:
	return PackedByteArray()


func shutdown() -> void:
	pass


func attach_to(_parent: Node) -> void:
	pass


func active_texture() -> Texture2D:
	return null


func presentation_texture() -> Texture2D:
	return active_texture()


func presentation_even_texture() -> Texture2D:
	return presentation_texture()


func notify_external_changes(_change_set: TerrainChangeSet) -> void:
	pass


func set_high_frequency_light_source(
	_source_id: StringName,
	_offset: Vector2i,
	_light_level: int,
	_update_radius: int
) -> bool:
	return false


func remove_high_frequency_light_source(_source_id: StringName) -> bool:
	return false


func set_standard_light_source(_source_id: StringName, _offset: Vector2i, _light_level: int) -> bool:
	return false


func remove_standard_light_source(_source_id: StringName) -> bool:
	return false


func clear_standard_light_sources() -> void:
	pass


func standard_light_source_count() -> int:
	return 0


func standard_light_level_at(_offset: Vector2i) -> int:
	return 0


func is_tick_in_progress() -> bool:
	return false


func has_commit_ready() -> bool:
	return false
