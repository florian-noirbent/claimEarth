extends GutTest
## Covers the beat between a lost run and its result panel: what stops, what keeps running,
## what is ignored, and that statistics and scores are settled exactly once.


const DeathCauseScript = preload("res://src/player/death_cause.gd")
const SUFFIXES := ["death", "ignored", "flag", "menu", "restart", "zero", "world", "seam", "blast", "remains", "suspend"]


func before_each() -> void:
	for suffix in SUFFIXES:
		for path in [_save_path(suffix), _statistics_path(suffix)]:
			for candidate in [path, "%s.tmp" % path]:
				if FileAccess.file_exists(candidate):
					DirAccess.remove_absolute(candidate)


func test_death_holds_the_result_panel_back_for_the_beat() -> void:
	var app_root := await _started_app("death")
	watch_signals(app_root.statistics_controller)
	var started_msec := Time.get_ticks_msec()

	app_root._on_player_death_requested(DeathCauseScript.COOKED)

	assert_eq(app_root.get_run_state(), RunPhase.OUTCOME_BEAT)
	assert_false(app_root.ui.result_panel.visible, "The panel waits for the beat.")
	assert_false(app_root.ui.modal_dim.visible)
	assert_false(app_root.ui.item_toolbar.visible, "Controls leave at once.")
	assert_false(app_root.ui.pause_button.visible)
	assert_true(app_root.ui.playing_panel.visible, "Readouts stay over the world.")
	var player := app_root.get_player()
	var death_position := player.global_position
	var camera_position := player.camera.global_position
	assert_false(player.is_physics_processing(), "The player no longer simulates.")
	assert_true(player.is_dead())
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.total_deaths(), 1, "The death is recorded at the moment it happens.")
	assert_eq(data.runs_started, 1)
	assert_false(app_root.statistics_controller.is_run_active())
	assert_signal_emit_count(app_root.statistics_controller, "statistics_changed", 1)

	await _until_state(app_root, RunPhase.DEATH)

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)
	# The beat counts frame time, and the first frame it counts began before the death.
	assert_gte(Time.get_ticks_msec() - started_msec, int(app_root.death_beat_seconds * 900.0))
	assert_true(is_instance_valid(player) and player.is_inside_tree(), "The body stays in the scene.")
	assert_true(player.is_visible_in_tree())
	assert_eq(player.global_position, death_position)
	assert_almost_eq(player.camera.global_position, camera_position, Vector2(40.0, 40.0), "Only shake moves the camera.")
	assert_true(app_root.ui.result_panel.visible)
	assert_eq(app_root.ui.result_title.text, "Run Lost")
	assert_string_contains(app_root.ui.result_status.text, "Cooked")
	assert_false(app_root.ui.playing_panel.visible)
	assert_eq(app_root.statistics_controller.statistics().total_deaths(), 1)
	assert_eq(app_root.statistics_controller.statistics().runs_started, 1)
	assert_signal_emit_count(app_root.statistics_controller, "statistics_changed", 1)
	assert_eq(app_root.score_controller.personal_best_depth, -1, "Death never saves a score.")
	assert_false(FileAccess.file_exists(_save_path("death")))


func test_input_pause_and_later_outcomes_are_ignored_during_the_beat() -> void:
	var app_root := await _started_app("ignored")
	var player := app_root.get_player()
	app_root._on_player_death_requested(DeathCauseScript.COOKED)
	var selected := String(app_root.inventory_status_for_test()["selected_name"])

	app_root._on_throw_requested(player.global_position + Vector2(100.0, -50.0))
	app_root._on_item_selected(1)
	app_root._on_item_cycle_requested(1)
	app_root._toggle_pause()
	assert_eq(app_root.get_run_state(), RunPhase.OUTCOME_BEAT, "Pause is ignored during the beat.")
	assert_eq(app_root.active_projectile_count(), 0)
	assert_eq(String(app_root.inventory_status_for_test()["selected_name"]), selected)

	# A blast on the player, a second death, and both flag outcomes all arrive too late.
	var explosion := load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition
	app_root.item_controller.resolve_explosion(explosion, player.global_position)
	app_root._on_player_death_requested(DeathCauseScript.ACID)
	var landing := HexMetrics.center_for_offset(5, 40, app_root.world_presenter.hex_radius)
	app_root.item_controller.resolve_flag_landing(null, landing, null, &"impact")
	app_root.item_controller.resolve_flag_landing(null, landing, null, &"lava")

	assert_eq(app_root.get_run_state(), RunPhase.OUTCOME_BEAT)
	await _until_state(app_root, RunPhase.DEATH)
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.total_deaths(), 1)
	assert_eq(PlayerStatistics.count_in(data.deaths_by_cause, DeathCauseScript.COOKED), 1)
	assert_eq(data.flags_planted, 0)
	assert_eq(PlayerStatistics.count_in(data.flags_lost_by_cause, &"lava"), 0)
	assert_eq(data.runs_started, 1)
	assert_eq(app_root.pending_score_depth(), -1)
	assert_string_contains(app_root.ui.result_status.text, "Cooked")


