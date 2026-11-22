extends GutTest

const DeathCauseScript = preload("res://src/player/death_cause.gd")

const SUFFIXES := ["run", "throw", "explosion", "death", "flag", "reward", "player"]


## Records the routed moments this test asserts instead of playing them.
class RecordingAudioDirector extends AudioDirector:
	var calls: Array[Array] = []

	func play_run_start() -> void:
		calls.append([&"run_start"])

	func play_pause(is_paused: bool) -> void:
		calls.append([&"pause", is_paused])

	func play_game_over() -> void:
		calls.append([&"game_over"])

	func play_ui(kind: StringName) -> void:
		calls.append([&"ui", kind])

	func play_ui_confirm() -> void:
		calls.append([&"ui_confirm"])

	func play_death(cause: StringName) -> void:
		calls.append([&"death", cause])

	func play_throw(item: ItemDefinition) -> void:
		calls.append([&"throw", item])

	func play_item_select(item: ItemDefinition) -> void:
		calls.append([&"item_select", item])

	func play_explosion(world_position: Vector2, radius_world: float, is_large: bool) -> void:
		calls.append([&"explosion", world_position, radius_world, is_large])

	func play_flag_plant() -> void:
		calls.append([&"flag_plant"])

	func play_flag_destroyed(cause: StringName) -> void:
		calls.append([&"flag_destroyed", cause])

	func play_container_open(container_key: StringName) -> void:
		calls.append([&"container_open", container_key])

	func play_reward_choices() -> void:
		calls.append([&"reward_choices"])

	func play_reward_claimed(is_perk: bool) -> void:
		calls.append([&"reward_claimed", is_perk])

	func play_hard_impact(impact_speed: float) -> void:
		calls.append([&"hard_impact", impact_speed])

	func play_knockout(impact_speed: float) -> void:
		calls.append([&"knockout", impact_speed])

	func named(moment: StringName) -> Array[Array]:
		return calls.filter(func(entry: Array) -> bool: return entry[0] == moment)


## Records the routed visual moments on top of the real effects.
class RecordingGameplayFeedback extends GameplayFeedback:
	var calls: Array[Array] = []

	func request_shake(intensity: float, world_position: Vector2) -> void:
		calls.append([&"shake", intensity, world_position])
		super.request_shake(intensity, world_position)

	func spawn_knockout_stars(world_position: Vector2, duration_seconds: float) -> void:
		calls.append([&"knockout_stars", world_position, duration_seconds])

	func spawn_chest_burst(world_position: Vector2, container_key: StringName) -> void:
		calls.append([&"chest_burst", world_position, container_key])

	func spawn_reward_claimed(world_position: Vector2, is_perk: bool) -> void:
		calls.append([&"reward_claimed", world_position, is_perk])

	func spawn_flag_destroyed(world_position: Vector2, cause: StringName) -> void:
		calls.append([&"flag_destroyed", world_position, cause])

	func named(moment: StringName) -> Array[Array]:
		return calls.filter(func(entry: Array) -> bool: return entry[0] == moment)


func before_each() -> void:
	for suffix in SUFFIXES:
		var path := "user://gut_feedback_flow_%s.json" % suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_run_flow_and_buttons_reach_the_audio_sink() -> void:
	var app_root := await _app("run")
	var audio := app_root.audio_director as RecordingAudioDirector

	app_root.ui.menu_start_button.pressed.emit()
	await _until_playing(app_root)

	assert_eq(audio.named(&"ui"), [[&"ui", AppUiController.UI_FEEDBACK_PRESS]] as Array[Array])
	assert_eq(audio.named(&"run_start").size(), 1)
	app_root.ui.pause_button.mouse_entered.emit()
	assert_eq(audio.named(&"ui").back(), [&"ui", AppUiController.UI_FEEDBACK_HOVER])
	app_root.ui.pause_button.pressed.emit()
	app_root.ui.resume_button.pressed.emit()

	assert_eq(audio.named(&"pause"), [[&"pause", true], [&"pause", false]] as Array[Array])
	assert_eq(audio.named(&"run_start").size(), 1, "Resuming is not a run start")
	assert_eq(audio.named(&"ui").size(), 4)


