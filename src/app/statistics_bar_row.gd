## Ranked statistics row with an icon, caption, proportional bar, and values.
class_name StatisticsBarRow
extends StatisticsEntryControl


const _BAR_FILL := Color(0.86, 0.43, 0.2, 1.0)
const _BAR_BACKGROUND := Color(0.05, 0.035, 0.025, 0.95)

@onready var icon_rect: TextureRect = %Icon
@onready var caption_label: Label = %Caption
@onready var bar: ProgressBar = %Bar
@onready var value_label: Label = %Value
@onready var secondary_label: Label = %Secondary


func _apply_entry(entry: StatisticsEntryViewData) -> void:
	icon_rect.texture = entry.icon
	icon_rect.visible = entry.icon != null
	icon_rect.modulate = _icon_modulate()
	caption_label.text = entry.label
	caption_label.add_theme_color_override(&"font_color", _value_color() if _highlighted else BODY_COLOR)
	var has_bar := entry.fraction >= 0.0
	bar.visible = has_bar
	bar.value = clampf(entry.fraction, 0.0, 1.0)
	caption_label.size_flags_horizontal = Control.SIZE_FILL if has_bar else Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override(&"background", _bar_style(_BAR_BACKGROUND, Color(0.24, 0.15, 0.09, 1.0)))
	bar.add_theme_stylebox_override(&"fill", _bar_style(HIGHLIGHT_COLOR if _highlighted else _BAR_FILL, Color(0, 0, 0, 0)))
	value_label.text = entry.value_text
	value_label.add_theme_color_override(&"font_color", _value_color())
	secondary_label.text = entry.secondary_text


func _bar_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(5)
	return style
