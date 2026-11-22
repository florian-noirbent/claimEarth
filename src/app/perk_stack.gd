## Displays acquired perks as compact, wrapping tooltip badges.
class_name PerkStack
extends Control


@export_range(20, 96, 1) var badge_size := 44
## Scale a newly acquired perk badge pops in from.
@export_range(0.1, 1.0, 0.05) var gained_from_scale := 0.3

@onready var badges: HFlowContainer = %Badges

var _shown_perk_ids := {}


## Replaces the badges; perks that were not shown before pop in.
func show_perks(perks: Array) -> void:
	_remove_badges()
	var shown := {}
	for perk_value in perks:
		var perk := perk_value as PerkViewData
		if perk == null:
			continue
		var badge := _create_badge(perk)
		badges.add_child(badge)
		shown[perk.perk_id] = true
		if not _shown_perk_ids.has(perk.perk_id):
			UiMotion.pop_in(badge, 0.0, gained_from_scale)
	_shown_perk_ids = shown


func clear_perks() -> void:
	_remove_badges()
	_shown_perk_ids.clear()


func perk_count() -> int:
	return badges.get_child_count()


func _remove_badges() -> void:
	for child in badges.get_children():
		badges.remove_child(child)
		child.queue_free()


func _create_badge(perk: PerkViewData) -> TextureButton:
	var badge := TextureButton.new()
	badge.custom_minimum_size = Vector2(badge_size, badge_size)
	badge.ignore_texture_size = true
	badge.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	badge.texture_normal = perk.icon
	badge.tooltip_text = "%s\n%s" % [perk.title, perk.description]
	badge.focus_mode = Control.FOCUS_NONE
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	UiMotion.attach_button(badge)
	return badge
