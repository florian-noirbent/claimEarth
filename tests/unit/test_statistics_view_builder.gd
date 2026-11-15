extends GutTest


const Layout := StatisticsSectionViewData.Layout

var _item_catalog: ItemCatalog
var _perk_catalog: PerkCatalog
var _presentation: StatisticsPresentationConfig
var _rules: StatisticsRules


func before_all() -> void:
	_item_catalog = load("res://config/items/catalog.tres") as ItemCatalog
	_perk_catalog = load("res://config/perks/catalog.tres") as PerkCatalog
	_presentation = load("res://config/statistics/statistics_presentation.tres") as StatisticsPresentationConfig
	_rules = load("res://config/statistics/statistics_rules.tres") as StatisticsRules


func test_shipped_presentation_resource_is_valid() -> void:
	assert_eq(_presentation.validate(), PackedStringArray())
	assert_eq(_rules.validate(), PackedStringArray())


func test_sections_follow_the_page_order_and_layouts() -> void:
	var view := _build(PlayerStatistics.new())

	var titles := PackedStringArray()
	var layouts := []
	for section in view.sections:
		titles.append(section.title)
		layouts.append(section.layout)
		assert_not_null(section.icon, section.title)
	assert_eq(titles, PackedStringArray(["Lifetime", "Loot & flags", "Items", "Perks", "Causes of death"]))
	assert_eq(layouts, [Layout.TILES, Layout.TILES, Layout.ICON_GRID, Layout.ICON_GRID, Layout.BARS])


func test_entry_counts_follow_catalogs_and_presentation_lists() -> void:
	var view := _build(PlayerStatistics.new())

	assert_eq(view.sections[0].entries.size(), 8, "Lifetime fills two rows of four tiles.")
	assert_eq(view.sections[1].entries.size(), _presentation.containers.size() + _presentation.destroyed_objects.size() + _presentation.flag_loss_causes.size())
	assert_eq(view.sections[2].entries.size(), 9)
	assert_eq(view.sections[2].entries.size(), _item_catalog.definitions.size())
	assert_eq(view.sections[3].entries.size(), 15)
	assert_eq(view.sections[3].entries.size(), _perk_catalog.definitions.size())
	assert_eq(view.sections[4].entries.size(), _presentation.death_causes.size())


func test_empty_statistics_show_the_hint_and_dim_every_entry() -> void:
	var view := _build(PlayerStatistics.new())

	assert_false(view.empty_hint.is_empty())
	for section in view.sections:
		for entry in section.entries:
			assert_true(entry.dimmed, "%s / %s" % [section.title, entry.label])
			assert_false(entry.highlighted, "%s / %s" % [section.title, entry.label])
	for entry in view.sections[4].entries:
		assert_eq(entry.fraction, 0.0)
		assert_eq(entry.secondary_text, "0%")
	assert_eq(view.sections[4].subtitle, "0 deaths")
	assert_eq(view.sections[3].subtitle, "0 of 15 discovered")
	assert_eq(view.sections[2].subtitle, "0 used · 0 of 9 tried")


func test_hint_disappears_after_the_first_run() -> void:
	var data := PlayerStatistics.new()
	data.runs_started = 1
	assert_eq(_build(data).empty_hint, "")


func test_lifetime_tiles_format_totals() -> void:
	var data := PlayerStatistics.new()
	data.runs_started = 140
	data.games_played = 128
	data.flags_planted = 35
	data.victories = 3
	data.best_flag_streak = 7
	data.current_flag_streak = 2
	data.total_play_seconds = 3.0 * 3600.0 + 12.0 * 60.0 + 9.0
	data.longest_run_seconds = 25.0 * 60.0
	data.fastest_victory_seconds = 14.0 * 60.0 + 5.0
	data.max_depth_reached = 1284
	data.best_flag_depth = 1200
	data.total_depth_traveled = 58210
	data.deaths_by_cause = {"cooked": 80, "acid": 7}

	var tiles := _build(data).sections[0].entries
	var labels := PackedStringArray()
	for tile in tiles:
		labels.append(tile.label)
	assert_eq(labels, PackedStringArray(["Games played", "Flags planted", "Victories", "Best flag streak", "Time played", "Deepest depth", "Total depth traveled", "Deaths"]))
	assert_eq(tiles[0].value_text, "128")
	assert_string_contains(tiles[0].tooltip, "depth 30")
	assert_string_contains(tiles[0].tooltip, "Runs started: 140")
	assert_eq(tiles[1].value_text, "35")
	assert_eq(tiles[1].secondary_text, "25% of runs")
	assert_eq(tiles[2].value_text, "3")
	assert_true(tiles[2].highlighted)
	assert_string_contains(tiles[2].tooltip, "Relentless")
	assert_eq(tiles[3].secondary_text, "current 2")
	assert_eq(tiles[4].value_text, "3h 12m")
	assert_string_contains(tiles[4].tooltip, "Longest run: 25m 00s")
	assert_string_contains(tiles[4].tooltip, "Fastest victory: 14m 05s")
	assert_eq(tiles[5].value_text, "1 284")
	assert_eq(tiles[5].secondary_text, "best flag 1 200")
	assert_eq(tiles[6].value_text, "58 210")
	assert_eq(tiles[7].value_text, "87")
	for tile in tiles:
		assert_false(tile.dimmed, tile.label)


