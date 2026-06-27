## Solves terrain transfer amounts, split flow, liquid contact, and displacement.
class_name TerrainTransferSolver
extends RefCounted


const DIRECTION_FALL := 0
const DIRECTION_SIDE_DOWN := 1
const DIRECTION_SIDE_UP := 2


func try_transfer(source: int, target: int, direction_kind: int, context) -> bool:
	var source_id: int = context.cell_id(source)
	var target_id: int = context.cell_id(target)
	var source_fill: int = context.fill(source)
	var target_fill: int = context.fill(target)
	if source_fill <= 0:
		return false
	if _is_opposite_liquid(source_id, target_id, target_fill, context.metadata):
		context.write_working(source, context.metadata.air_id, 0)
		context.write_working(target, context.metadata.stone_id, 255)
		context.wake_movement(source, target)
		return true
	if direction_kind == DIRECTION_FALL and _try_displace_passable_moving(source, target, source_id, target_id, source_fill, target_fill, context):
		return true
	if not _can_transfer_into(source_id, target_id, target_fill, context.metadata):
		return false
	var amount := transfer_amount(source_id, source_fill, target_fill, direction_kind, context.metadata)
	if amount <= 0:
		return false
	var next_source_fill: int = source_fill - amount
	var next_target_fill: int = target_fill + amount
	context.write_working(source, source_id if next_source_fill > 0 else context.metadata.air_id, next_source_fill)
	context.write_working(target, source_id, next_target_fill)
	context.wake_movement(source, target)
	return true


func try_side_transfers(source: int, targets: Array[int], direction_kind: int, context) -> bool:
	var source_id: int = context.cell_id(source)
	var source_fill: int = context.fill(source)
	if source_fill <= 0:
		return false
	for target in targets:
		var target_id: int = context.cell_id(target)
		var target_fill: int = context.fill(target)
		if _is_opposite_liquid(source_id, target_id, target_fill, context.metadata):
			context.write_working(source, context.metadata.air_id, 0)
			context.write_working(target, context.metadata.stone_id, 255)
			context.wake_movement(source, target)
			return true
	var candidates: Array[Dictionary] = []
	var total_capacity := 0
	for target in targets:
		var target_id: int = context.cell_id(target)
		var target_fill: int = context.fill(target)
		if not _can_transfer_into(source_id, target_id, target_fill, context.metadata):
			continue
		var capacity: int = side_transfer_capacity(source_id, source_fill, target_fill, direction_kind, context.metadata)
		if capacity <= 0:
			continue
		candidates.append({
			"index": target,
			"fill": target_fill,
			"capacity": capacity,
			"amount": 0,
		})
		total_capacity += capacity
	if candidates.is_empty():
		return false
	var budget := mini(context.metadata.transfer_rate(source_id, direction_kind), mini(source_fill, total_capacity))
	if budget <= 0:
		return false
	allocate_split_budget(candidates, budget)
	var total_amount := 0
	for candidate in candidates:
		total_amount += int(candidate["amount"])
	if total_amount <= 0:
		return false
	var next_source_fill: int = source_fill - total_amount
	context.write_working(source, source_id if next_source_fill > 0 else context.metadata.air_id, next_source_fill)
	for candidate in candidates:
		var amount := int(candidate["amount"])
		if amount <= 0:
			continue
		var target := int(candidate["index"])
		var target_fill := int(candidate["fill"])
		context.write_working(target, source_id, target_fill + amount)
		context.wake_movement(source, target)
	return true


func allocate_split_budget(candidates: Array[Dictionary], budget: int) -> void:
	var remaining := budget
	var base_share := int(budget / candidates.size())
	var remainder := budget % candidates.size()
	for index in range(candidates.size()):
		var requested := base_share
		if index < remainder:
			requested += 1
		var amount := mini(int(candidates[index]["capacity"]), requested)
		candidates[index]["amount"] = amount
		remaining -= amount
	while remaining > 0:
		var moved := false
		for index in range(candidates.size()):
			var amount := int(candidates[index]["amount"])
			var capacity := int(candidates[index]["capacity"])
			if amount >= capacity:
				continue
			candidates[index]["amount"] = amount + 1
			remaining -= 1
			moved = true
			if remaining <= 0:
				break
		if not moved:
			break


func transfer_amount(source_id: int, source_fill: int, target_fill: int, direction_kind: int, metadata: CompiledTerrainData) -> int:
	var rate := metadata.transfer_rate(source_id, direction_kind)
	var capacity := 255 - target_fill
	if rate <= 0 or capacity <= 0:
		return 0
	if direction_kind == DIRECTION_FALL:
		return mini(source_fill, mini(rate, capacity))
	return mini(rate, side_transfer_capacity(source_id, source_fill, target_fill, direction_kind, metadata))


func side_transfer_capacity(source_id: int, source_fill: int, target_fill: int, direction_kind: int, metadata: CompiledTerrainData) -> int:
	var raw_capacity := 255 - target_fill
	if raw_capacity <= 0:
		return 0
	var min_difference := metadata.min_fill_difference(source_id)
	if min_difference > 0 and source_fill - target_fill < min_difference:
		return 0
	var offset := metadata.side_flow_offset(source_id)
	var equilibrium_distance := 0
	if direction_kind == DIRECTION_SIDE_DOWN:
		equilibrium_distance = source_fill - target_fill + offset
	elif direction_kind == DIRECTION_SIDE_UP:
		equilibrium_distance = source_fill - target_fill - offset
	else:
		return 0
	if equilibrium_distance <= 0:
		return 0
	return mini(source_fill, mini(raw_capacity, int(equilibrium_distance / 2)))


func _is_opposite_liquid(source_id: int, target_id: int, target_fill: int, metadata: CompiledTerrainData) -> bool:
	return target_fill > 0 and source_id != target_id and metadata.motion(source_id) == CompiledTerrainData.MOTION_LIQUID and metadata.motion(target_id) == CompiledTerrainData.MOTION_LIQUID


func _try_displace_passable_moving(source: int, target: int, source_id: int, target_id: int, source_fill: int, target_fill: int, context) -> bool:
	if not context.metadata.displaces_passable_moving_on_fall(source_id):
		return false
	if target_fill <= 0 or target_id == source_id:
		return false
	if not context.metadata.is_moving(target_id) or not context.metadata.is_passable(target_id):
		return false
	context.write_working(source, target_id, target_fill)
	context.write_working(target, source_id, source_fill)
	context.wake_movement(source, target)
	return true


func _can_transfer_into(source_id: int, target_id: int, target_fill: int, metadata: CompiledTerrainData) -> bool:
	if target_id == source_id:
		return true
	return target_fill <= 0 and target_id == metadata.air_id
