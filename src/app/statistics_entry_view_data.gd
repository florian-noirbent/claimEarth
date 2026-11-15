## Presentation-only data for one statistics tile, icon cell, or bar row.
class_name StatisticsEntryViewData
extends RefCounted


var icon: Texture2D
## Short caption, for example "Games played".
var label := ""
## Primary value, already formatted, for example "42" or "3h 12m".
var value_text := ""
## Optional small second line or badge, for example "picked 5" or "38%".
var secondary_text := ""
## Multi-line detail text shown on hover.
var tooltip := ""
## Share in 0..1 for bar layouts; a negative value hides the bar.
var fraction := -1.0
## Zero or never-seen entry rendered desaturated.
var dimmed := false
## Record or most-common entry rendered with a gold accent.
var highlighted := false


func _init(
	icon_value: Texture2D = null,
	label_value := "",
	value_text_value := "",
	secondary_text_value := "",
	tooltip_value := "",
	fraction_value := -1.0,
	dimmed_value := false,
	highlighted_value := false
) -> void:
	icon = icon_value
	label = label_value
	value_text = value_text_value
	secondary_text = secondary_text_value
	tooltip = tooltip_value
	fraction = fraction_value
	dimmed = dimmed_value
	highlighted = highlighted_value
