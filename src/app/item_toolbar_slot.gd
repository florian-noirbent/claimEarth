## Displays one selectable inventory item in the in-run toolbar.
class_name ItemToolbarSlot
extends Button


@export var normal_style: StyleBoxFlat
@export var selected_style: StyleBoxFlat
@export var count_color := Color(0.86, 0.84, 0.8, 1.0)
@export var empty_count_color := Color(0.9, 0.45, 0.36, 1.0)

@onready var icon_rect: TextureRect = %Icon
@onready var key_label: Label = %KeyLabel
@onready var count_label: Label = %CountLabel

var _configured := false
var _selected := false
var _count := 0.0
var _count_text := ""


func _ready() -> void:
	UiMotion.attach_button(self)


## Applies the item state at once, then reacts to what changed since the previous call:
## a new selection pops (or shakes when the item is empty), a gained item pulses, and a
## used item squashes. `count` is the raw quantity; it defaults to the count text.
func configure(icon: Texture2D, shortcut: String, count_text: String, selected: bool, count: float = NAN) -> void:
	var numeric_count := count
	if is_nan(numeric_count):
		numeric_count = count_text.to_float() if count_text.is_valid_float() else 0.0
	var was_configured := _configured
	var was_selected := _selected
	var previous_count := _count
	var count_text_changed := count_text != _count_text
	_configured = true
	_selected = selected
	_count = numeric_count
	_count_text = count_text

	icon_rect.texture = icon
	key_label.text = shortcut
	count_label.text = "x%s" % count_text
	# This runs every frame during play, so theme overrides are only touched on a change.
	if not was_configured or selected != was_selected:
		var style := selected_style if selected else normal_style
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("hover", style)
		add_theme_stylebox_override("pressed", style)
		add_theme_stylebox_override("focus", style)
	var empty := numeric_count <= 0.0
	var icon_modulate := UiMotion.config().item_empty_modulate if empty else Color.WHITE
	if not was_configured:
		count_label.add_theme_color_override(&"font_color", empty_count_color if empty else count_color)
		icon_rect.modulate = icon_modulate
		return
	if empty != (previous_count <= 0.0):
		count_label.add_theme_color_override(&"font_color", empty_count_color if empty else count_color)
		UiMotion.tint_to(icon_rect, icon_modulate)
	if numeric_count > previous_count:
		play_gained()
	elif count_text_changed and numeric_count < previous_count:
		UiMotion.squash(icon_rect)
		UiMotion.punch(count_label)
	if selected and not was_selected:
		if empty:
			UiMotion.shake(self)
		else:
			UiMotion.punch(self)


func is_selected() -> bool:
	return _selected


## Pulses the slot to show that its item was just picked up.
func play_gained() -> void:
	var settings := UiMotion.config()
	UiMotion.punch(icon_rect, settings.item_gain_scale)
	UiMotion.punch(count_label, settings.item_gain_scale)
	UiMotion.flash(self, settings.item_gain_color)
