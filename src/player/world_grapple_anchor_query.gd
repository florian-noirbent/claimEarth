class_name WorldGrappleAnchorQuery
extends GrappleAnchorQuery


var _world: WorldGrid
var _terrain_registry: TerrainRegistry
var _hex_radius := 16.0
var _attach_radius := 12.0
var _probe_step := 8.0


func configure(
	world: WorldGrid,
	terrain_registry: TerrainRegistry,
	hex_radius: float,
	attach_radius: float,
	probe_step: float
) -> void:
	_world = world
	_terrain_registry = terrain_registry
	_hex_radius = hex_radius
	_attach_radius = attach_radius
	_probe_step = probe_step


func find_anchor(origin: Vector2, target: Vector2) -> GrappleAnchor:
	if _world == null or _terrain_registry == null:
		return null

	var delta := target - origin
	var distance := delta.length()
	if distance <= 0.001:
		return null

	var direction := delta / distance
	var travel := _probe_step
	while travel <= distance:
		var sample_position := origin + direction * travel
		var cell := HexMetrics.offset_for_world(sample_position, _hex_radius)
		var anchor := _anchor_for_cell(cell)
		if anchor != null:
			return anchor
		travel += _probe_step

	return _anchor_for_cell(HexMetrics.offset_for_world(target, _hex_radius))


func is_anchor_valid(anchor: GrappleAnchor) -> bool:
	if anchor == null or _world == null or _terrain_registry == null:
		return false
	return _anchor_for_cell(anchor.cell) != null


func _anchor_for_cell(cell: Vector2i) -> GrappleAnchor:
	if _world == null or _terrain_registry == null:
		return null
	if not _world.dimensions.is_in_bounds_offset(cell.x, cell.y):
		return null

	var definition := _terrain_registry.get_definition(_world.get_committed_by_offset(cell.x, cell.y))
	if definition == null or not definition.is_hookable:
		return null

	var center := HexMetrics.center_for_offset(cell.x, cell.y, _hex_radius)
	return GrappleAnchor.new(cell, center + Vector2(0.0, -_attach_radius))
