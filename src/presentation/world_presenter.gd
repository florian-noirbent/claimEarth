class_name WorldPresenter
extends Node2D


@export var hex_radius := 16.0
@export var visible_row_count := 96
@export var build_budget_usec := 1200
@export var max_results_applied_per_frame := 1
@export var build_collision := true

var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _metadata: CompiledTerrainData
var _chunk_activity_index: ChunkActivityIndex
var _renderers: Dictionary = {}
var _colliders: Dictionary = {}
var _visible_lookup: Dictionary = {}
var _chunk_revisions: Dictionary = {}
var _executor := CooperativeChunkJobExecutor.new()
var _pending_results: Array[ChunkBuildResult] = []
var _refresh_count := 0
var _rebuild_count := 0
var _dirty_rebuild_count := 0
var _last_refresh_rebuild_count := 0
var _discarded_result_count := 0
var _last_build_usec := 0


func reset() -> void:
	for renderer_variant in _renderers.values():
		(renderer_variant as Node).queue_free()
	for collider_variant in _colliders.values():
		(collider_variant as Node).queue_free()
	_renderers.clear()
	_colliders.clear()
	_visible_lookup.clear()
	_chunk_revisions.clear()
	_executor.clear()
	_pending_results.clear()
	_world = null
	_terrain_registry = null
	_metadata = null
	_chunk_activity_index = null
	reset_stats()


func configure(world: WorldGrid, terrain_registry: TerrainRegistry, chunk_activity_index: ChunkActivityIndex) -> void:
	_world = world
	_terrain_registry = terrain_registry
	_metadata = CompiledTerrainData.compile(terrain_registry)
	_chunk_activity_index = chunk_activity_index
	_chunk_activity_index.mark_all_dirty()
	refresh_visible_chunks(0)
	# Initial presentation is part of world attachment, before play resumes.
	while _executor.pending_count() > 0:
		_executor.advance(1000000)
	_apply_completed_results(1000000)


func refresh_visible_chunks(start_row: int) -> void:
	if _world == null or _chunk_activity_index == null:
		return
	_refresh_count += 1
	_last_refresh_rebuild_count = 0
	var visible_chunks := _chunk_activity_index.visible_chunks_for_depth_window(start_row, visible_row_count)
	var visible_lookup := {}
	var requested_masks := {}
	for chunk_coord in visible_chunks:
		visible_lookup[chunk_coord] = true
		if _ensure_chunk_nodes(chunk_coord):
			requested_masks[chunk_coord] = _effective_layer_mask(TerrainLayerMask.ALL)
	for existing_coord_variant in _renderers.keys():
		var existing_coord := existing_coord_variant as Vector2i
		if visible_lookup.has(existing_coord):
			continue
		(_renderers[existing_coord] as Node).queue_free()
		if _colliders.has(existing_coord):
			(_colliders[existing_coord] as Node).queue_free()
		_renderers.erase(existing_coord)
		_colliders.erase(existing_coord)
		_chunk_revisions.erase(existing_coord)
	var dirty_work := _chunk_activity_index.consume_dirty_work()
	for coord_variant in dirty_work.keys():
		var coord := coord_variant as Vector2i
		if visible_lookup.has(coord):
			var work := dirty_work[coord] as Dictionary
			requested_masks[coord] = _effective_layer_mask(int(requested_masks.get(coord, TerrainLayerMask.NONE)) | int(work["mask"]))
	for coord_variant in requested_masks.keys():
		var coord := coord_variant as Vector2i
		var collision_indices := PackedInt32Array()
		if build_collision and dirty_work.has(coord):
			collision_indices = (dirty_work[coord] as Dictionary)["collision_indices"] as PackedInt32Array
		_enqueue_chunk_job(coord, int(requested_masks[coord]), collision_indices)
	_visible_lookup = visible_lookup
	var started := Time.get_ticks_usec()
	_executor.advance(build_budget_usec)
	_apply_completed_results(max_results_applied_per_frame)
	_last_build_usec = Time.get_ticks_usec() - started


func visible_chunk_count() -> int:
	return _renderers.size()


func total_renderer_nodes() -> int:
	return _renderers.size()


func total_collider_nodes() -> int:
	return _colliders.size() if build_collision else 0


func chunk_collision_segment_count(chunk_coord: Vector2i) -> int:
	if not build_collision:
		return 0
	var collider := _colliders.get(chunk_coord) as WorldChunkCollision
	return collider.segment_count() if collider != null else 0