func test_throw_and_selection_reach_the_audio_sink_with_the_item() -> void:
	var app_root := await _started_app("throw")
	var audio := app_root.audio_director as RecordingAudioDirector
	var definitions := app_root.item_controller._inventory.definitions()

	app_root.select_item_for_test(1)
	assert_true(app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2(80.0, -40.0), true))

	assert_eq(audio.named(&"item_select"), [[&"item_select", definitions[1]]] as Array[Array])
	assert_eq(audio.named(&"throw"), [[&"throw", definitions[1]]] as Array[Array])


func test_explosion_reaches_both_sinks_in_world_units_and_shakes_through_the_seam() -> void:
	var app_root := await _started_app("explosion")
	var audio := app_root.audio_director as RecordingAudioDirector
	var visuals := app_root.gameplay_feedback as RecordingGameplayFeedback
	var definition := load("res://config/items/explosions/large_bomb_explosion.tres") as ExplosionDefinition
	var impact := app_root.get_player().global_position + Vector2(0.0, 400.0)
	var effects_before := visuals.get_child_count()

	app_root.item_controller.resolve_explosion(definition, impact)

	var radius_world := definition.blast_radius * app_root.world_presenter.hex_radius
	assert_eq(audio.named(&"explosion"), [[&"explosion", impact, radius_world, true]] as Array[Array])
	assert_eq(visuals.get_child_count(), effects_before + 1, "The explosion still spawns its ring")
	assert_eq(visuals.named(&"shake"), [[&"shake", 10.0, impact]] as Array[Array])
	assert_almost_eq(app_root.get_player().camera._shake_strength, 10.0, 0.001)


func test_knockout_and_death_reach_both_sinks() -> void:
	var app_root := await _started_app("death")
	var audio := app_root.audio_director as RecordingAudioDirector
	var visuals := app_root.gameplay_feedback as RecordingGameplayFeedback
	var player := app_root.get_player()
	var impact_speed := player.movement_config.medium_impact_speed

	player._handle_terrain_impact(impact_speed)

	assert_eq(audio.named(&"hard_impact"), [[&"hard_impact", impact_speed]] as Array[Array])
	assert_eq(audio.named(&"knockout"), [[&"knockout", impact_speed]] as Array[Array])
	assert_eq(
		visuals.named(&"knockout_stars"),
		[[&"knockout_stars", player.global_position, player.movement_config.ragdoll_seconds]] as Array[Array]
	)

	app_root._on_player_death_requested(DeathCauseScript.COOKED)

	assert_eq(audio.named(&"death"), [[&"death", DeathCauseScript.COOKED]] as Array[Array])
	assert_eq(audio.named(&"game_over").size(), 1)
	assert_eq(visuals.named(&"shake"), [[&"shake", 14.0, player.global_position]] as Array[Array])


func test_flag_outcomes_reach_the_sinks() -> void:
	var app_root := await _started_app("flag")
	var audio := app_root.audio_director as RecordingAudioDirector
	var visuals := app_root.gameplay_feedback as RecordingGameplayFeedback
	var landing := HexMetrics.center_for_offset(5, 20, app_root.world_presenter.hex_radius)

	app_root.item_controller.resolve_flag_landing(null, landing, null, &"lava")

	assert_eq(audio.named(&"flag_destroyed"), [[&"flag_destroyed", &"lava"]] as Array[Array])
	assert_eq(visuals.named(&"flag_destroyed"), [[&"flag_destroyed", landing, &"lava"]] as Array[Array])
	assert_eq(audio.named(&"game_over").size(), 1)
	assert_eq(audio.named(&"flag_plant").size(), 0)

	app_root.transition_to(RunPhase.GENERATING)
	await _until_playing(app_root)
	app_root.item_controller.resolve_flag_landing(null, landing, null, &"impact")
	assert_eq(audio.named(&"flag_plant").size(), 1)
	app_root.ui.player_name_input.text = "Florian"
	app_root.ui.confirm_score_button.pressed.emit()
	assert_eq(audio.named(&"ui_confirm").size(), 1)


