## Deposits configured fluid into the closest available Air hexes at impact.
class_name FluidBottleItemAction
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
		"visual_texture": definition.icon,
	}


func resolve(item_controller: RunItemController, impact_position: Vector2, _projectile: ItemProjectile, resolution_kind: StringName = &"impact") -> void:
	if resolution_kind == &"impact":
		item_controller.resolve_fluid_bottle_impact(factory.deposited_terrain, impact_position)
