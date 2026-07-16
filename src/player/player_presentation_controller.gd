## Owns the editor-authored player visuals and their transient animation state.
class_name PlayerPresentationController
extends Node2D


@export var hook_launch_animation_seconds := 0.08

@onready var body_visual: Node2D = %BodyVisual
@onready var body_polygon: Polygon2D = %BodyPolygon
@onready var sand_outline: Line2D = %SandOutline
@onready var rope_line: Line2D = %RopeLine
@onready var hook_indicator: Polygon2D = %HookIndicator

var _hook_launch_elapsed := 0.0
var _hook_launch_duration := 0.0
var _hook_launch_target := Vector2.ZERO


func update_body(
	movement_state: StringName,
	current_velocity: Vector2,
	ragdolling: bool,
	spin_direction: float,
	spin_speed: float,
	delta: float
) -> void:
	if ragdolling:
		body_visual.rotation += spin_direction * spin_speed * delta
		body_visual.scale = Vector2(1.06, 0.94)
		return

	body_visual.rotation = 0.0
	match movement_state:
		PlayerMovementState.RUN:
			body_visual.scale = Vector2(1.05, 0.95)
		PlayerMovementState.JUMP:
			body_visual.scale = Vector2(0.95, 1.08)
		PlayerMovementState.FALL:
			body_visual.scale = Vector2(0.98, 1.03)
		_:
			body_visual.scale = Vector2.ONE

	if absf(current_velocity.x) > 0.001:
		body_visual.scale.x = absf(body_visual.scale.x) * signf(current_velocity.x)


func start_hook_launch(target_world_position: Vector2) -> void:
	_hook_launch_elapsed = 0.0
	_hook_launch_duration = maxf(hook_launch_animation_seconds, 0.001)
	_hook_launch_target = target_world_position


func cancel_hook_launch() -> void:
	_hook_launch_elapsed = 0.0
	_hook_launch_duration = 0.0


func update_grapple(
	attached: bool,
	anchor_world_position: Vector2,
	delta: float
) -> void:
	if _hook_launch_duration > 0.0:
		_hook_launch_elapsed = minf(
			_hook_launch_duration,
			_hook_launch_elapsed + delta
		)
		var progress := _hook_launch_elapsed / _hook_launch_duration
		rope_line.visible = true
		hook_indicator.visible = true
		var animated_end := to_local(_hook_launch_target) * progress
		rope_line.points = PackedVector2Array([
			Vector2.ZERO,
			animated_end,
		])
		hook_indicator.position = animated_end
		if _hook_launch_elapsed < _hook_launch_duration:
			return
		cancel_hook_launch()

	if not attached:
		rope_line.visible = false
		hook_indicator.visible = false
		return

	var local_anchor := to_local(anchor_world_position)
	rope_line.visible = true
	hook_indicator.visible = true
	rope_line.points = PackedVector2Array([
		Vector2.ZERO,
		local_anchor,
	])
	hook_indicator.position = local_anchor


func set_sand_burrow_visible(visible: bool) -> void:
	sand_outline.visible = visible
