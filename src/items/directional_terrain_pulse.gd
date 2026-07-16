## Advances a bounded downward terrain pulse without owning rendering or run state.
class_name DirectionalTerrainPulse
extends RefCounted


var definition: DirectionalTerrainPulseDefinition
var origin := Vector2i.ZERO
var elapsed := 0.0
var completed_steps := 0
var completed_ticks := 0


func _init(definition_value: DirectionalTerrainPulseDefinition, origin_value := Vector2i.ZERO) -> void:
	definition = definition_value
	origin = origin_value


func is_complete() -> bool:
	return definition == null or completed_steps >= definition.step_count


func advance(delta: float, world: WorldGrid, air_id: int) -> TerrainChangeSet:
	var changes := TerrainChangeSet.new(world.dimensions if world != null else null)
	if is_complete() or delta <= 0.0 or world == null or air_id < 0:
		return changes
	elapsed += delta
	while elapsed + 0.000001 >= definition.step_interval_seconds and completed_ticks < definition.pulse_tick_count:
		elapsed -= definition.step_interval_seconds
		completed_ticks += 1
		_clear_steps_until(definition.steps_after_tick(completed_ticks), world, air_id, changes)
	return changes


func current_step_center() -> Vector2i:
	return Vector2i(origin.x, origin.y + completed_steps)


func _clear_steps_until(target_step_count: int, world: WorldGrid, air_id: int, changes: TerrainChangeSet) -> void:
	while completed_steps < target_step_count:
		completed_steps += 1
		_clear_step(world, air_id, changes)


func _clear_step(world: WorldGrid, air_id: int, changes: TerrainChangeSet) -> void:
	var half_width := definition.width / 2
	var row := origin.y + completed_steps
	for column in range(origin.x - half_width, origin.x + half_width + 1):
		if not world.dimensions.is_in_bounds_offset(column, row):
			continue
		var change := world.set_committed_by_offset(column, row, air_id, WorldGrid.AIR_QUANTITY)
		changes.add_cell_change(change)
