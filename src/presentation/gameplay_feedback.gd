## Owns transient gameplay effects such as camera shake and impact rings.
## Each spawn_*/show_* method is one feedback moment routed by FeedbackRouter. Positions are
## world positions, speeds are px/s, radii are world px; this class decides how a moment looks.
class_name GameplayFeedback
extends Node2D


const RingEffectScript = preload("res://src/presentation/ring_effect.gd")
const DirectionalPulseEffectScript = preload("res://src/presentation/directional_pulse_effect.gd")

var _camera: DescendingCameraController


## Hands over the camera that shake requests reach; null detaches it.
func set_camera(camera: DescendingCameraController) -> void:
	_camera = camera


## The single seam for camera shake. intensity is the peak offset in world px; world_position
## is where the cause happened, so the shake model may scale or direct it.
func request_shake(intensity: float, _world_position: Vector2) -> void:
	if is_instance_valid(_camera):
		_camera.apply_shake(intensity)


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


# --- Player ---

## The player started a jump at this body position; is_air_jump marks an extra air jump.
func spawn_jump_dust(_world_position: Vector2, _is_air_jump: bool) -> void:
	pass


## The player touched ground after being airborne, or bounced off it. impact_speed is the
## downward speed lost on the floor; airborne_seconds is the time since the last ground
## contact. Running over hex steps also lands, after well under 0.2 s in the air.
func spawn_landing_dust(_world_position: Vector2, _impact_speed: float, _airborne_seconds: float) -> void:
	pass


## A terrain collision fast enough to fill the impact hazard meter; impact_speed is the
## velocity change. Knockout and impact death add their own moment in the same frame.
func spawn_impact_flash(_world_position: Vector2, _impact_speed: float) -> void:
	pass


## A terrain impact knocked the player out for duration_seconds.
func spawn_knockout_stars(_world_position: Vector2, _duration_seconds: float) -> void:
	pass


## The hook was fired from origin toward target_position; attach or miss follows in the
## same frame. The rope itself is drawn by the player presentation.
func spawn_hook_launch(_origin: Vector2, _target_position: Vector2) -> void:
	pass


## The hook caught terrain (false) or a moving target such as a barrel (true) here.
func spawn_hook_spark(_anchor_position: Vector2, _is_moving_target: bool) -> void:
	pass


## The fired hook found nothing; target_position is where its full range ended.
func spawn_hook_miss(_target_position: Vector2) -> void:
	pass


## The rope let go of this anchor: by_input is true when the player released it, false
## when the anchor was destroyed or an impact tore it off.
func spawn_hook_release(_anchor_position: Vector2, _by_input: bool) -> void:
	pass


## The player's body entered (true) or left (false) liquid of this color at this speed.
func spawn_splash(_world_position: Vector2, _color: Color, _speed: float, _is_entering: bool) -> void:
	pass


## A Sand Worm player started (true) or stopped (false) burrowing through sand.
func spawn_sand_burst(_world_position: Vector2, _is_burrowing: bool) -> void:
	pass


## A hazard meter keeps filling above the warning level; repeats at a fixed interval while
## it does. world_position is the player, cause a DeathCause value, level the meter fill
## from 0 to 1, color the meter's bar color.
func show_hazard_warning(_world_position: Vector2, _cause: StringName, _level: float, _color: Color) -> void:
	pass


## The player died for good here; cause is a DeathCause value.
func spawn_death(world_position: Vector2, _cause: StringName) -> void:
	request_shake(14.0, world_position)


# --- Items and world objects ---

## The player threw a projectile item from origin along the normalized direction.
func spawn_throw(_origin: Vector2, _direction: Vector2, _item: ItemDefinition) -> void:
	pass


## The player used an in-place tool such as the pickaxe or shovel toward direction.
func spawn_tool_swing(_origin: Vector2, _direction: Vector2, _item: ItemDefinition) -> void:
	pass


## A thrown item bounced off terrain; impact_speed is its speed before the bounce.
func spawn_bounce_spark(_world_position: Vector2, _impact_speed: float) -> void:
	pass


## A thrown item without an explosive ended. resolution_kind is &"impact", &"fuse" (timed
## out, such as a flare burning out) or the terrain tag that destroyed it, such as &"lava".
func spawn_projectile_end(_world_position: Vector2, _item: ItemDefinition, _resolution_kind: StringName) -> void:
	pass


## A fluid bottle broke and released fluid of this color.
func spawn_bottle_burst(_world_position: Vector2, _color: Color) -> void:
	pass


## An explosion resolved; radius_world is its blast radius.
func spawn_explosion(world_position: Vector2, color: Color, radius_world: float, is_large: bool) -> void:
	spawn_ring(world_position, color, radius_world * 0.75)
	request_shake(10.0 if is_large else 6.0, world_position)


## A blast lit the chain fuse of a barrel, container, or lying bomb that explodes after
## fuse_seconds.
func spawn_fuse_warning(_world_position: Vector2, _fuse_seconds: float) -> void:
	pass


## An explosion destroyed a world object; object_key is its definition's statistics_key
## (&"item_chest", &"perk_geode", &"explosive_barrel"). spawn_explosion follows.
func spawn_object_debris(_world_position: Vector2, _object_key: StringName) -> void:
	pass


## A rolling or falling barrel rebounded off terrain; impact_speed is the velocity change.
func spawn_barrel_bump(_world_position: Vector2, _impact_speed: float) -> void:
	pass


## A thrown excavator landed and started working.
func spawn_excavator_deploy(_world_position: Vector2) -> void:
	pass


## One excavator drill tick; dug_cell_count is how many cells it wore down (0 to 3).
func spawn_drill_debris(_world_position: Vector2, _dug_cell_count: int) -> void:
	pass


## The flag left the player's hand (true) or its flight ended (false). A false also
## arrives once when a run is configured.
func show_flag_flight(_in_flight: bool) -> void:
	pass


## The flag landed here and claimed its depth.
func spawn_flag_planted(world_position: Vector2) -> void:
	spawn_ring(world_position, Color(0.98, 0.86, 0.32, 0.9), 18.0)


## Terrain destroyed the flying flag here; cause is the terrain tag, such as &"lava".
func spawn_flag_destroyed(_world_position: Vector2, _cause: StringName) -> void:
	pass


## The flag planted here reached the victory depth; follows spawn_flag_planted.
func spawn_victory(_world_position: Vector2) -> void:
	pass


## The player touched a reward container here and it opened; container_key is its
## definition's statistics_key (&"item_chest" or &"perk_geode").
func spawn_chest_burst(_world_position: Vector2, _container_key: StringName) -> void:
	pass


## The player picked a perk (true) or an item (false) from the container that stood here.
func spawn_reward_claimed(_world_position: Vector2, _is_perk: bool) -> void:
	pass