func test_victory_tile_is_dimmed_and_plain_without_victories() -> void:
	var data := PlayerStatistics.new()
	data.runs_started = 3
	data.games_played = 3
	var tiles := _build(data).sections[0].entries
	assert_true(tiles[2].dimmed)
	assert_false(tiles[2].highlighted)
	assert_false(tiles[0].dimmed)
	assert_eq(tiles[1].secondary_text, "0% of runs")
	assert_false(tiles[4].tooltip.contains("Fastest victory"))


func test_format_helpers() -> void:
	assert_eq(StatisticsViewBuilder.format_duration(0.0), "0s")
	assert_eq(StatisticsViewBuilder.format_duration(-5.0), "0s")
	assert_eq(StatisticsViewBuilder.format_duration(45.9), "45s")
	assert_eq(StatisticsViewBuilder.format_duration(60.0), "1m 00s")
	assert_eq(StatisticsViewBuilder.format_duration(12.0 * 60.0 + 5.0), "12m 05s")
	assert_eq(StatisticsViewBuilder.format_duration(3600.0), "1h 00m")
	assert_eq(StatisticsViewBuilder.format_duration(14.0 * 3600.0 + 32.0 * 60.0 + 59.0), "14h 32m")
	assert_eq(StatisticsViewBuilder.format_count(0), "0")
	assert_eq(StatisticsViewBuilder.format_count(999), "999")
	assert_eq(StatisticsViewBuilder.format_count(1000), "1 000")
	assert_eq(StatisticsViewBuilder.format_count(58210), "58 210")
	assert_eq(StatisticsViewBuilder.format_count(1234567), "1 234 567")
	assert_eq(StatisticsViewBuilder.format_count(-4200), "-4 200")
	assert_eq(StatisticsViewBuilder.format_percent(0, 0), "0%")
	assert_eq(StatisticsViewBuilder.format_percent(5, 0), "0%")
	assert_eq(StatisticsViewBuilder.format_percent(1, 3), "33%")
	assert_eq(StatisticsViewBuilder.format_percent(2, 3), "67%")
	assert_eq(StatisticsViewBuilder.format_percent(3, 3), "100%")


func test_item_cells_follow_catalog_order_with_uses_picks_and_highlight() -> void:
	var first := _item_catalog.definitions[0] as ItemDefinition
	var second := _item_catalog.definitions[1] as ItemDefinition
	var third := _item_catalog.definitions[2] as ItemDefinition
	var data := PlayerStatistics.new()
	data.item_uses = {str(first.stable_id): 1520, str(second.stable_id): 1520, str(third.stable_id): 3}
	data.item_offers = {str(third.stable_id): 8}
	data.item_picks = {str(third.stable_id): 5}

	var section := _build(data).sections[2]
	for index in section.entries.size():
		var definition := _item_catalog.definitions[index] as ItemDefinition
		assert_eq(section.entries[index].label, definition.display_name)
		assert_eq(section.entries[index].icon, definition.icon)
	assert_eq(section.entries[0].value_text, "1 520")
	assert_true(section.entries[0].highlighted, "The first most-used item gets the accent.")
	assert_false(section.entries[1].highlighted, "Ties keep a single accent.")
	assert_eq(section.entries[0].secondary_text, "")
	assert_eq(section.entries[2].secondary_text, "picked 5")
	assert_string_contains(section.entries[2].tooltip, third.display_name)
	assert_string_contains(section.entries[2].tooltip, "Used 3")
	assert_string_contains(section.entries[2].tooltip, "Picked from chests 5 of 8 offers (63%)")
	assert_false(section.entries[2].dimmed)
	assert_true(section.entries[3].dimmed)
	assert_eq(section.subtitle, "3 043 used · 3 of 9 tried")


func test_item_picked_but_never_used_is_not_dimmed() -> void:
	var item := _item_catalog.definitions[4] as ItemDefinition
	var data := PlayerStatistics.new()
	data.item_picks = {str(item.stable_id): 1}
	data.item_offers = {str(item.stable_id): 1}
	var entry := _build(data).sections[2].entries[4]
	assert_false(entry.dimmed)
	assert_false(entry.highlighted, "Highlight needs at least one use.")


