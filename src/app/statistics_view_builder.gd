## Turns lifetime player statistics into generic statistics page view data.
##
## Catalog and presentation resources decide which entries exist and how they look, so
## new items, perks, death causes, flag-loss causes, or containers need no code here.
class_name StatisticsViewBuilder
extends RefCounted


const EMPTY_HINT := "No runs recorded yet. Start a descent to fill these pages."


func build(
	statistics: PlayerStatistics,
	item_catalog: ItemCatalog,
	perk_catalog: PerkCatalog,
	presentation: StatisticsPresentationConfig,
	rules: StatisticsRules
) -> StatisticsViewData:
	var data := statistics if statistics != null else PlayerStatistics.new()
	var config := presentation if presentation != null else StatisticsPresentationConfig.new()
	var minimum_game_depth := rules.minimum_game_depth if rules != null else StatisticsRules.new().minimum_game_depth
	var sections: Array[StatisticsSectionViewData] = [
		_lifetime_section(data, config, minimum_game_depth),
		_loot_section(data, config),
		_items_section(data, item_catalog, config),
		_perks_section(data, perk_catalog, config),
		_deaths_section(data, config),
	]
	return StatisticsViewData.new(sections, EMPTY_HINT if data.runs_started == 0 else "")


## Formats seconds as "45s", "12m 05s", or "3h 12m".
static func format_duration(seconds: float) -> String:
	var total := maxi(int(floor(maxf(seconds, 0.0))), 0)
	if total < 60:
		return "%ds" % total
	var minutes := floori(total / 60.0)
	if total < 3600:
		return "%dm %02ds" % [minutes, total % 60]
	return "%dh %02dm" % [floori(total / 3600.0), minutes % 60]