func chunk_layer_vertex_count(chunk_coord: Vector2i, layer_mask: int) -> int:
	var renderer := _renderers.get(chunk_coord) as WorldChunkRenderer
	return renderer.layer_vertex_count(layer_mask) if renderer != null else 0


func chunk_layer_min_vertex_y(chunk_coord: Vector2i, layer_mask: int) -> float:
	var renderer := _renderers.get(chunk_coord) as WorldChunkRenderer
	return renderer.layer_min_vertex_y(layer_mask) if renderer != null else INF


func refresh_count() -> int:
	return _refresh_count


func rebuild_count() -> int:
	return _rebuild_count


func dirty_rebuild_count() -> int:
	return _dirty_rebuild_count


func last_refresh_rebuild_count() -> int:
	return _last_refresh_rebuild_count


func discarded_result_count() -> int:
	return _discarded_result_count


func pending_job_count() -> int:
	return _executor.pending_count() + _pending_results.size()


func last_build_usec() -> int:
	return _last_build_usec


func reset_stats() -> void:
	_refresh_count = 0
	_rebuild_count = 0
	_dirty_rebuild_count = 0
	_last_refresh_rebuild_count = 0
	_discarded_result_count = 0
	_last_build_usec = 0


func _ensure_chunk_nodes(chunk_coord: Vector2i) -> bool:
	if _renderers.has(chunk_coord):
		return false
	var chunk_rect := _chunk_activity_index.chunk_rect(chunk_coord)
	var renderer := WorldChunkRenderer.new()
	add_child(renderer)
	renderer.configure(chunk_coord, chunk_rect)
	_renderers[chunk_coord] = renderer
	if build_collision:
		var collider := WorldChunkCollision.new()
		add_child(collider)
		collider.chunk_coord = chunk_coord
		collider.chunk_rect = chunk_rect
		_colliders[chunk_coord] = collider
	_chunk_revisions[chunk_coord] = 0
	return true


func _enqueue_chunk_job(chunk_coord: Vector2i, layer_mask: int, collision_indices: PackedInt32Array = PackedInt32Array()) -> void:
	if layer_mask == TerrainLayerMask.NONE:
		return
	for index in range(_pending_results.size() - 1, -1, -1):
		if _pending_results[index].chunk_coord == chunk_coord:
			layer_mask |= _pending_results[index].layer_mask
			if (_pending_results[index].layer_mask & TerrainLayerMask.COLLISION) != 0:
				collision_indices = PackedInt32Array()
			_pending_results.remove_at(index)
			_discarded_result_count += 1
	var revision := int(_chunk_revisions.get(chunk_coord, 0)) + 1
	_chunk_revisions[chunk_coord] = revision
	var chunk_rect := _chunk_activity_index.chunk_rect(chunk_coord)
	var snapshot_rect := chunk_rect.grow(1).intersection(Rect2i(Vector2i.ZERO, Vector2i(_world.dimensions.width, _world.dimensions.depth)))
	var job := ChunkBuildJob.new()
	job.configure(chunk_coord, revision, layer_mask, chunk_rect, snapshot_rect, _world.copy_committed_region(snapshot_rect), _world.copy_committed_fill_region(snapshot_rect), _metadata, hex_radius, _world.dimensions.width, collision_indices)
	_executor.enqueue(job)


func _apply_completed_results(limit: int) -> void:
	_pending_results.append_array(_executor.take_completed())
	var applied := 0
	while not _pending_results.is_empty() and applied < limit:
		var result: ChunkBuildResult = _pending_results.pop_front()
		if int(_chunk_revisions.get(result.chunk_coord, -1)) != result.revision or not _renderers.has(result.chunk_coord):
			_discarded_result_count += 1
			continue
		(_renderers[result.chunk_coord] as WorldChunkRenderer).apply_result(result)
		if build_collision and (result.layer_mask & TerrainLayerMask.COLLISION) != 0 and _colliders.has(result.chunk_coord):
			(_colliders[result.chunk_coord] as WorldChunkCollision).apply_result(result)
		_rebuild_count += 1
		_dirty_rebuild_count += 1
		_last_refresh_rebuild_count += 1
		applied += 1


func _effective_layer_mask(layer_mask: int) -> int:
	return layer_mask if build_collision else layer_mask & ~TerrainLayerMask.COLLISION
