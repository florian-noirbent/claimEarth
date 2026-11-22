extends GutTest


const DeathCauseScript = preload("res://src/player/death_cause.gd")
const DEFAULT_STATISTICS_PATH := "user://claim_earth_statistics.json"
const SUFFIXES := ["death", "abandon", "items", "flag", "victory", "flag_lost", "restart", "page", "relentless"]


func before_each() -> void:
	for suffix in SUFFIXES:
		for path in [_statistics_path(suffix), _save_path(suffix), _save_path("no_path")]:
			for candidate in [path, "%s.tmp" % path]:
				if FileAccess.file_exists(candidate):
					DirAccess.remove_absolute(candidate)


func test_deep_run_ending_in_death_counts_a_game_and_persists() -> void:
	var app_root := await _start_app("death")
	_hold_player_at_row(app_root, 60)
	await wait_process_frames(2)
	app_root._on_player_death_requested(DeathCauseScript.COOKED)

	# Statistics settle at the moment of death, before the beat ends.
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.runs_started, 1)
	assert_eq(data.games_played, 1)
	assert_eq(PlayerStatistics.count_in(data.deaths_by_cause, DeathCauseScript.COOKED), 1)
	assert_eq(data.total_deaths(), 1)
	assert_eq(data.max_depth_reached, 60)
	assert_eq(data.total_depth_traveled, 60)
	assert_gt(data.total_play_seconds, 0.0)
	assert_true(FileAccess.file_exists(_statistics_path("death")))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.DEATH
	, 4.0)
	assert_eq(app_root.get_run_state(), RunPhase.DEATH)
	assert_eq(app_root.statistics_controller.statistics().runs_started, 1)
	assert_eq(app_root.statistics_controller.statistics().total_deaths(), 1)

	var reloaded := _instantiate_app("death")
	add_child_autofree(reloaded)
	await wait_process_frames(1)
	var reloaded_data := reloaded.statistics_controller.statistics()
	assert_eq(reloaded_data.games_played, 1)
	assert_eq(reloaded_data.max_depth_reached, 60)
	assert_eq(PlayerStatistics.count_in(reloaded_data.deaths_by_cause, DeathCauseScript.COOKED), 1)


func test_shallow_run_abandoned_from_the_menu_is_a_run_but_not_a_game() -> void:
	var app_root := await _start_app("abandon")
	_hold_player_at_row(app_root, 5)
	await wait_process_frames(2)
	app_root.ui.pause_button.pressed.emit()
	app_root.ui.pause_menu_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.MAIN_MENU)
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.runs_started, 1)
	assert_eq(data.games_played, 0)
	assert_eq(data.max_depth_reached, 5)
	assert_eq(data.total_deaths(), 0)
	assert_eq(data.flags_planted, 0)
	assert_true(FileAccess.file_exists(_statistics_path("abandon")))


func test_item_use_and_container_claims_are_counted() -> void:
	var app_root := await _start_app("items")
	var thrown := app_root.item_controller._inventory.definitions()[0]
	assert_true(app_root.throw_selected_item_for_test(app_root.get_player().global_position + Vector2.UP * 120.0, true))
	assert_eq(PlayerStatistics.count_in(app_root.statistics_controller.statistics().item_uses, thrown.stable_id), 1)

	var chest := _container(app_root, &"item_chest")
	chest.touch_area.body_entered.emit(app_root.get_player())
	assert_eq(app_root.get_run_state(), RunPhase.REWARD_PICKER)
	var item_card := app_root.ui.reward_picker_cards.get_child(0) as RewardPickerCard
	var picked_name := item_card.title_label.text
	item_card.pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)

	var geode := _container(app_root, &"perk_geode")
	geode.touch_area.body_entered.emit(app_root.get_player())
	assert_eq(app_root.get_run_state(), RunPhase.REWARD_PICKER)
	var perk_card_count := app_root.ui.reward_picker_cards.get_child_count()
	(app_root.ui.reward_picker_cards.get_child(0) as RewardPickerCard).pressed.emit()

	var data := app_root.statistics_controller.statistics()
	assert_eq(PlayerStatistics.count_in(data.containers_opened, &"item_chest"), 1)
	assert_eq(PlayerStatistics.count_in(data.containers_opened, &"perk_geode"), 1)
	assert_eq(PlayerStatistics._sum(data.item_offers), 2)
	assert_eq(PlayerStatistics._sum(data.item_picks), 1)
	var picked := app_root.item_controller._inventory.definitions().filter(func(definition: ItemDefinition) -> bool:
		return definition.display_name == picked_name
	)
	assert_eq(picked.size(), 1)
	assert_eq(PlayerStatistics.count_in(data.item_picks, (picked[0] as ItemDefinition).stable_id), 1)
	assert_eq(PlayerStatistics._sum(data.perk_offers), perk_card_count)
	assert_eq(PlayerStatistics._sum(data.perk_picks), 1)
	var selected_perk := app_root.perk_controller.selected_perks()[0]
	assert_eq(PlayerStatistics.count_in(data.perk_picks, selected_perk.stable_id), 1)
	assert_eq(data.runs_started, 0, "Run totals fold in only when the run ends.")
	assert_false(FileAccess.file_exists(_statistics_path("items")), "Events never write before the run ends.")


