class_name TerrainSimulationBackend
extends RefCounted


func initialize(_world: WorldGrid, _registry: TerrainRegistry, _seed: int) -> void:
	pass


func queue_change(_change: CellChange) -> void:
	pass


func schedule(_active_chunks: Array[Vector2i]) -> void:
	pass


func advance(_time_budget_usec: int) -> SimulationProgress:
	return SimulationProgress.new()


func commit_if_ready() -> SimulationCommit:
	return SimulationCommit.new()


func read_region(_region: Rect2i) -> PackedByteArray:
	return PackedByteArray()


func shutdown() -> void:
	pass
