## Base contract for selected item use behavior.
class_name ItemAction
extends RefCounted


var definition: ItemDefinition
var factory: ItemActionFactory


func _init(definition_value: ItemDefinition, factory_value: ItemActionFactory) -> void:
	definition = definition_value
	factory = factory_value


func can_use(_inventory: ItemInventory) -> bool:
	return true


func locks_throwing_until_resolved() -> bool:
	return false


func is_immediate() -> bool:
	return false


## Performs an in-place use and returns the durability charge to consume.
## Zero means that no valid use occurred.
func use_immediately(_item_controller: RunItemController, _aim_position: Vector2) -> float:
	return 0.0


func create_projectile(_origin: Vector2, _aim_position: Vector2, _trajectory_service: ItemTrajectoryService, _thrower_velocity: Vector2) -> Dictionary:
	return {}


func resolve(_item_controller: RunItemController, _impact_position: Vector2, _projectile: ItemProjectile, _resolution_kind: StringName = &"impact") -> void:
	pass
