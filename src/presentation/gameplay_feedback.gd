class_name GameplayFeedback
extends Node2D


const RingEffectScript = preload("res://src/presentation/ring_effect.gd")


func spawn_ring(world_position: Vector2, color: Color, radius: float) -> void:
	var ring = RingEffectScript.new()
	ring.global_position = world_position
	ring.color = color
	ring.base_radius = radius
	add_child(ring)
