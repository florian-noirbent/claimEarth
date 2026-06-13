class_name RingEffect
extends Node2D


var color := Color.WHITE
var base_radius := 18.0
var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= 0.28:
		queue_free()


func _draw() -> void:
	var progress := clampf(_age / 0.28, 0.0, 1.0)
	var radius := lerpf(base_radius, base_radius * 2.5, progress)
	var alpha := 1.0 - progress
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(color.r, color.g, color.b, alpha), 3.0)
