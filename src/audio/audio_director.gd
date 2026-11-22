## Maps gameplay and UI events to audio playback without owning gameplay state.
## Each play_* method is one feedback moment routed by FeedbackRouter. Positions are world
## positions, speeds are px/s, radii are world px; this class decides how a moment sounds.
class_name AudioDirector
extends Node


# --- Run flow and UI ---

## Gameplay of a new run became playable.
func play_run_start() -> void:
	pass


## The run was paused (true) or resumed (false).
func play_pause(_is_paused: bool) -> void:
	pass


## The run ended without a claim: the player died or the flag was destroyed.
func play_game_over() -> void:
	pass


## The planted flag reached the victory depth; follows play_flag_plant in the same frame.
func play_victory() -> void:
	pass


## The player confirmed the name entry and the score was accepted.
func play_ui_confirm() -> void:
	_play_tone(860.0, 0.05, 0.08)


## A UI button moment. kind is AppUiController.UI_FEEDBACK_HOVER or UI_FEEDBACK_PRESS.
func play_ui(_kind: StringName) -> void:
	pass


# --- Player ---

## The player started a jump; is_air_jump is true when it spent an extra air jump.
func play_jump(_is_air_jump: bool) -> void:
	pass


## The player touched ground after being airborne, or bounced off it. impact_speed is the
## downward speed lost on the floor; airborne_seconds is the time since the last ground
## contact. Running over hex steps also lands, after well under 0.2 s in the air.
func play_land(_impact_speed: float, _airborne_seconds: float) -> void:
	pass


## A terrain collision fast enough to fill the impact hazard meter; impact_speed is the
## velocity change. Knockout and impact death add their own moment in the same frame.
func play_hard_impact(_impact_speed: float) -> void:
	pass


## A terrain impact knocked the player out into a ragdoll.
func play_knockout(_impact_speed: float) -> void:
	pass


## The hook was fired; attach or miss follows in the same frame.
func play_hook_launch() -> void:
	pass


## The hook caught terrain (false) or a moving target such as a barrel (true).
func play_hook_attach(_is_moving_target: bool) -> void:
	pass


## The fired hook found nothing in range.
func play_hook_miss() -> void:
	pass


## The rope let go: by_input is true when the player released it, false when the anchor
## was destroyed or an impact tore it off.
func play_hook_release(_by_input: bool) -> void:
	pass


## The player's body entered (true) or left (false) liquid at this body speed.
func play_splash(_speed: float, _is_entering: bool) -> void:
	pass


## A Sand Worm player started (true) or stopped (false) burrowing through sand.
func play_sand_burrow(_is_burrowing: bool) -> void:
	pass


## A hazard meter keeps filling above the warning level; repeats at a fixed interval while
## it does. cause is a DeathCause value and level is the meter fill from 0 to 1.
func play_hazard_warning(_cause: StringName, _level: float) -> void:
	pass


## The player died for good; cause is a DeathCause value.
func play_death(_cause: StringName) -> void:
	_play_tone(110.0, 0.26, 0.16)


# --- Items and world objects ---

## The player threw a projectile item; item.feedback_key names its family.
func play_throw(_item: ItemDefinition) -> void:
	_play_tone(520.0, 0.06, 0.08)


## The player used an in-place tool such as the pickaxe or shovel and it changed terrain.
func play_tool_use(_item: ItemDefinition) -> void:
	_play_tone(520.0, 0.06, 0.08)


## The player selected another item.
func play_item_select(_item: ItemDefinition) -> void:
	pass


## A thrown item bounced off terrain; impact_speed is its speed before the bounce.
func play_projectile_bounce(_world_position: Vector2, _impact_speed: float, _item: ItemDefinition) -> void:
	pass


## A thrown item without an explosive ended. resolution_kind is &"impact", &"fuse" (timed
## out, such as a flare burning out) or the terrain tag that destroyed it, such as &"lava".
func play_projectile_end(_world_position: Vector2, _item: ItemDefinition, _resolution_kind: StringName) -> void:
	pass


## A fluid bottle broke and released its fluid.
func play_bottle_burst(_world_position: Vector2) -> void:
	pass


## An explosion resolved; radius_world is its blast radius.
func play_explosion(_world_position: Vector2, _radius_world: float, is_large: bool) -> void:
	_play_tone(150.0 if is_large else 210.0, 0.18 if is_large else 0.12, 0.18)


## A blast lit the chain fuse of a barrel, container, or lying bomb that explodes after
## fuse_seconds.
func play_fuse_armed(_world_position: Vector2, _fuse_seconds: float) -> void:
	pass


## An explosion destroyed a world object; object_key is its definition's statistics_key
## (&"item_chest", &"perk_geode", &"explosive_barrel"). play_explosion follows.
func play_object_destroyed(_world_position: Vector2, _object_key: StringName) -> void:
	pass


## A rolling or falling barrel rebounded off terrain; impact_speed is the velocity change.
func play_barrel_bump(_world_position: Vector2, _impact_speed: float) -> void:
	pass


## A thrown excavator landed and started working.
func play_excavator_deploy(_world_position: Vector2) -> void:
	pass


## One excavator drill tick; dug_cell_count is how many cells it wore down (0 to 3).
func play_excavator_drill(_world_position: Vector2, _dug_cell_count: int) -> void:
	pass


## A destroyed container started a directional terrain pulse lasting duration_seconds.
func play_terrain_pulse(_world_position: Vector2, _duration_seconds: float) -> void:
	pass


## The flag left the player's hand (true) or its flight ended (false). A false also
## arrives once when a run is configured.
func play_flag_flight(_in_flight: bool) -> void:
	pass


## The flag landed and claimed its depth.
func play_flag_plant() -> void:
	_play_tone(720.0, 0.12, 0.12)
	_play_tone(940.0, 0.08, 0.08, 0.02)


## Terrain destroyed the flying flag; cause is the terrain tag, such as &"lava" or &"acid".
func play_flag_destroyed(_cause: StringName) -> void:
	pass


## The player touched a reward container and it opened; container_key is its definition's
## statistics_key (&"item_chest" or &"perk_geode").
func play_container_open(_container_key: StringName) -> void:
	pass


## The reward picker appeared.
func play_reward_choices() -> void:
	pass


## The player picked a reward: a perk (true) or an item added to the inventory (false).
func play_reward_claimed(_is_perk: bool) -> void:
	pass


func _play_tone(frequency: float, duration: float, volume: float, delay := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = maxf(0.1, duration + delay + 0.05)
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.001, volume))
	add_child(player)
	player.play()
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
	var frame_count := int(stream.mix_rate * duration)
	for index in range(frame_count):
		var envelope := 1.0 - float(index) / maxf(1.0, frame_count)
		var sample: float = sin(TAU * frequency * float(index) / stream.mix_rate) * envelope
		playback.push_frame(Vector2(sample, sample))
	await get_tree().create_timer(duration + 0.1).timeout
	player.queue_free()
