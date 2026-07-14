## Applies a configured terrain transformation to the aimed neighboring hex.
class_name TerrainToolItemAction
extends ItemAction


func is_immediate() -> bool:
	return true


func use_immediately(item_controller: RunItemController, aim_position: Vector2) -> float:
	return item_controller.resolve_terrain_tool_use(factory.transformations, aim_position)
