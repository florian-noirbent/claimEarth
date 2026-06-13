class_name ItemAction
extends RefCounted


var definition: ItemDefinition
var factory: ItemActionFactory


func _init(definition_value: ItemDefinition, factory_value: ItemActionFactory) -> void:
	definition = definition_value
	factory = factory_value


func can_use(_inventory) -> bool:
	return true


func create_projectile(_origin: Vector2, _aim_position: Vector2, _trajectory_service, _thrower_velocity: Vector2) -> Dictionary:
	return {}


func resolve(_app_root, _impact_position: Vector2, _projectile) -> void:
	pass
