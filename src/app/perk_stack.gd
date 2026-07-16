## Displays acquired perks as compact, wrapping tooltip badges.
class_name PerkStack
extends Control


@export_range(20, 96, 1) var badge_size := 44

@onready var badges: HFlowContainer = %Badges


func show_perks(perks: Array) -> void:
	for child in badges.get_children():
		child.queue_free()
	for perk_value in perks:
		var perk := perk_value as PerkViewData
		if perk == null:
			continue
		badges.add_child(_create_badge(perk))


func clear_perks() -> void:
	for child in badges.get_children():
		child.queue_free()


func perk_count() -> int:
	return badges.get_child_count()


func _create_badge(perk: PerkViewData) -> TextureButton:
	var badge := TextureButton.new()
	badge.custom_minimum_size = Vector2(badge_size, badge_size)
	badge.ignore_texture_size = true
	badge.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	badge.texture_normal = perk.icon
	badge.tooltip_text = "%s\n%s" % [perk.title, perk.description]
	badge.focus_mode = Control.FOCUS_NONE
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	return badge
