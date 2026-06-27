## Displays one selectable inventory item in the in-run toolbar.
class_name ItemToolbarSlot
extends Button


@export var normal_style: StyleBoxFlat
@export var selected_style: StyleBoxFlat

@onready var icon_rect: TextureRect = %Icon
@onready var key_label: Label = %KeyLabel
@onready var count_label: Label = %CountLabel


func configure(icon: Texture2D, shortcut: String, count: int, selected: bool) -> void:
	icon_rect.texture = icon
	key_label.text = shortcut
	count_label.text = "x%d" % count
	var style := selected_style if selected else normal_style
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
