## Collection-style statistics cell with a large icon and its count underneath.
class_name StatisticsIconCell
extends StatisticsEntryControl


@onready var icon_rect: TextureRect = %Icon
@onready var value_label: Label = %Value
@onready var caption_label: Label = %Caption
@onready var secondary_label: Label = %Secondary


func _apply_entry(entry: StatisticsEntryViewData) -> void:
	icon_rect.texture = entry.icon
	icon_rect.modulate = _icon_modulate()
	UiMotion.finish_value(value_label)
	value_label.text = entry.value_text
	value_label.add_theme_color_override(&"font_color", _value_color())
	_set_optional_text(caption_label, entry.label)
	_set_optional_text(secondary_label, entry.secondary_text)


func _play_value_intro(delay: float) -> void:
	_count_up(value_label, delay)
