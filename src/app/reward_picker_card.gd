## Displays one generic item or perk reward choice.
class_name RewardPickerCard
extends Button


@onready var shortcut_label: Label = %ShortcutLabel
@onready var icon_rect: TextureRect = %Icon
@onready var title_label: Label = %Title
@onready var description_label: Label = %Description
@onready var quantity_label: Label = %Quantity


func configure(choice: RewardChoiceViewData, shortcut: String) -> void:
	shortcut_label.text = shortcut
	icon_rect.texture = choice.icon
	title_label.text = choice.title
	description_label.text = choice.description
	quantity_label.text = choice.quantity_text
	tooltip_text = "%s: %s" % [choice.title, choice.description]


func set_choice_enabled(enabled: bool) -> void:
	disabled = not enabled
	modulate = Color.WHITE if enabled else Color(0.72, 0.72, 0.72, 1.0)
