## Creates a bouncing, temporary world-light projectile.
class_name FlareItemAction
extends ItemAction


func create_projectile(origin: Vector2, aim_position: Vector2, trajectory_service: ItemTrajectoryService, thrower_velocity: Vector2) -> Dictionary:
	var launch_velocity := trajectory_service.launch_velocity(origin, aim_position, factory.throw_distance_hint, factory.gravity)
	return {
		"gravity": factory.gravity,
		"fuse_seconds": factory.fuse_seconds,
		"velocity": launch_velocity + thrower_velocity * factory.thrower_velocity_influence,
		"color": factory.projectile_color,
		"outline_color": factory.projectile_outline_color,
		"polygon": factory.projectile_points,
		"destroyed_by_lava": true,
		"bounce_on_impact": true,
		"bounce_damping": factory.bounce_damping,
		"horizontal_bounce_damping": factory.horizontal_bounce_damping,
		"light_definition": factory.light_definition,
		"visual_texture": definition.icon,
	}
