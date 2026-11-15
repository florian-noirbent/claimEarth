## Scrollable lifetime statistics page built from generic presentation data.
class_name StatisticsPage
extends PanelContainer

signal back_requested

@export var section_scene: PackedScene

@onready var back_button: Button = %BackButton
@onready var scroll: ScrollContainer = %Scroll
@onready var empty_hint_label: Label = %EmptyHint
@onready var sections_root: VBoxContainer = %Sections


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)


## Replaces every rendered section with the sections from the view data.
func show_statistics(view: StatisticsViewData) -> void:
	for child in sections_root.get_children():
		child.free()
	var hint := view.empty_hint if view != null else ""
	empty_hint_label.text = hint
	empty_hint_label.visible = not hint.is_empty()
	if view != null:
		for section in view.sections:
			if section == null:
				continue
			var control := section_scene.instantiate() as StatisticsSection
			sections_root.add_child(control)
			control.configure(section)
	scroll.scroll_vertical = 0


func section_count() -> int:
	return sections_root.get_child_count()


func entry_count(section_index: int) -> int:
	var section := section_at(section_index)
	return section.entry_count() if section != null else 0


func section_at(section_index: int) -> StatisticsSection:
	if section_index < 0 or section_index >= sections_root.get_child_count():
		return null
	return sections_root.get_child(section_index) as StatisticsSection


func focus_default() -> void:
	back_button.grab_focus()
