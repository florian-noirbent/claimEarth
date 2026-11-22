## Owns transient gameplay effects and camera shake requests.
## Each spawn_*/show_* method is one feedback moment routed by FeedbackRouter. Positions are
## world positions, speeds are px/s, radii are world px; this class decides how a moment looks
## by choosing a recipe from the effect library and the scale, tint, and strength to play it at.
class_name GameplayFeedback
extends Node2D


const DirectionalPulseEffectScript = preload("res://src/presentation/directional_pulse_effect.gd")
const EFFECTS_NODE_NAME := "WorldEffects"
const FLAG_MARKER_NODE_NAME := "PlantedFlag"
## Strength a moment plays at when its speed only just passes its threshold.
const MIN_STRENGTH := 0.35

var _camera: DescendingCameraController
var _effects: WorldEffects
var _library := GameplayEffectLibrary.new()
var _clock := 0.0
var _barrel_bump_ready_at := 0.0
var _flag_marker: Sprite2D
var _session_active := true
## Set by the moments that end a run; from then on feedback no longer freezes.
var _run_ended := false
## Bodies with an attached effect, by instance id so a freed body is simply gone.
var _attached_body_ids := PackedInt64Array()
var _attached_effects: Array[AttachedEffect] = []
var _attached_waits := PackedFloat32Array()


func _ready() -> void:
	_effects = get_node_or_null(EFFECTS_NODE_NAME) as WorldEffects
	if _effects == null:
		_effects = WorldEffects.new()
		_effects.name = EFFECTS_NODE_NAME
		add_child(_effects)
	if _effects.library != null:
		_library = _effects.library


func _process(delta: float) -> void:
	_clock += delta
	_sync_anchor()
	_advance_attached_effects(delta)


## The node that plays this feedback's effect recipes.
func effects() -> WorldEffects:
	return _effects


## Hands over the camera that shake requests reach; null detaches it.
func set_camera(camera: DescendingCameraController) -> void:
	if is_instance_valid(_camera) and _camera != camera:
		_camera.set_shake_suspended(false)
	_camera = camera
	_apply_suspension()


## The run session was suspended (false) or resumed (true). While it is suspended, effects,
## attached effects, and the camera shake hold their current frame like the rest of the frozen
## world, and go on from there when it resumes. A run that ended (death, planted or destroyed
## flag) never resumes, so from that moment feedback keeps running and the last effects and
## the shake play out behind the result screens.
func set_active(is_active: bool) -> void:
	_session_active = is_active
	_apply_suspension()


func is_suspended() -> bool:
	return not _session_active and not _run_ended


## The single seam for camera shake. intensity is the peak offset in world px; world_position
## is where the cause happened, so the shake model may scale or direct it.
func request_shake(intensity: float, world_position: Vector2) -> void:
	if is_instance_valid(_camera):
		_camera.apply_shake(intensity, world_position)


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
func spawn_jump_dust(world_position: Vector2, is_air_jump: bool) -> void:
	var recipe := _library.air_jump if is_air_jump else _library.jump_dust
	_play(recipe, world_position + _library.player_feet_offset)


## The player touched ground after being airborne, or bounced off it. impact_speed is the
## downward speed lost on the floor; airborne_seconds is the time since the last ground
## contact. Running over hex steps also lands, after well under 0.2 s in the air; those
## footsteps show nothing.
func spawn_landing_dust(world_position: Vector2, impact_speed: float, airborne_seconds: float) -> void:
	if airborne_seconds < _library.landing_min_airborne_seconds:
		return
	var strength := _strength(impact_speed, _library.landing_min_speed, _library.landing_full_speed)
	if strength > 0.0:
		_play(_library.landing_dust, world_position + _library.player_feet_offset, 1.0, Color.WHITE, Vector2.RIGHT, strength)


## A terrain collision fast enough to fill the impact hazard meter; impact_speed is the
## velocity change. Knockout and impact death add their own moment in the same frame.
func spawn_impact_flash(world_position: Vector2, impact_speed: float) -> void:
	var strength := _strength(impact_speed, _library.impact_min_speed, _library.impact_full_speed)
	if strength > 0.0:
		_play(_library.impact_flash, world_position, strength, Color.WHITE, Vector2.RIGHT, strength)


