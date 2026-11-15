## Presentation-only data for one titled group of statistics entries.
class_name StatisticsSectionViewData
extends RefCounted

enum Layout { TILES, ICON_GRID, BARS }

var title := ""
## Optional one-line summary shown beside the title.
var subtitle := ""
## Optional icon shown before the title.
var icon: Texture2D
var layout := Layout.TILES
var entries: Array[StatisticsEntryViewData] = []


func _init(
	title_value := "",
	layout_value := Layout.TILES,
	entries_value: Array[StatisticsEntryViewData] = [],
	subtitle_value := "",
	icon_value: Texture2D = null
) -> void:
	title = title_value
	layout = layout_value
	entries = entries_value.duplicate()
	subtitle = subtitle_value
	icon = icon_value