func test_perk_cells_show_picks_offers_and_discovery() -> void:
	var first := _perk_catalog.definitions[0]
	var fourth := _perk_catalog.definitions[3]
	var data := PlayerStatistics.new()
	data.perk_offers = {str(first.stable_id): 10, str(fourth.stable_id): 4}
	data.perk_picks = {str(first.stable_id): 2, str(fourth.stable_id): 4}

	var section := _build(data).sections[3]
	assert_eq(section.entries[0].value_text, "x2")
	assert_eq(section.entries[0].label, first.display_name)
	assert_string_contains(section.entries[0].tooltip, "Picked 2 of 10 offers (20%)")
	assert_false(section.entries[0].highlighted)
	assert_true(section.entries[3].highlighted)
	assert_eq(section.entries[1].value_text, "x0")
	assert_true(section.entries[1].dimmed)
	assert_string_contains(section.entries[1].tooltip, "Picked 0 of 0 offers (0%)")
	assert_eq(section.subtitle, "2 of 15 discovered")


func test_death_bars_sort_by_count_and_normalise_to_the_top_cause() -> void:
	var data := PlayerStatistics.new()
	data.runs_started = 10
	data.deaths_by_cause = {"acid": 12, "cooked": 31, "poison": 12, "bounds": 0}

	var section := _build(data).sections[4]
	var labels := PackedStringArray()
	for entry in section.entries:
		labels.append(entry.label)
	assert_eq(labels.slice(0, 3), PackedStringArray(["Cooked", "Dissolved", "Poisoned"]), "Ties keep presentation order.")
	assert_eq(section.entries.size(), _presentation.death_causes.size())
	assert_eq(section.entries[0].fraction, 1.0)
	assert_almost_eq(section.entries[1].fraction, 12.0 / 31.0, 0.0001)
	assert_eq(section.entries[0].value_text, "31")
	assert_eq(section.entries[0].secondary_text, "56%")
	assert_true(section.entries[0].highlighted)
	assert_false(section.entries[1].highlighted)
	assert_false(section.entries[1].dimmed)
	var last := section.entries[section.entries.size() - 1]
	assert_true(last.dimmed)
	assert_eq(last.fraction, 0.0)
	assert_eq(last.secondary_text, "0%")
	assert_eq(section.subtitle, "55 deaths")


func test_unknown_keys_fall_back_to_the_unknown_icon_and_capitalised_name() -> void:
	var data := PlayerStatistics.new()
	data.deaths_by_cause = {"meteor_strike": 2, "cooked": 1}
	data.containers_opened = {"item_chest": 4, "ancient_vault": 1}
	data.flags_lost_by_cause = {"black_hole": 1}

	var view := _build(data)
	var death := view.sections[4].entries[0]
	assert_eq(death.label, "Meteor Strike")
	assert_eq(death.icon, _presentation.unknown_icon)
	assert_true(death.highlighted)

	var loot := view.sections[1].entries
	assert_eq(loot.size(), _presentation.containers.size() + _presentation.destroyed_objects.size() + _presentation.flag_loss_causes.size() + 2)
	assert_eq(loot[0].value_text, "4")
	assert_eq(loot[0].label, _presentation.containers[0].display_name)
	var labels := PackedStringArray()
	for entry in loot:
		labels.append(entry.label)
	assert_true(labels.has("Ancient Vault opened"))
	assert_true(labels.has("Flag lost: Black Hole"))
	assert_eq(loot[_presentation.containers.size()].icon, _presentation.unknown_icon)
	assert_eq(loot[loot.size() - 1].icon, _presentation.unknown_icon)


func test_builder_tolerates_missing_inputs() -> void:
	var view := StatisticsViewBuilder.new().build(null, null, null, null, null)
	assert_eq(view.sections.size(), 5)
	assert_eq(view.sections[2].entries.size(), 0)
	assert_eq(view.sections[3].entries.size(), 0)
	assert_false(view.empty_hint.is_empty())


func _build(data: PlayerStatistics) -> StatisticsViewData:
	return StatisticsViewBuilder.new().build(data, _item_catalog, _perk_catalog, _presentation, _rules)


func test_loot_section_lists_destroyed_objects_after_opened_ones() -> void:
	var data := PlayerStatistics.new()
	data.containers_opened = {"item_chest": 4}
	data.objects_destroyed = {"item_chest": 3, "perk_geode": 1, "explosive_barrel": 12}

	var loot := _build(data).sections[1].entries
	var first_destroyed := _presentation.containers.size()
	assert_eq(loot[first_destroyed].label, _presentation.destroyed_objects[0].display_name)
	assert_eq(loot[first_destroyed].value_text, "3")
	assert_eq(loot[first_destroyed + 1].value_text, "1")
	assert_false(loot[first_destroyed + 1].dimmed)
	assert_eq(loot[first_destroyed + 2].label, "Barrels exploded")
	assert_eq(loot[first_destroyed + 2].value_text, "12")
