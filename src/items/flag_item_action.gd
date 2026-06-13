class_name FlagItemAction
extends ItemAction


func create_projectile(origin: Vector2, aim_position: Vector2, trajectory_service, thrower_velocity: Vector2) -> Dictionary:
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
		"destroyed_by_lava": factory.destroyed_by_lava,
		"ignores_water": factory.ignores_water,
	}


func resolve(app_root, impact_position: Vector2, projectile) -> void:
	app_root.resolve_flag_landing(self, impact_position, projectile)
