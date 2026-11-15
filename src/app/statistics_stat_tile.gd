## Big-number statistics tile with an icon, value, caption, and optional detail line.
class_name StatisticsStatTile
extends StatisticsEntryControl


@onready var icon_rect: TextureRect = %Icon
@onready var value_label: Label = %Value
@onready var caption_label: Label = %Caption
@onready var secondary_label: Label = %Secondary


func _apply_entry(entry: StatisticsEntryViewData) -> void:
	icon_rect.texture = entry.icon
	icon_rect.visible = entry.icon != null
	icon_rect.modulate = _icon_modulate()
	value_label.text = entry.value_text
	value_label.add_theme_color_override(&"font_color", _value_color())
	caption_label.text = entry.label
	_set_optional_text(secondary_label, entry.secondary_text)