func test_destroyed_flag_takes_the_same_beat_and_saves_no_score() -> void:
	var app_root := await _started_app("flag")
	var landing := HexMetrics.center_for_offset(5, 40, app_root.world_presenter.hex_radius)

	app_root.item_controller.resolve_flag_landing(null, landing, null, &"lava")

	assert_eq(app_root.get_run_state(), RunPhase.OUTCOME_BEAT)
	assert_false(app_root.get_player().is_physics_processing())
	assert_false(app_root.get_player().is_dead(), "A lost flag is not a death.")
	assert_false(app_root.get_player().presentation.death.has_begun(), "A lost flag leaves the body whole.")
	assert_eq(PlayerStatistics.count_in(app_root.statistics_controller.statistics().flags_lost_by_cause, &"lava"), 1)
	app_root._on_player_death_requested(DeathCauseScript.COOKED)
	var started_msec := Time.get_ticks_msec()

	await _until_state(app_root, RunPhase.DEATH)
	assert_lt(Time.get_ticks_msec() - started_msec, int(app_root.death_beat_seconds * 1000.0), "The flag beat is the shorter one.")
	assert_false(app_root.get_player().is_dead())
	assert_string_contains(app_root.ui.result_status.text, "melted in lava")
	assert_eq(app_root.statistics_controller.statistics().total_deaths(), 0)
	assert_eq(app_root.score_controller.personal_best_depth, -1)
	assert_false(FileAccess.file_exists(_save_path("flag")))


func test_the_world_keeps_running_during_the_beat_and_stops_with_the_panel() -> void:
	var app_root := await _started_app("world")
	assert_true(app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2(0.0, -200.0), true))
	var projectile := _projectile(app_root)
	assert_not_null(projectile)

	app_root._on_player_death_requested(DeathCauseScript.COOKED)

	assert_true(projectile.is_physics_processing(), "Thrown items keep flying under the death effect.")
	assert_true(app_root.gameplay_feedback.is_processing())
	await _until_state(app_root, RunPhase.DEATH)
	if is_instance_valid(projectile):
		assert_false(projectile.is_physics_processing(), "The result panel freezes the session.")


func test_leaving_for_the_menu_during_the_beat_cancels_it() -> void:
	var app_root := await _started_app("menu")
	var player := app_root.get_player()
	app_root._on_player_death_requested(DeathCauseScript.COOKED)
	assert_true(player.presentation.death.is_playing())
	await wait_physics_frames(4)

	app_root.ui.menu_requested.emit()
	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)
	await wait_seconds(app_root.death_beat_seconds + 0.3)

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU, "The cancelled beat never opens the result panel.")
	assert_false(app_root.ui.result_panel.visible)
	assert_false(is_instance_valid(player), "The half-played death sequence left with its session.")
	assert_eq(app_root.active_session_count(), 0)
	assert_eq(app_root.statistics_controller.statistics().runs_started, 1)


func test_restarting_during_the_beat_starts_a_clean_run() -> void:
	var app_root := await _started_app("restart")
	var dead_player := app_root.get_player()
	app_root._on_player_death_requested(DeathCauseScript.COOKED)
	await wait_physics_frames(4)

	app_root.ui.restart_requested.emit()
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	await wait_seconds(app_root.death_beat_seconds + 0.3)

	assert_false(app_root.get_player().is_dead())
	assert_false(is_instance_valid(dead_player), "The remains left with the old session.")
	var rig := app_root.get_player().presentation.rig
	assert_false(app_root.get_player().presentation.death.has_begun(), "The new player is whole.")
	assert_null(rig.part_sprite(0).material)
	assert_eq(rig.z_index, 0)
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING, "The old beat does not end the new run.")
	assert_true(app_root.get_player().is_physics_processing())
	assert_true(app_root.statistics_controller.is_run_active())
	app_root._on_player_death_requested(DeathCauseScript.BOMB)
	assert_eq(app_root.get_run_state(), RunPhase.OUTCOME_BEAT, "The new run can end normally.")
	await _until_state(app_root, RunPhase.DEATH)
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.runs_started, 2)
	assert_eq(data.total_deaths(), 2)


func test_a_zero_beat_opens_the_result_panel_at_once() -> void:
	var app_root := await _started_app("zero")
	app_root.death_beat_seconds = 0.0

	app_root._on_player_death_requested(DeathCauseScript.COOKED)

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)
	assert_true(app_root.ui.result_panel.visible)
	var animator := app_root.get_player().presentation.death
	assert_true(animator.has_begun(), "Without a beat the body still comes apart, behind the panel.")
	assert_eq(animator.detached_part_count(), 16)
	await wait_physics_frames(6)
	assert_true(is_instance_valid(app_root.get_player()))