func test_reward_container_moments_reach_both_sinks() -> void:
	var app_root := await _started_app("reward")
	var audio := app_root.audio_director as RecordingAudioDirector
	var visuals := app_root.gameplay_feedback as RecordingGameplayFeedback
	var chest: ItemChest
	for child in app_root.item_controller.get_children():
		if child is ItemChest and (child as ItemChest).spawn_data.definition.reward_kind == ItemChestDefinition.RewardKind.ITEMS:
			chest = child as ItemChest
			break
	var chest_position := chest.global_position
	var container_key := chest.spawn_data.definition.statistics_key

	chest.touch_area.body_entered.emit(app_root.get_player())

	assert_eq(audio.named(&"container_open"), [[&"container_open", container_key]] as Array[Array])
	assert_eq(visuals.named(&"chest_burst"), [[&"chest_burst", chest_position, container_key]] as Array[Array])
	assert_eq(audio.named(&"reward_choices").size(), 1)

	(app_root.ui.reward_picker_cards.get_child(0) as RewardPickerCard).pressed.emit()

	assert_eq(audio.named(&"reward_claimed"), [[&"reward_claimed", false]] as Array[Array])
	assert_eq(visuals.named(&"reward_claimed"), [[&"reward_claimed", chest_position, false]] as Array[Array])
	assert_eq(audio.named(&"ui").back(), [&"ui", AppUiController.UI_FEEDBACK_PRESS], "Reward cards report presses")


func test_session_relays_every_player_feedback_fact() -> void:
	var app_root := await _started_app("player")
	var session := app_root._session
	var player := app_root.get_player()
	watch_signals(session)

	player.jumped.emit(Vector2.ONE, true)
	player.landed.emit(Vector2.ONE, 2.0, 0.5)
	player.hook_launched.emit(Vector2.ONE, Vector2.ZERO)
	player.hook_attached.emit(Vector2.ONE, true)
	player.hook_missed.emit(Vector2.ONE, Vector2.ZERO)
	player.hook_released.emit(Vector2.ONE, false)
	player.liquid_entered.emit(Vector2.ONE, Color.BLUE, 3.0)
	player.liquid_exited.emit(Vector2.ONE, Color.BLUE, 3.0)
	player.sand_burrow_changed.emit(Vector2.ONE, true)
	player.hazard_warning.emit(DeathCauseScript.ACID, 0.7, Color.GREEN)

	assert_signal_emitted_with_parameters(session, "player_jumped", [Vector2.ONE, true])
	assert_signal_emitted_with_parameters(session, "player_landed", [Vector2.ONE, 2.0, 0.5])
	assert_signal_emitted_with_parameters(session, "player_hook_launched", [Vector2.ONE, Vector2.ZERO])
	assert_signal_emitted_with_parameters(session, "player_hook_attached", [Vector2.ONE, true])
	assert_signal_emitted_with_parameters(session, "player_hook_missed", [Vector2.ONE, Vector2.ZERO])
	assert_signal_emitted_with_parameters(session, "player_hook_released", [Vector2.ONE, false])
	assert_signal_emitted_with_parameters(session, "player_liquid_entered", [Vector2.ONE, Color.BLUE, 3.0])
	assert_signal_emitted_with_parameters(session, "player_liquid_exited", [Vector2.ONE, Color.BLUE, 3.0])
	assert_signal_emitted_with_parameters(session, "player_sand_burrow_changed", [Vector2.ONE, true])
	assert_signal_emitted_with_parameters(session, "player_hazard_warning", [DeathCauseScript.ACID, 0.7, Color.GREEN])


func _app(suffix: String) -> AppRoot:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.get_node("AudioDirector").set_script(RecordingAudioDirector)
	app_root.configure_save_path_for_test("user://gut_feedback_flow_%s.json" % suffix)
	app_root.set_test_mode(true)
	app_root.child_entered_tree.connect(func(child: Node) -> void:
		if child is RunSession:
			child.get_node("GameplayFeedback").set_script(RecordingGameplayFeedback)
	)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	return app_root


func _started_app(suffix: String) -> AppRoot:
	var app_root := await _app(suffix)
	app_root.start_run_for_test(SeedUtils.seed_from_text("feedback-flow-%s" % suffix))
	await _until_playing(app_root)
	return app_root


func _until_playing(app_root: AppRoot) -> void:
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
