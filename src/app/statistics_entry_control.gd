## Shared focus, tooltip, and accent behavior for one rendered statistics entry.
class_name StatisticsEntryControl
extends PanelContainer


const VALUE_COLOR := Color(1.0, 0.97, 0.9, 1.0)
const HIGHLIGHT_COLOR := Color(0.96, 0.75, 0.19, 1.0)
const BODY_COLOR := Color(0.92, 0.89, 0.85, 1.0)
const HINT_COLOR := Color(0.75, 0.78, 0.83, 1.0)
const SECONDARY_COLOR := Color(0.43, 0.87, 0.94, 1.0)
const DIMMED_MODULATE := Color(1.0, 1.0, 1.0, 0.5)
const DIMMED_ICON_MODULATE := Color(0.72, 0.72, 0.72, 0.9)

const _BACKGROUND := Color(0.12, 0.08, 0.05, 0.94)
const _FOCUS_BACKGROUND := Color(0.2, 0.12, 0.06, 0.98)
const _BORDER := Color(0.3, 0.19, 0.11, 1.0)
const _HIGHLIGHT_BORDER := Color(0.96, 0.75, 0.19, 1.0)
const _FOCUS_BORDER := Color(1.0, 0.94, 0.76, 1.0)

## Horizontal and vertical inner padding of the entry panel.
@export var content_padding := Vector2(12.0, 8.0)
@export_range(0, 16, 1) var corner_radius := 8

var _highlighted := false
var _dimmed := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	# PASS keeps tooltips while letting drags and wheel events reach the scroll view.
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)
	_refresh_style()


func configure(entry: StatisticsEntryViewData) -> void:
	_highlighted = entry.highlighted
	_dimmed = entry.dimmed
	tooltip_text = entry.tooltip if not entry.tooltip.is_empty() else entry.label
	modulate = DIMMED_MODULATE if _dimmed else Color.WHITE
	_apply_entry(entry)
	_refresh_style()


func is_highlighted() -> bool:
	return _highlighted


func is_dimmed() -> bool:
	return _dimmed


## Fills the component-specific labels, icon, and bar.
func _apply_entry(_entry: StatisticsEntryViewData) -> void:
	pass


func _value_color() -> Color:
	return HIGHLIGHT_COLOR if _highlighted else VALUE_COLOR


func _icon_modulate() -> Color:
	return DIMMED_ICON_MODULATE if _dimmed else Color.WHITE


func _set_optional_text(label: Label, text: String) -> void:
	label.text = text
	label.visible = not text.is_empty()


func _refresh_style() -> void:
	var focused := has_focus()
	var style := StyleBoxFlat.new()
	style.bg_color = _FOCUS_BACKGROUND if focused else _BACKGROUND
	style.border_color = _FOCUS_BORDER if focused else (_HIGHLIGHT_BORDER if _highlighted else _BORDER)
	style.set_border_width_all(3 if focused or _highlighted else 2)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_padding.x
	style.content_margin_right = content_padding.x
	style.content_margin_top = content_padding.y
	style.content_margin_bottom = content_padding.y
	add_theme_stylebox_override(&"panel", style)
