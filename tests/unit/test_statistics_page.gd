extends GutTest


const PAGE_SCENE_PATH := "res://scenes/ui/statistics_page.tscn"
const PRESENTATION_PATH := "res://config/statistics/statistics_presentation.tres"


func test_show_statistics_builds_each_layout_with_entry_state() -> void:
	var page := await _create_page()
	page.show_statistics(_sample_view())

	assert_eq(page.section_count(), 3)
	assert_eq(page.entry_count(0), 4)
	assert_eq(page.entry_count(1), 3)
	assert_eq(page.entry_count(2), 2)
	assert_eq(page.entry_count(7), 0)

	var tiles := page.section_at(0)
	assert_eq(tiles.title_label.text, "Overview")
	assert_true(tiles.tiles.visible)
	assert_false(tiles.icon_grid.visible)
	assert_false(tiles.bars.visible)
	assert_false(tiles.icon_rect.visible)
	var tile := tiles.entry_control(0) as StatisticsStatTile
	assert_not_null(tile)
	assert_eq(tile.value_label.text, "42")
	assert_eq(tile.caption_label.text, "Games played")
	assert_eq(tile.tooltip_text, "Runs started\nacross all sessions")
	assert_eq(tile.focus_mode, Control.FOCUS_ALL)
	assert_ne(tile.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(tile.secondary_label.visible)
	var record_tile := tiles.entry_control(1) as StatisticsStatTile
	assert_true(record_tile.is_highlighted())
	assert_true(record_tile.secondary_label.visible)
	assert_eq(record_tile.secondary_label.text, "record")
	assert_eq(record_tile.value_label.get_theme_color(&"font_color"), StatisticsEntryControl.HIGHLIGHT_COLOR)
	assert_eq(record_tile.get_theme_stylebox(&"panel").border_color, Color(0.96, 0.75, 0.19, 1.0))
	var dimmed_tile := tiles.entry_control(2) as StatisticsStatTile
	assert_true(dimmed_tile.is_dimmed())
	assert_lt(dimmed_tile.modulate.a, 1.0)
	assert_eq(tile.modulate, Color.WHITE)

	var grid := page.section_at(1)
	assert_true(grid.icon_grid.visible)
	assert_false(grid.tiles.visible)
	assert_true(grid.icon_rect.visible)
	assert_eq(grid.subtitle_label.text, "3 kinds")
	var cell := grid.entry_control(0) as StatisticsIconCell
	assert_not_null(cell)
	assert_eq(cell.value_label.text, "17")
	assert_eq(cell.secondary_label.text, "picked 5")
	assert_eq(cell.tooltip_text, "Small Bomb\nThrown 17 times")
	assert_not_null(cell.icon_rect.texture)
	var unseen_cell := grid.entry_control(2) as StatisticsIconCell
	assert_true(unseen_cell.is_dimmed())
	assert_eq(unseen_cell.tooltip_text, "Mystery", "Empty tooltips fall back to the label.")

	var bars := page.section_at(2)
	assert_true(bars.bars.visible)
	var top_row := bars.entry_control(0) as StatisticsBarRow
	assert_not_null(top_row)
	assert_true(top_row.bar.visible)
	assert_almost_eq(top_row.bar.value, 0.6, 0.001)
	assert_eq(top_row.value_label.text, "12")
	assert_eq(top_row.secondary_label.text, "60%")
	assert_true(top_row.is_highlighted())
	var plain_row := bars.entry_control(1) as StatisticsBarRow
	assert_false(plain_row.bar.visible, "A negative fraction hides the bar.")


func test_second_show_replaces_sections_and_empty_hint_toggles() -> void:
	var page := await _create_page()
	page.show_statistics(_sample_view())
	assert_false(page.empty_hint_label.visible)

	var empty_view := StatisticsViewData.new([], "No runs recorded yet. Start a descent!")
	page.show_statistics(empty_view)
	assert_eq(page.section_count(), 0)
	assert_true(page.empty_hint_label.visible)
	assert_eq(page.empty_hint_label.text, "No runs recorded yet. Start a descent!")

	page.show_statistics(_sample_view())
	page.show_statistics(_sample_view())
	assert_eq(page.section_count(), 3)
	assert_eq(page.entry_count(0), 4)
	assert_false(page.empty_hint_label.visible)


func test_page_fits_viewport_and_back_button_emits_and_takes_focus() -> void:
	var page := await _create_page()
	page.show_statistics(_sample_view())
	await wait_process_frames(2)

	assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(page.get_global_rect()))
	assert_true(page.get_global_rect().encloses(page.back_button.get_global_rect()))
	assert_true(page.scroll.follow_focus)
	assert_eq(page.scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	page.focus_default()
	assert_true(page.back_button.has_focus())

	watch_signals(page)
	page.back_button.pressed.emit()
	assert_signal_emitted(page, "back_requested")


func test_entry_focus_changes_the_panel_style() -> void:
	var page := await _create_page()
	page.show_statistics(_sample_view())
	await wait_process_frames(1)
	var tile := page.section_at(0).entry_control(0)
	var unfocused_border := (tile.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color
	tile.grab_focus()
	var focused_border := (tile.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color
	assert_ne(focused_border, unfocused_border)


func test_shipped_presentation_config_is_complete() -> void:
	var config := load(PRESENTATION_PATH) as StatisticsPresentationConfig
	assert_not_null(config)
	assert_eq(config.validate(), PackedStringArray())
	assert_eq(config.death_causes.size(), 7)
	for key in [&"cooked", &"suffocation", &"acid", &"poison", &"bomb", &"impact", &"bounds"]:
		var presentation := config.presentation_for(config.death_causes, key)
		assert_not_null(presentation, "Missing death cause %s" % key)
		if presentation != null:
			assert_not_null(presentation.icon)
			assert_false(presentation.display_name.is_empty())
			assert_false(presentation.description.is_empty())
	assert_eq(config.flag_loss_causes.size(), 2)
	assert_not_null(config.presentation_for(config.flag_loss_causes, &"lava"))
	assert_not_null(config.presentation_for(config.flag_loss_causes, &"acid"))
	assert_eq(config.containers.size(), 2)
	assert_not_null(config.presentation_for(config.containers, &"item_chest"))
	assert_not_null(config.presentation_for(config.containers, &"perk_geode"))
	assert_null(config.presentation_for(config.death_causes, &"missing"))


func test_presentation_config_validation_reports_missing_icons_and_duplicates() -> void:
	var config := StatisticsPresentationConfig.new()
	var duplicate := StatisticKeyPresentation.new()
	duplicate.key = &"cooked"
	duplicate.display_name = "Cooked"
	config.death_causes = [duplicate, duplicate]
	var errors := config.validate()
	assert_true(errors.has("statistics presentation requires unknown_icon"))
	assert_true(errors.has("death_causes contains duplicate key 'cooked'"))
	assert_true(errors.has("death_causes: statistic presentation 'cooked' requires an icon"))


func _create_page() -> StatisticsPage:
	var page := (load(PAGE_SCENE_PATH) as PackedScene).instantiate() as StatisticsPage
	add_child_autofree(page)
	page.position = Vector2(100, 40)
	await wait_process_frames(1)
	return page


func _sample_view() -> StatisticsViewData:
	var bomb := load("res://assets/objects/small_bomb.svg") as Texture2D
	var flag := load("res://assets/objects/flag.svg") as Texture2D
	var tiles: Array[StatisticsEntryViewData] = [
		StatisticsEntryViewData.new(flag, "Games played", "42", "", "Runs started\nacross all sessions"),
		StatisticsEntryViewData.new(flag, "Deepest depth", "812", "record", "", -1.0, false, true),
		StatisticsEntryViewData.new(flag, "Victories", "0", "", "", -1.0, true),
		StatisticsEntryViewData.new(flag, "Time played", "3h 12m"),
	]
	var cells: Array[StatisticsEntryViewData] = [
		StatisticsEntryViewData.new(bomb, "Small Bomb", "17", "picked 5", "Small Bomb\nThrown 17 times"),
		StatisticsEntryViewData.new(bomb, "Large Bomb", "4"),
		StatisticsEntryViewData.new(bomb, "Mystery", "0", "", "", -1.0, true),
	]
	var rows: Array[StatisticsEntryViewData] = [
		StatisticsEntryViewData.new(bomb, "Blown up", "12", "60%", "Caught in an explosion.", 0.6, false, true),
		StatisticsEntryViewData.new(bomb, "Left the map", "8", "", "", -1.0),
	]
	var sections: Array[StatisticsSectionViewData] = [
		StatisticsSectionViewData.new("Overview", StatisticsSectionViewData.Layout.TILES, tiles),
		StatisticsSectionViewData.new("Items", StatisticsSectionViewData.Layout.ICON_GRID, cells, "3 kinds", bomb),
		StatisticsSectionViewData.new("Deaths", StatisticsSectionViewData.Layout.BARS, rows, "20 total"),
	]
	return StatisticsViewData.new(sections)