func test_planted_flag_counts_before_name_entry_and_score_waits_for_confirmation() -> void:
	var app_root := await _start_app("flag")
	_land_flag(app_root, 25, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.NAME_ENTRY)
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.flags_planted, 1)
	assert_eq(data.best_flag_depth, 25)
	assert_eq(data.victories, 0)
	assert_eq(data.runs_started, 1)
	assert_true(FileAccess.file_exists(_statistics_path("flag")))
	assert_eq(app_root.score_controller.personal_best_depth, -1, "The score waits for a confirmed name.")
	assert_false(FileAccess.file_exists(_save_path("flag")))

	app_root.ui.player_name_input.text = "Florian"
	app_root.ui.confirm_score_button.pressed.emit()

	assert_eq(app_root.get_run_state(), RunPhase.RESULT)
	assert_eq(app_root.score_controller.personal_best_depth, 25)
	assert_eq(app_root.ui.result_title.text, "Flag Planted")
	assert_false(app_root.ui.result_victory_label.visible)
	assert_eq(app_root.statistics_controller.statistics().runs_started, 1)
	assert_eq(app_root.statistics_controller.statistics().flags_planted, 1)


func test_flag_planted_in_the_lava_core_is_a_victory() -> void:
	var app_root := await _start_app("victory")
	var core_row := app_root.current_world().dimensions.depth - 1
	_land_flag(app_root, core_row, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.NAME_ENTRY)
	assert_eq(app_root.statistics_controller.statistics().victories, 1)
	app_root.ui.confirm_score_button.pressed.emit()
	assert_eq(app_root.get_run_state(), RunPhase.RESULT)
	assert_eq(app_root.ui.result_title.text, "Victory!")
	assert_true(app_root.ui.result_victory_label.visible)
	assert_eq(app_root.ui.result_victory_label.text, "The flag stands in Earth's core.")


func test_destroyed_flag_records_a_flag_loss_without_a_planted_flag() -> void:
	var app_root := await _start_app("flag_lost")
	_land_flag(app_root, 40, &"lava")
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.DEATH
	, 4.0)

	assert_eq(app_root.get_run_state(), RunPhase.DEATH)
	var data := app_root.statistics_controller.statistics()
	assert_eq(PlayerStatistics.count_in(data.flags_lost_by_cause, &"lava"), 1)
	assert_eq(data.flags_planted, 0)
	assert_eq(data.total_deaths(), 0)
	assert_eq(data.runs_started, 1)

	app_root._on_player_death_requested(DeathCauseScript.ACID)
	assert_eq(app_root.statistics_controller.statistics().total_deaths(), 0, "Ignored late outcomes are not recorded.")


func test_restart_from_pause_ends_the_previous_run_exactly_once() -> void:
	var app_root := await _start_app("restart")
	_hold_player_at_row(app_root, 45)
	await wait_process_frames(2)
	watch_signals(app_root.statistics_controller)

	app_root.ui.pause_button.pressed.emit()
	app_root.ui.pause_restart_button.pressed.emit()
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)

	assert_signal_emit_count(app_root.statistics_controller, "statistics_changed", 1)
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.runs_started, 1)
	assert_eq(data.games_played, 1)
	assert_eq(data.max_depth_reached, 45)
	assert_true(app_root.statistics_controller.is_run_active())

	app_root._on_player_death_requested(DeathCauseScript.BOMB)
	app_root.ui.restart_button.pressed.emit()
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 2.0)
	assert_signal_emit_count(app_root.statistics_controller, "statistics_changed", 2)
	assert_eq(app_root.statistics_controller.statistics().runs_started, 2)
	assert_eq(app_root.statistics_controller.statistics().total_deaths(), 1)