## A terrain impact knocked the player out for duration_seconds.
func spawn_knockout_stars(world_position: Vector2, duration_seconds: float) -> void:
	_play(_library.knockout_stars, world_position + _library.player_head_offset, 1.0, Color.WHITE, Vector2.RIGHT, 1.0, duration_seconds)


## The hook was fired from origin toward target_position; attach or miss follows in the
## same frame. The rope itself is drawn by the player presentation.
func spawn_hook_launch(origin: Vector2, target_position: Vector2) -> void:
	_play(_library.hook_launch, origin, 1.0, Color.WHITE, target_position - origin)


## The hook caught terrain (false) or a moving target such as a barrel (true) here.
func spawn_hook_spark(anchor_position: Vector2, is_moving_target: bool) -> void:
	_play(_library.hook_spark_moving if is_moving_target else _library.hook_spark_terrain, anchor_position)


## The fired hook found nothing; target_position is where its full range ended.
func spawn_hook_miss(target_position: Vector2) -> void:
	_play(_library.hook_miss, target_position)


## The rope let go of this anchor: by_input is true when the player released it, false
## when the anchor was destroyed or an impact tore it off.
func spawn_hook_release(anchor_position: Vector2, by_input: bool) -> void:
	_play(_library.hook_release if by_input else _library.hook_torn_off, anchor_position)


## The player's body entered (true) or left (false) liquid of this color at this speed.
func spawn_splash(world_position: Vector2, color: Color, speed: float, is_entering: bool) -> void:
	var strength := _strength(speed, _library.splash_min_speed, _library.splash_full_speed)
	if strength > 0.0:
		var recipe := _library.splash_enter if is_entering else _library.splash_exit
		_play(recipe, world_position, 1.0, color, Vector2.RIGHT, strength)


## A Sand Worm player started (true) or stopped (false) burrowing through sand.
func spawn_sand_burst(world_position: Vector2, is_burrowing: bool) -> void:
	_play(_library.sand_burst_enter if is_burrowing else _library.sand_burst_exit, world_position)


## A hazard meter keeps filling above the warning level; repeats at a fixed interval while
## it does. world_position is the player, cause a DeathCause value, level the meter fill
## from 0 to 1, color the meter's bar color.
func show_hazard_warning(world_position: Vector2, _cause: StringName, level: float, color: Color) -> void:
	_play(_library.hazard_warning, world_position, lerpf(0.8, 1.25, clampf(level, 0.0, 1.0)), color)


## The player died for good here; cause is a DeathCause value.
func spawn_death(world_position: Vector2, cause: StringName) -> void:
	_end_run()
	_play(_library.death, world_position)
	_play(GameplayEffectLibrary.keyed(_library.death_by_cause, cause, null), world_position)


# --- Items and world objects ---

## A thrown item entered the world. The effect the library attaches to its feedback key, such
## as a fuse spark or a trail, follows the projectile until it is freed.
func show_projectile_effect(projectile: WorldRigidBody2D, item: ItemDefinition) -> void:
	if item == null or not is_instance_valid(projectile):
		return
	var effect: AttachedEffect = _library.projectile_effect_by_key.get(item.feedback_key)
	if effect == null or effect.recipe == null:
		return
	_attached_body_ids.append(projectile.get_instance_id())
	_attached_effects.append(effect)
	_attached_waits.append(0.0)


## Bodies that currently carry an attached effect.
func attached_effect_count() -> int:
	return _attached_body_ids.size()


## The player threw a projectile item from origin along the normalized direction.
func spawn_throw(origin: Vector2, direction: Vector2, _item: ItemDefinition) -> void:
	_play(_library.throw_whoosh, origin, 1.0, Color.WHITE, direction)


## The player used an in-place tool such as the pickaxe or shovel toward direction.
func spawn_tool_swing(origin: Vector2, direction: Vector2, _item: ItemDefinition) -> void:
	_play(_library.tool_swing, origin, 1.0, Color.WHITE, direction)


## A thrown item bounced off terrain; impact_speed is its speed before the bounce.
func spawn_bounce_spark(world_position: Vector2, impact_speed: float) -> void:
	var strength := _strength(impact_speed, _library.bounce_min_speed, _library.bounce_full_speed)
	if strength > 0.0:
		_play(_library.bounce_spark, world_position, 1.0, Color.WHITE, Vector2.RIGHT, strength)