func test_death_seam_runs_once_with_the_cause_and_beat_and_not_for_a_relentless_drop() -> void:
	var app_root := await _started_app("seam")
	var relentless := load("res://config/perks/relentless.tres") as PerkDefinition
	assert_true(app_root.perk_controller.select_perk(relentless))
	var player := app_root.get_player()

	app_root._on_player_death_requested(DeathCauseScript.COOKED)
	assert_eq(app_root.get_run_state(), RunPhase.FLAG_IN_FLIGHT)
	assert_false(player.is_dead(), "Relentless dropped the flag: the death is not final.")
	await wait_physics_frames(3)
	assert_false(player.presentation.death.has_begun(), "A Relentless drop plays no death sequence.")
	assert_null(player.presentation.rig.part_sprite(0).material)

	app_root.transition_to(RunPhase.GENERATING)
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	var player_two := app_root.get_player()
	watch_signals(player_two)
	app_root._on_player_death_requested(DeathCauseScript.BOMB)
	app_root._on_player_death_requested(DeathCauseScript.ACID)

	assert_true(player_two.is_dead())
	assert_signal_emit_count(player_two, "death_began", 1)
	assert_eq(get_signal_parameters(player_two, "death_began"), [DeathCauseScript.BOMB, app_root.death_beat_seconds])
	var library := player_two.presentation.death.library
	assert_same(player_two.presentation.death.sequence(), library.sequences[DeathCauseScript.BOMB], "The first cause picks the sequence.")


func test_a_bomb_kill_hands_the_blast_center_to_the_death_sequence() -> void:
	var app_root := await _started_app("blast")
	var player := app_root.get_player()
	var explosion := load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition

	app_root.item_controller.resolve_explosion(explosion, player.global_position + Vector2(-20.0, 0.0))

	assert_eq(app_root.get_run_state(), RunPhase.OUTCOME_BEAT)
	assert_true(player.is_dead())
	var animator := player.presentation.death
	assert_same(animator.sequence(), animator.library.sequences[DeathCauseScript.BOMB])
	assert_eq(animator._push, Vector2.RIGHT, "The parts are thrown away from the blast.")
	assert_eq(PlayerStatistics.count_in(app_root.statistics_controller.statistics().deaths_by_cause, DeathCauseScript.BOMB), 1)


func test_the_remains_stay_apart_behind_the_result_panel() -> void:
	var app_root := await _started_app("remains")
	var player := app_root.get_player()

	app_root._on_player_death_requested(DeathCauseScript.IMPACT)
	await _until_state(app_root, RunPhase.DEATH)
	await wait_until(func() -> bool:
		return not player.presentation.death.is_playing()
	, 4.0)

	var animator := player.presentation.death
	assert_false(animator.is_playing(), "The sequence ends on its own behind the panel.")
	assert_eq(animator.detached_part_count(), 16)
	assert_true(animator.simulation().all_asleep())
	var settled := player.presentation.rig.part_sprite(0).global_position
	await wait_physics_frames(10)
	assert_eq(player.presentation.rig.part_sprite(0).global_position, settled, "The player does not come back whole.")
	assert_gt(settled.distance_to(player.presentation.rig.part_sprite(15).global_position), 1.0)


func test_a_suspended_session_holds_the_death_sequence_like_its_effects() -> void:
	var app_root := await _started_app("suspend")
	var player := app_root.get_player()
	var animator := player.presentation.death
	# A death the feedback sink never saw end the run: the session can still be suspended.
	player.begin_death(DeathCauseScript.BOMB, 2.0)
	await wait_physics_frames(3)

	app_root._session.set_active(false)
	assert_true(app_root.gameplay_feedback.is_suspended())
	var held := animator.progress()
	await wait_physics_frames(8)
	assert_eq(animator.progress(), held, "The sequence freezes with the world and its effects.")

	app_root._session.set_active(true)
	await wait_physics_frames(4)
	assert_gt(animator.progress(), held)

	# Once the run has ended the effects play on, and so does the sequence.
	app_root.gameplay_feedback.spawn_death(player.global_position, DeathCauseScript.BOMB)
	app_root._session.set_active(false)
	held = animator.progress()
	await wait_physics_frames(4)
	assert_gt(animator.progress(), held)


func test_shipped_beats_are_two_seconds_for_death_and_shorter_for_a_lost_flag() -> void:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	autofree(app_root)

	assert_eq(app_root.death_beat_seconds, 2.0)
	assert_between(app_root.flag_lost_beat_seconds, 0.6, 1.0)


func _started_app(suffix: String) -> AppRoot:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test(_save_path(suffix))
	app_root.configure_statistics_path_for_test(_statistics_path(suffix))
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	app_root.start_run_for_test(SeedUtils.seed_from_text("outcome-beat-%s" % suffix))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	return app_root


func _until_state(app_root: AppRoot, state: StringName) -> void:
	await wait_until(func() -> bool:
		return app_root.get_run_state() == state
	, app_root.death_beat_seconds + 2.0)


func _projectile(app_root: AppRoot) -> ItemProjectile:
	for child in app_root.item_controller.get_children():
		if child is ItemProjectile:
			return child as ItemProjectile
	return null


func _save_path(suffix: String) -> String:
	return "user://gut_outcome_beat_%s.json" % suffix


func _statistics_path(suffix: String) -> String:
	return "user://gut_outcome_beat_%s_statistics.json" % suffix