func test_menu_statistics_page_opens_populated_and_returns_to_a_working_menu() -> void:
	var app_root := _instantiate_app("page")
	add_child_autofree(app_root)
	await wait_process_frames(1)
	var ui := app_root.ui

	ui.menu_statistics_button.pressed.emit()
	await wait_process_frames(1)

	assert_true(ui.statistics_page.is_visible_in_tree())
	assert_false(ui.menu_panel.visible)
	assert_eq(ui.statistics_page.section_count(), 5)
	assert_eq(ui.statistics_page.entry_count(2), app_root.item_catalog.definitions.size())
	assert_eq(ui.statistics_page.entry_count(3), app_root.perk_catalog.definitions.size())
	assert_true(ui.statistics_page.empty_hint_label.visible)

	ui.statistics_page.back_button.pressed.emit()
	assert_false(ui.statistics_page.visible)
	assert_true(ui.menu_panel.visible)

	ui.menu_start_button.pressed.emit()
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 2.0)
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	app_root.transition_to(RunPhase.MAIN_MENU)
	ui.menu_statistics_button.pressed.emit()
	assert_false(ui.statistics_page.empty_hint_label.visible, "One recorded run removes the empty hint.")


func test_test_mode_without_a_statistics_path_never_writes_the_player_file() -> void:
	var existed_before := FileAccess.file_exists(DEFAULT_STATISTICS_PATH)
	var modified_before := FileAccess.get_modified_time(DEFAULT_STATISTICS_PATH) if existed_before else 0
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test(_save_path("no_path"))
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	app_root.start_run_for_test(SeedUtils.seed_from_text("statistics-flow-no-path"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING
	, 2.0)
	app_root._on_player_death_requested(DeathCauseScript.COOKED)
	app_root.transition_to(RunPhase.MAIN_MENU)

	assert_eq(app_root.statistics_controller.statistics().runs_started, 1, "Statistics still count in memory.")
	assert_eq(FileAccess.file_exists(DEFAULT_STATISTICS_PATH), existed_before)
	if existed_before:
		assert_eq(FileAccess.get_modified_time(DEFAULT_STATISTICS_PATH), modified_before)


func test_relentless_death_then_planted_flag_records_both() -> void:
	var app_root := await _start_app("relentless")
	var relentless := load("res://config/perks/relentless.tres") as PerkDefinition
	assert_true(app_root.perk_controller.select_perk(relentless))

	app_root._on_player_death_requested(DeathCauseScript.COOKED)
	assert_eq(app_root.get_run_state(), RunPhase.FLAG_IN_FLIGHT, "Relentless drops the flag and the run continues.")
	app_root._on_player_death_requested(DeathCauseScript.ACID)
	_land_flag(app_root, 50, &"impact")

	assert_eq(app_root.get_run_state(), RunPhase.NAME_ENTRY)
	var data := app_root.statistics_controller.statistics()
	assert_eq(data.deaths_by_cause, {"cooked": 1})
	assert_eq(data.flags_planted, 1)
	assert_eq(data.best_flag_depth, 50)
	assert_eq(data.runs_started, 1)
	assert_eq(data.best_flag_streak, 1)


func _start_app(suffix: String) -> AppRoot:
	var app_root := _instantiate_app(suffix)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	app_root.start_run_for_test(SeedUtils.seed_from_text("statistics-flow-%s" % suffix))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	return app_root


func _instantiate_app(suffix: String) -> AppRoot:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test(_save_path(suffix))
	app_root.configure_statistics_path_for_test(_statistics_path(suffix))
	app_root.set_test_mode(true)
	return app_root


## Freezes player physics so the recorded depth is exactly the requested row.
func _hold_player_at_row(app_root: AppRoot, row: int) -> void:
	var player := app_root.get_player()
	player.set_physics_process(false)
	var column := HexMetrics.offset_for_world(player.global_position, app_root.world_presenter.hex_radius).x
	player.global_position = HexMetrics.center_for_offset(column, row, app_root.world_presenter.hex_radius)


func _land_flag(app_root: AppRoot, row: int, resolution_kind: StringName) -> void:
	var landing := HexMetrics.center_for_offset(5, row, app_root.world_presenter.hex_radius)
	app_root.item_controller.resolve_flag_landing(null, landing, null, resolution_kind)


func _container(app_root: AppRoot, statistics_key: StringName) -> ItemChest:
	for child in app_root.item_controller.get_children():
		var chest := child as ItemChest
		if chest != null and chest.spawn_data.definition.statistics_key == statistics_key:
			return chest
	return null


func _statistics_path(suffix: String) -> String:
	return "user://gut_statistics_flow_%s.json" % suffix


func _save_path(suffix: String) -> String:
	return "user://gut_statistics_flow_save_%s.json" % suffix
