class_name WorldPresenter
extends Node2D


@export var hex_radius := 16.0
@export var visible_row_count := 96

var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _chunk_activity_index: ChunkActivityIndex
var _renderers: Dictionary = {}
var _colliders: Dictionary = {}
var _visible_lookup: Dictionary = {}
var _refresh_count := 0
var _rebuild_count := 0
var _dirty_rebuild_count := 0
var _last_refresh_rebuild_count := 0


func reset() -> void:
	for renderer_variant in _renderers.values():
		var renderer := renderer_variant as Node
		if renderer != null:
			renderer.queue_free()
	for collider_variant in _colliders.values():
		var collider := collider_variant as Node
		if collider != null:
			collider.queue_free()
	_renderers.clear()
	_colliders.clear()
	_world = null
	_terrain_registry = null
	_chunk_activity_index = null
	_visible_lookup.clear()
	reset_stats()


func configure(world: WorldGrid, terrain_registry: TerrainRegistry, chunk_activity_index: ChunkActivityIndex) -> void:
	_world = world
	_terrain_registry = terrain_registry
	_chunk_activity_index = chunk_activity_index
	_chunk_activity_index.mark_all_dirty()
	refresh_visible_chunks(0)


func refresh_visible_chunks(start_row: int) -> void:
	if _world == null or _terrain_registry == null or _chunk_activity_index == null:
		return

	_refresh_count += 1
	_last_refresh_rebuild_count = 0
	var visible_chunks := _chunk_activity_index.visible_chunks_for_depth_window(start_row, visible_row_count)
	var visible_lookup := {}
	for chunk_coord in visible_chunks:
		visible_lookup[chunk_coord] = true
		_ensure_chunk_nodes(chunk_coord)

	var dirty_lookup := {}
	for dirty_chunk in _chunk_activity_index.consume_dirty_chunks():
		dirty_lookup[dirty_chunk] = true

	for existing_coord_variant in _renderers.keys():
		var existing_coord := existing_coord_variant as Vector2i
		var renderer := _renderers[existing_coord] as Node
		var collider := _colliders[existing_coord] as Node
		var is_visible := visible_lookup.has(existing_coord)
		var was_visible := bool(_visible_lookup.get(existing_coord, false))
		if not is_visible:
			if renderer != null:
				renderer.queue_free()
			if collider != null:
				collider.queue_free()
			_renderers.erase(existing_coord)
			_colliders.erase(existing_coord)
			continue
		renderer.visible = true
		collider.visible = true
		if dirty_lookup.has(existing_coord) or not was_visible:
			_rebuild_chunk(existing_coord, dirty_lookup.has(existing_coord))

	_visible_lookup = visible_lookup


func visible_chunk_count() -> int:
	var total := 0
	for renderer_variant in _renderers.values():
		var renderer := renderer_variant as Node
		if renderer.visible:
			total += 1
	return total


func total_renderer_nodes() -> int:
	return _renderers.size()


func total_collider_nodes() -> int:
	return _colliders.size()


func chunk_collision_segment_count(chunk_coord: Vector2i) -> int:
	var collider := _colliders.get(chunk_coord) as WorldChunkCollision
	if collider == null:
		return 0
	return collider.segment_count()


func refresh_count() -> int:
	return _refresh_count


func rebuild_count() -> int:
	return _rebuild_count


func dirty_rebuild_count() -> int:
	return _dirty_rebuild_count


func last_refresh_rebuild_count() -> int:
	return _last_refresh_rebuild_count


func reset_stats() -> void:
	_refresh_count = 0
	_rebuild_count = 0
	_dirty_rebuild_count = 0
	_last_refresh_rebuild_count = 0


func _ensure_chunk_nodes(chunk_coord: Vector2i) -> void:
	if _renderers.has(chunk_coord):
		return

	var chunk_rect := _chunk_activity_index.chunk_rect(chunk_coord)
	var renderer := WorldChunkRenderer.new()
	var collider := WorldChunkCollision.new()
	add_child(renderer)
	add_child(collider)
	_renderers[chunk_coord] = renderer
	_colliders[chunk_coord] = collider
	renderer.configure(_world, _terrain_registry, chunk_coord, chunk_rect)
	collider.configure(_world, _terrain_registry, chunk_coord, chunk_rect, hex_radius)


func _rebuild_chunk(chunk_coord: Vector2i, caused_by_dirty_chunk: bool) -> void:
	var chunk_rect := _chunk_activity_index.chunk_rect(chunk_coord)
	var renderer := _renderers[chunk_coord] as WorldChunkRenderer
	var collider := _colliders[chunk_coord] as WorldChunkCollision
	renderer.configure(_world, _terrain_registry, chunk_coord, chunk_rect)
	collider.configure(_world, _terrain_registry, chunk_coord, chunk_rect, hex_radius)
	_rebuild_count += 1
	_last_refresh_rebuild_count += 1
	if caused_by_dirty_chunk:
		_dirty_rebuild_count += 1
