class_name BombItemAction
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
		"fuse_seconds": factory.fuse_seconds,
		"velocity": launch_velocity + thrower_velocity * factory.thrower_velocity_influence,
		"radius": factory.blast_radius,
		"lethal_radius": factory.lethal_radius,
		"color": factory.projectile_color,
		"outline_color": factory.projectile_outline_color,
		"polygon": factory.projectile_points,
		"destroyed_by_lava": true,
		"bounce_on_impact": true,
		"bounce_damping": factory.bounce_damping,
		"horizontal_bounce_damping": factory.horizontal_bounce_damping,
	}


func resolve(item_controller: RunItemController, impact_position: Vector2, projectile: ItemProjectile, _resolution_kind: StringName = &"impact") -> void:
	item_controller.resolve_bomb_explosion(self, impact_position, projectile)
