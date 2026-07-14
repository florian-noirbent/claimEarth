class_name ExcavatorItemAction
extends ItemAction
func create_projectile(origin: Vector2, aim: Vector2, trajectory: ItemTrajectoryService, velocity: Vector2) -> Dictionary:
	return {"gravity":factory.gravity,"fuse_seconds":10.0,"velocity":trajectory.launch_velocity(origin,aim,factory.throw_distance_hint,factory.gravity)+velocity*0.15,"visual_texture":definition.icon,"destroyed_by_lava":true}
func resolve(controller: RunItemController, impact: Vector2, _projectile: ItemProjectile, kind: StringName = &"impact") -> void:
	if kind == &"impact": controller.spawn_excavator(impact, factory)
