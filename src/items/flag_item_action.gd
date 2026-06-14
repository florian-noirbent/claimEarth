class_name FlagItemAction
extends ItemAction


func create_projectile(origin: Vector2, aim_position: Vector2, trajectory_service: ItemTrajectoryService, thrower_velocity: Vector2) -> Dictionary:
	var launch_velocity: Vector2 = trajectory_service.launch_velocity(
		origin,
		aim_position,
		factory.throw_distance_hint,
		factory.gravity
	)
	return {
		"gravity": factory.gravity,
		"fuse_seconds": 10.0,
		"velocity": launch_velocity + thrower_velocity * factory.thrower_velocity_influence,
		"radius": 0,
		"lethal_radius": 0,
		"color": factory.projectile_color,
		"outline_color": factory.projectile_outline_color,
		"polygon": factory.projectile_points,
		"destroyed_by_lava": factory.destroyed_by_lava,
		"ignores_water": factory.ignores_water,
	}


func locks_throwing_until_resolved() -> bool:
	return true


func resolve(item_controller: RunItemController, impact_position: Vector2, projectile: ItemProjectile, resolution_kind: StringName = &"impact") -> void:
	item_controller.resolve_flag_landing(self, impact_position, projectile, resolution_kind)