## Formats a count with a space between thousands groups, for example "58 210".
static func format_count(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = " " + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


## Formats part / whole as a rounded percentage; a zero whole reads as "0%".
static func format_percent(part: int, whole: int) -> String:
	if whole <= 0:
		return "0%"
	return "%d%%" % roundi(100.0 * float(part) / float(whole))


func _lifetime_section(data: PlayerStatistics, config: StatisticsPresentationConfig, minimum_game_depth: int) -> StatisticsSectionViewData:
	var deaths := data.total_deaths()
	var time_tooltip := "Total time spent in runs.\nLongest run: %s" % format_duration(data.longest_run_seconds)
	if data.victories > 0:
		time_tooltip += "\nFastest victory: %s" % format_duration(data.fastest_victory_seconds)
	var depth_tooltip := "Deepest row reached in any run."
	if data.best_flag_depth > 0:
		depth_tooltip += "\nDeepest planted flag: %s" % format_count(data.best_flag_depth)
	var entries: Array[StatisticsEntryViewData] = [
		_tile(
			config.runs_icon,
			"Games played",
			data.games_played,
			"",
			"Runs that reached depth %d.\nRuns started: %s" % [minimum_game_depth, format_count(data.runs_started)]
		),
		_tile(
			config.flag_icon,
			"Flags planted",
			data.flags_planted,
			"%s of runs" % format_percent(data.flags_planted, data.runs_started) if data.runs_started > 0 else "",
			"Runs that ended with a planted flag, counted when the flag lands."
		),
		_tile(
			config.victory_icon,
			"Victories",
			data.victories,
			"",
			"Flags planted in Earth's lava core at the bottom of the world.\nOnly a flag protected by the Relentless perk survives the lava.",
			data.victories > 0
		),
		_tile(
			config.streak_icon,
			"Best flag streak",
			data.best_flag_streak,
			"current %s" % format_count(data.current_flag_streak) if data.best_flag_streak > 0 else "",
			"Most consecutive played games that each planted a flag."
		),
		_text_tile(
			config.time_icon,
			"Time played",
			format_duration(data.total_play_seconds),
			"",
			time_tooltip,
			data.total_play_seconds <= 0.0
		),
		_tile(
			config.depth_icon,
			"Deepest depth",
			data.max_depth_reached,
			"best flag %s" % format_count(data.best_flag_depth) if data.best_flag_depth > 0 else "",
			depth_tooltip
		),
		_tile(
			config.distance_icon,
			"Total depth traveled",
			data.total_depth_traveled,
			"",
			"The deepest point of every run, added together."
		),
		_tile(config.death_icon, "Deaths", deaths, "", "Times the player died, in any run."),
	]
	var subtitle := "%s runs started" % format_count(data.runs_started) if data.runs_started > 0 else ""
	return StatisticsSectionViewData.new("Lifetime", StatisticsSectionViewData.Layout.TILES, entries, subtitle, config.runs_icon)


func _loot_section(data: PlayerStatistics, config: StatisticsPresentationConfig) -> StatisticsSectionViewData:
	var entries: Array[StatisticsEntryViewData] = []
	_append_keyed_tiles(entries, config.containers, data.containers_opened, config, "%s opened")
	_append_keyed_tiles(entries, config.flag_loss_causes, data.flags_lost_by_cause, config, "Flag lost: %s")
	var subtitle := "%s flags lost" % format_count(data.total_flags_lost()) if data.total_flags_lost() > 0 else ""
	return StatisticsSectionViewData.new("Loot & flags", StatisticsSectionViewData.Layout.TILES, entries, subtitle, config.flag_icon)


func _items_section(data: PlayerStatistics, item_catalog: ItemCatalog, config: StatisticsPresentationConfig) -> StatisticsSectionViewData:
	var definitions: Array[ItemDefinition] = []
	if item_catalog != null:
		for value in item_catalog.definitions:
			var definition := value as ItemDefinition
			if definition != null:
				definitions.append(definition)
	var top_uses := 0
	for definition in definitions:
		top_uses = maxi(top_uses, PlayerStatistics.count_in(data.item_uses, definition.stable_id))
	var entries: Array[StatisticsEntryViewData] = []
	var total_used := 0
	var tried := 0
	var highlight_given := false
	for definition in definitions:
		var uses := PlayerStatistics.count_in(data.item_uses, definition.stable_id)
		var picks := PlayerStatistics.count_in(data.item_picks, definition.stable_id)
		var offers := PlayerStatistics.count_in(data.item_offers, definition.stable_id)
		total_used += uses
		if uses > 0:
			tried += 1
		var highlighted := not highlight_given and top_uses > 0 and uses == top_uses
		highlight_given = highlight_given or highlighted
		var tooltip := "%s\n%s\nUsed %s\nPicked from chests %s of %s offers (%s)" % [
			definition.display_name,
			definition.description.strip_edges(),
			format_count(uses),
			format_count(picks),
			format_count(offers),
			format_percent(picks, offers),
		]
		entries.append(StatisticsEntryViewData.new(
			definition.icon,
			definition.display_name,
			format_count(uses),
			"picked %s" % format_count(picks) if picks > 0 else "",
			tooltip,
			-1.0,
			uses == 0 and picks == 0,
			highlighted
		))
	var subtitle := "%s used · %d of %d tried" % [format_count(total_used), tried, definitions.size()]
	return StatisticsSectionViewData.new("Items", StatisticsSectionViewData.Layout.ICON_GRID, entries, subtitle, config.item_icon)


func _perks_section(data: PlayerStatistics, perk_catalog: PerkCatalog, config: StatisticsPresentationConfig) -> StatisticsSectionViewData:
	var definitions: Array[PerkDefinition] = []
	if perk_catalog != null:
		for definition in perk_catalog.definitions:
			if definition != null:
				definitions.append(definition)
	var top_picks := 0
	for definition in definitions:
		top_picks = maxi(top_picks, PlayerStatistics.count_in(data.perk_picks, definition.stable_id))
	var entries: Array[StatisticsEntryViewData] = []
	var discovered := 0
	var highlight_given := false
	for definition in definitions:
		var picks := PlayerStatistics.count_in(data.perk_picks, definition.stable_id)
		var offers := PlayerStatistics.count_in(data.perk_offers, definition.stable_id)
		if picks > 0:
			discovered += 1
		var highlighted := not highlight_given and top_picks > 0 and picks == top_picks
		highlight_given = highlight_given or highlighted
		var tooltip := "%s\n%s\nPicked %s of %s offers (%s)" % [
			definition.display_name,
			definition.description.strip_edges(),
			format_count(picks),
			format_count(offers),
			format_percent(picks, offers),
		]
		entries.append(StatisticsEntryViewData.new(
			definition.icon,
			definition.display_name,
			"x%s" % format_count(picks),
			"",
			tooltip,
			-1.0,
			picks == 0,
			highlighted
		))
	var subtitle := "%d of %d discovered" % [discovered, definitions.size()]
	return StatisticsSectionViewData.new("Perks", StatisticsSectionViewData.Layout.ICON_GRID, entries, subtitle, config.perk_icon)


func _deaths_section(data: PlayerStatistics, config: StatisticsPresentationConfig) -> StatisticsSectionViewData:
	var total := data.total_deaths()
	# Each row is [count, presentation order, entry data] so ties keep presentation order.
	var rows: Array = []
	var known := {}
	for presentation in config.death_causes:
		if presentation == null:
			continue
		known[String(presentation.key)] = true
		rows.append([PlayerStatistics.count_in(data.deaths_by_cause, presentation.key), rows.size(), presentation.icon, presentation.display_name, presentation.description])
	for key in _unknown_keys(data.deaths_by_cause, known):
		rows.append([PlayerStatistics.count_in(data.deaths_by_cause, key), rows.size(), config.unknown_icon, key.capitalize(), ""])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1]))
	)
	var top := int(rows[0][0]) if not rows.is_empty() else 0
	var entries: Array[StatisticsEntryViewData] = []
	for row in rows:
		var count := int(row[0])
		var label := String(row[3])
		var description := String(row[4])
		var tooltip := "%s\n%s deaths (%s)" % [label, format_count(count), format_percent(count, total)]
		if not description.is_empty():
			tooltip = "%s\n%s\n%s deaths (%s)" % [label, description, format_count(count), format_percent(count, total)]
		entries.append(StatisticsEntryViewData.new(
			row[2] as Texture2D,
			label,
			format_count(count),
			format_percent(count, total),
			tooltip,
			float(count) / float(top) if top > 0 else 0.0,
			count == 0,
			count > 0 and count == top and entries.is_empty()
		))
	var subtitle := "%s %s" % [format_count(total), "death" if total == 1 else "deaths"]
	return StatisticsSectionViewData.new("Causes of death", StatisticsSectionViewData.Layout.BARS, entries, subtitle, config.death_icon)