## A thrown item without an explosive ended. resolution_kind is &"impact", &"fuse" (timed
## out, such as a flare burning out) or the terrain tag that destroyed it, such as &"lava".
func spawn_projectile_end(world_position: Vector2, _item: ItemDefinition, resolution_kind: StringName) -> void:
	_play(
		GameplayEffectLibrary.keyed(_library.projectile_end_by_kind, resolution_kind, _library.projectile_end_default),
		world_position
	)


## A fluid bottle broke and released fluid of this color.
func spawn_bottle_burst(world_position: Vector2, color: Color) -> void:
	_play(_library.bottle_burst, world_position, 1.0, color)


## An explosion resolved; radius_world is its blast radius.
func spawn_explosion(world_position: Vector2, color: Color, radius_world: float, is_large: bool) -> void:
	if is_large:
		_play(_library.explosion_large, world_position, radius_world, color)
	_play(_library.explosion, world_position, radius_world, color)
	request_shake(explosion_shake_intensity(radius_world), world_position)


## Peak camera offset in world px an explosion of this blast radius asks for.
func explosion_shake_intensity(radius_world: float) -> float:
	return minf(radius_world * _library.explosion_shake_per_radius, _library.explosion_shake_max)


## A blast lit the chain fuse of a barrel, container, or lying bomb that explodes after
## fuse_seconds.
func spawn_fuse_warning(world_position: Vector2, fuse_seconds: float) -> void:
	_play(_library.fuse_warning, world_position, 1.0, Color.WHITE, Vector2.RIGHT, 1.0, maxf(fuse_seconds, 0.05))


## An explosion destroyed a world object; object_key is its definition's statistics_key
## (&"item_chest", &"perk_geode", &"explosive_barrel"). spawn_explosion follows.
func spawn_object_debris(world_position: Vector2, object_key: StringName) -> void:
	_play(
		GameplayEffectLibrary.keyed(_library.object_debris_by_key, object_key, _library.object_debris_default),
		world_position
	)


## A rolling or falling barrel rebounded off terrain; impact_speed is the velocity change.
## Slow rebounds and rebounds in quick succession show nothing.
func spawn_barrel_bump(world_position: Vector2, impact_speed: float) -> void:
	var strength := _strength(impact_speed, _library.barrel_bump_min_speed, _library.barrel_bump_full_speed)
	if strength <= 0.0 or _clock < _barrel_bump_ready_at:
		return
	_barrel_bump_ready_at = _clock + _library.barrel_bump_cooldown_seconds
	_play(_library.barrel_bump, world_position, 1.0, Color.WHITE, Vector2.RIGHT, strength)


## A thrown excavator landed and started working.
func spawn_excavator_deploy(world_position: Vector2) -> void:
	_play(_library.excavator_deploy, world_position)


## One excavator drill tick; dug_cell_count is how many cells it wore down (0 to 3).
func spawn_drill_debris(world_position: Vector2, dug_cell_count: int) -> void:
	var strength := clampf(float(dug_cell_count) / _library.drill_full_cell_count, MIN_STRENGTH, 1.0)
	_play(_library.drill_debris, world_position, 1.0, Color.WHITE, Vector2.RIGHT, strength)


## The flag left the player's hand (true) or its flight ended (false). A false also
## arrives once when a run is configured. The moment carries no position, so it has no
## world effect; a new throw clears the flag left by an earlier landing.
func show_flag_flight(in_flight: bool) -> void:
	if in_flight:
		_clear_flag_marker()


## The flag landed here and claimed its depth.
func spawn_flag_planted(world_position: Vector2) -> void:
	_end_run()
	_play(_library.flag_planted, world_position)
	_plant_flag_marker(world_position)


## Terrain destroyed the flying flag here; cause is the terrain tag, such as &"lava".
func spawn_flag_destroyed(world_position: Vector2, cause: StringName) -> void:
	_end_run()
	_play(
		GameplayEffectLibrary.keyed(_library.flag_destroyed_by_cause, cause, _library.flag_destroyed_default),
		world_position
	)


## The flag planted here reached the victory depth; follows spawn_flag_planted.
func spawn_victory(world_position: Vector2) -> void:
	_play(_library.victory, world_position)


## The player touched a reward container here and it opened; container_key is its
## definition's statistics_key (&"item_chest" or &"perk_geode").
func spawn_chest_burst(world_position: Vector2, container_key: StringName) -> void:
	_play(
		GameplayEffectLibrary.keyed(_library.container_open_by_key, container_key, _library.container_open_default),
		world_position
	)


