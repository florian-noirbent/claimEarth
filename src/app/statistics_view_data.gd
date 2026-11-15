## Presentation-only data for the whole statistics page.
class_name StatisticsViewData
extends RefCounted


var sections: Array[StatisticsSectionViewData] = []
## Friendly line shown above the sections when non-empty.
var empty_hint := ""


func _init(sections_value: Array[StatisticsSectionViewData] = [], empty_hint_value := "") -> void:
	sections = sections_value.duplicate()
	empty_hint = empty_hint_value
