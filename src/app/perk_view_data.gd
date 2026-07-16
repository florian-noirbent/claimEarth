## Presentation-only data for one acquired perk badge.
class_name PerkViewData
extends RefCounted


var perk_id: StringName
var title := ""
var description := ""
var icon: Texture2D


func _init(
	perk_id_value: StringName = &"",
	title_value := "",
	description_value := "",
	icon_value: Texture2D = null
) -> void:
	perk_id = perk_id_value
	title = title_value
	description = description_value
	icon = icon_value