## The player picked a perk (true) or an item (false) from the container that stood here.
func spawn_reward_claimed(world_position: Vector2, is_perk: bool) -> void:
	_play(_library.reward_claimed_perk if is_perk else _library.reward_claimed_item, world_position)


## Plays a recipe and requests the shake it asks for.
func _play(
	recipe: EffectRecipe,
	world_position: Vector2,
	effect_scale: float = 1.0,
	tint: Color = Color.WHITE,
	direction: Vector2 = Vector2.RIGHT,
	intensity: float = 1.0,
	duration_seconds: float = 1.0
) -> void:
	if recipe == null or _effects == null:
		return
	_sync_anchor()
	_effects.play(recipe, world_position, effect_scale, tint, direction, intensity, duration_seconds)
	if recipe.shake_intensity > 0.0:
		request_shake(recipe.shake_intensity * (intensity if recipe.shake_scales_with_intensity else 1.0), world_position)


## Plays every attached effect that is due and forgets the ones whose body is gone.
func _advance_attached_effects(delta: float) -> void:
	for index in range(_attached_body_ids.size() - 1, -1, -1):
		var body := instance_from_id(_attached_body_ids[index]) as WorldRigidBody2D
		if body == null or body.is_queued_for_deletion() or not body.is_inside_tree():
			_attached_body_ids.remove_at(index)
			_attached_effects.remove_at(index)
			_attached_waits.remove_at(index)
			continue
		var wait := _attached_waits[index] - delta
		if wait <= 0.0:
			var effect := _attached_effects[index]
			_play_attached(effect, body)
			wait = maxf(wait + effect.interval_seconds, 0.0)
		_attached_waits[index] = wait


func _play_attached(effect: AttachedEffect, body: WorldRigidBody2D) -> void:
	var point := body.visual_point(effect.attach_offset)
	var direction := Vector2.RIGHT
	if effect.aim == AttachedEffect.Aim.OUTWARD:
		direction = point - body.global_position
	elif effect.aim == AttachedEffect.Aim.MOTION:
		direction = body.velocity
	_play(effect.recipe, point, effect.effect_scale, Color.WHITE, direction)


func _end_run() -> void:
	_run_ended = true
	_apply_suspension()


## A disabled process mode stops this node, the effect layers below it, and their tweens.
func _apply_suspension() -> void:
	var suspended := is_suspended()
	process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_camera):
		_camera.set_shake_suspended(suspended)


## Strength from MIN_STRENGTH to 1 of a moment at this speed, or 0 below its threshold.
func _strength(speed: float, min_speed: float, full_speed: float) -> float:
	if speed < min_speed:
		return 0.0
	return lerpf(MIN_STRENGTH, 1.0, clampf(inverse_lerp(min_speed, maxf(full_speed, min_speed + 1.0), speed), 0.0, 1.0))


## Effects that follow the player follow the node the run camera follows.
func _sync_anchor() -> void:
	if _effects != null and is_instance_valid(_camera) and is_instance_valid(_camera.target):
		_effects.set_anchor_position(_camera.target.global_position)


func _plant_flag_marker(world_position: Vector2) -> void:
	if _library.flag_marker_texture == null:
		return
	_clear_flag_marker()
	_flag_marker = Sprite2D.new()
	_flag_marker.name = FLAG_MARKER_NODE_NAME
	_flag_marker.texture = _library.flag_marker_texture
	_flag_marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_flag_marker.z_index = 10
	# The sprite grows out of the pole's foot, which stays on the ground.
	_flag_marker.offset = _library.flag_marker_texture.get_size() * 0.5 - _library.flag_marker_foot
	_flag_marker.global_position = world_position + _library.flag_marker_offset
	var full_scale := Vector2.ONE * _library.flag_marker_scale
	_flag_marker.scale = full_scale * Vector2(1.0, 0.1)
	add_child(_flag_marker)
	if _library.flag_marker_pop_seconds <= 0.0:
		_flag_marker.scale = full_scale
		return
	var pop := _flag_marker.create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_flag_marker, "scale", full_scale, _library.flag_marker_pop_seconds)


func _clear_flag_marker() -> void:
	if is_instance_valid(_flag_marker):
		_flag_marker.queue_free()
	_flag_marker = null
