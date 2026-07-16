## Owns transient gameplay effects such as camera shake and impact rings.
class_name GameplayFeedback
extends Node2D


const RingEffectScript = preload("res://src/presentation/ring_effect.gd")
const DirectionalPulseEffectScript = preload("res://src/presentation/directional_pulse_effect.gd")


func spawn_ring(world_position: Vector2, color: Color, radius: float) -> void:
	var ring = RingEffectScript.new()
	ring.global_position = world_position
	ring.color = color
	ring.base_radius = radius
	add_child(ring)


func spawn_directional_pulse(
	world_position: Vector2,
	color: Color,
	width_world: float,
	length_world: float,
	duration_seconds: float,
	front_load_decay: float
) -> void:
	var pulse := DirectionalPulseEffectScript.new()
	pulse.global_position = world_position
	pulse.color = color
	pulse.width_world = maxf(width_world, 1.0)
	pulse.length_world = maxf(length_world, 1.0)
	pulse.duration_seconds = maxf(duration_seconds, 0.01)
	pulse.front_load_decay = front_load_decay
	add_child(pulse)