func _append_keyed_tiles(
	entries: Array[StatisticsEntryViewData],
	presentations: Array[StatisticKeyPresentation],
	counter: Dictionary,
	config: StatisticsPresentationConfig,
	unknown_label_format: String
) -> void:
	var known := {}
	for presentation in presentations:
		if presentation == null:
			continue
		known[String(presentation.key)] = true
		var count := PlayerStatistics.count_in(counter, presentation.key)
		var tooltip := presentation.description if not presentation.description.is_empty() else presentation.display_name
		entries.append(_tile(presentation.icon, presentation.display_name, count, "", tooltip))
	for key in _unknown_keys(counter, known):
		var label := unknown_label_format % key.capitalize()
		entries.append(_tile(config.unknown_icon, label, PlayerStatistics.count_in(counter, key), "", label))


## Counter keys without a presentation entry, sorted for a stable layout.
func _unknown_keys(counter: Dictionary, known: Dictionary) -> PackedStringArray:
	var keys := PackedStringArray()
	for raw_key in counter.keys():
		var key := str(raw_key)
		if not known.has(key):
			keys.append(key)
	keys.sort()
	return keys


func _tile(icon: Texture2D, label: String, value: int, secondary: String, tooltip: String, highlighted: bool = false) -> StatisticsEntryViewData:
	return _text_tile(icon, label, format_count(value), secondary, tooltip, value == 0, highlighted)


func _text_tile(icon: Texture2D, label: String, value_text: String, secondary: String, tooltip: String, dimmed: bool, highlighted: bool = false) -> StatisticsEntryViewData:
	return StatisticsEntryViewData.new(icon, label, value_text, secondary, tooltip, -1.0, dimmed, highlighted)
