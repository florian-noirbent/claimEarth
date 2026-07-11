## Renders one generic hazard meter without knowing any terrain or gameplay details.
class_name HazardMeterRow
extends Control


@onready var panel: Panel = %Panel
@onready var icon_rect: TextureRect = %Icon
@onready var meter: ProgressBar = %Meter
@onready var state_indicator: Label = %StateIndicator
@onready var forward_sweep: ColorRect = %ForwardSweep

var _active := false
var _bar_color := Color.WHITE
var _pulse_time := 0.0


func configure(icon: Texture2D, bar_color: Color, normalized_level: float, active: bool) -> void:
	icon_rect.texture = icon
	_bar_color = bar_color
	_active = active
	meter.value = clampf(normalized_level, 0.0, 1.0) * 100.0
	_apply_presentation()
	set_process(_active)


func is_building() -> bool:
	return _active


func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse := 0.94 + (sin(_pulse_time * 7.0) + 1.0) * 0.03
	panel.modulate = Color(pulse, pulse, pulse, 1.0)
	var sweep_width := 34.0
	var travel := maxf(size.x + sweep_width, 1.0)
	forward_sweep.position.x = fmod(_pulse_time * 100.0, travel) - sweep_width


func _apply_presentation() -> void:
	var panel_style := _style_box(
		Color(0.075, 0.045, 0.025, 0.9),
		Color(0.96, 0.75, 0.19, 1.0) if _active else Color(0.30, 0.22, 0.16, 0.88),
		3 if _active else 2
	)
	panel.add_theme_stylebox_override("panel", panel_style)

	var background_style := _style_box(Color(0.035, 0.025, 0.018, 0.94), Color(0.16, 0.10, 0.06, 0.95), 1, 5)
	var fill_color := _bar_color if _active else _muted(_bar_color)
	var fill_style := _style_box(fill_color, Color(1.0, 0.84, 0.42, 0.9) if _active else Color(0.24, 0.18, 0.13, 0.9), 1, 5)
	meter.add_theme_stylebox_override("background", background_style)
	meter.add_theme_stylebox_override("fill", fill_style)
	icon_rect.modulate = Color.WHITE if _active else _muted(_bar_color)
	state_indicator.text = ">" if _active else "v"
	state_indicator.modulate = Color(1.0, 0.80, 0.34, 1.0) if _active else Color(0.65, 0.60, 0.52, 0.9)
	forward_sweep.visible = _active
	panel.modulate = Color.WHITE


func _style_box(background: Color, border: Color, border_width: int, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _muted(color: Color) -> Color:
	return Color(
		color.r * 0.46 + 0.18,
		color.g * 0.46 + 0.16,
		color.b * 0.46 + 0.14,
		0.78
	)
