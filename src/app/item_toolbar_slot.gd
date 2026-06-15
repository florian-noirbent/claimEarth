class_name ItemToolbarSlot
extends PanelContainer


@export var normal_style: StyleBoxFlat
@export var selected_style: StyleBoxFlat

@onready var icon_rect: TextureRect = %Icon
@onready var key_label: Label = %KeyLabel
@onready var count_label: Label = %CountLabel


func configure(icon: Texture2D, shortcut: String, count: int, selected: bool) -> void:
	icon_rect.texture = icon
	key_label.text = shortcut
	count_label.text = "x%d" % count
	add_theme_stylebox_override("panel", selected_style if selected else normal_style)
