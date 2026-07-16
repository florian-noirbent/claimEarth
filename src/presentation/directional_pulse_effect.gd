## Lightweight placeholder visual for a terrain-only directional pulse.
class_name DirectionalPulseEffect
extends Node2D


var color := Color(0.68, 0.24, 0.95, 1.0)
var width_world := 24.0
var length_world := 160.0
var duration_seconds := 1.0
var front_load_decay := 2.65
var _elapsed := 0.0


func _ready() -> void:
	z_index = 20
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= duration_seconds:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var time_progress := clampf(_elapsed / maxf(duration_seconds, 0.001), 0.0, 1.0)
	var propagation_progress := distance_progress()
	var visible_length := length_world * propagation_progress
	var fade := 1.0 - time_progress * 0.55
	var glow_color := color
	glow_color.a *= 0.28 * fade
	var core_color := color
	core_color.a *= fade
	draw_rect(Rect2(Vector2(-width_world * 0.5, 0.0), Vector2(width_world, visible_length)), glow_color, true)
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, visible_length), core_color, maxf(2.0, width_world * 0.16), true)


func distance_progress() -> float:
	var time_progress := clampf(_elapsed / maxf(duration_seconds, 0.001), 0.0, 1.0)
	return DirectionalTerrainPulseDefinition.progress_for_fraction(time_progress, front_load_decay)
