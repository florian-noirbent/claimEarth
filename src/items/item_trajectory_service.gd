class_name ItemTrajectoryService
extends RefCounted


func launch_velocity(origin: Vector2, target: Vector2, distance_hint: float, gravity: float) -> Vector2:
	var direction := (target - origin).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var speed := sqrt(maxf(distance_hint * gravity, 1.0))
	return direction * speed
