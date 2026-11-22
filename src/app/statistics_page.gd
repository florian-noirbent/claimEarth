## Scrollable lifetime statistics page built from generic presentation data.
class_name StatisticsPage
extends PanelContainer

signal back_requested

@export var section_scene: PackedScene
## Share of the shared stagger delay used between sections.
@export_range(0.0, 4.0, 0.05) var section_stagger_ratio := 1.5

@onready var back_button: Button = %BackButton
@onready var scroll: ScrollContainer = %Scroll
@onready var empty_hint_label: Label = %EmptyHint
@onready var sections_root: VBoxContainer = %Sections


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)
	UiMotion.attach_button(back_button)


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
	_play_intro()


## Reveals the sections top to bottom; bars grow and whole numbers count up.
func _play_intro() -> void:
	var step := UiMotion.config().stagger_delay * section_stagger_ratio
	for index in sections_root.get_child_count():
		var section := sections_root.get_child(index) as StatisticsSection
		if section != null:
			section.play_intro(step * index)


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
