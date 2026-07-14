## Presentation-only data for one generic reward picker card.
class_name RewardChoiceViewData
extends RefCounted


var title := ""
var description := ""
var icon: Texture2D
var quantity_text := ""


func _init(
	title_value := "",
	description_value := "",
	icon_value: Texture2D = null,
	quantity_text_value := ""
) -> void:
	title = title_value
	description = description_value
	icon = icon_value
	quantity_text = quantity_text_value
