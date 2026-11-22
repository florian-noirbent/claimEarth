## Renders one generic hazard meter without knowing any terrain or gameplay details.
class_name HazardMeterRow
extends Control


@onready var panel: Panel = %Panel
@onready var icon_rect: TextureRect = %Icon
@onready var meter: ProgressBar = %Meter
@onready var state_indicator: Label = %StateIndicator
@onready var forward_sweep: ColorRect = %ForwardSweep
@onready var secondary_marker: ColorRect = %SecondaryMarker
@onready var lethal_end_marker: ColorRect = %LethalEndMarker

var _active := false
var _bar_color := Color.WHITE
var _level := 0.0
var _pulse_time := 0.0
var _sweep_time := 0.0


func configure(
	icon: Texture2D,
	bar_color: Color,
	normalized_level: float,
	active: bool,
	secondary_threshold: float = -1.0,
	lethal_end: bool = false
) -> void:
	icon_rect.texture = icon
	_bar_color = bar_color
	var was_active := _active
	_active = active
	_level = clampf(normalized_level, 0.0, 1.0)
	meter.value = _level * 100.0
	secondary_marker.visible = secondary_threshold > 0.0 and secondary_threshold < 1.0
	secondary_marker.anchor_left = clampf(secondary_threshold, 0.0, 1.0)
	secondary_marker.anchor_right = secondary_marker.anchor_left
	lethal_end_marker.visible = lethal_end
	_apply_presentation()
	set_process(_active)
	if was_active and not _active:
		_settle()


func is_building() -> bool:
	return _active


## Normalized 0..1 urgency of a building meter past the configured shake start level.
func danger() -> float:
	if not _active:
		return 0.0
	var start := UiMotion.config().hazard_shake_start_level
	return clampf(inverse_lerp(start, 1.0, _level), 0.0, 1.0)


## Pops the meter in when its hazard first appears.
func play_appear() -> void:
	UiMotion.pop_in(self)


## Fades the meter out, then calls `on_finished`.
func play_retire(on_finished: Callable) -> void:
	set_process(false)
	_settle()
	UiMotion.fade_out(self, on_finished)


## A building meter pulses faster, glows redder, and shakes harder as it nears full.
func _process(delta: float) -> void:
	var settings := UiMotion.config()
	var urgency := danger()
	_sweep_time += delta
	_pulse_time += delta * TAU * lerpf(settings.hazard_min_pulse_hz, settings.hazard_max_pulse_hz, _level)
	var wave := (sin(_pulse_time) + 1.0) * 0.5
	var glow := 0.94 + wave * (0.06 + 0.3 * urgency)
	panel.modulate = Color(glow, glow * (1.0 - 0.35 * urgency * wave), glow * (1.0 - 0.45 * urgency * wave), 1.0)
	var sweep_width := 34.0
	var travel := maxf(size.x + sweep_width, 1.0)
	forward_sweep.position.x = fmod(_sweep_time * 100.0, travel) - sweep_width
	if not UiMotion.enabled or UiMotion.is_moving(self):
		return
	pivot_offset_ratio = Vector2(0.5, 0.5)
	scale = Vector2.ONE * (1.0 + settings.hazard_max_pulse_scale * urgency * wave)
	rotation = deg_to_rad(settings.hazard_max_shake_degrees) * urgency * sin(_pulse_time * 2.3)


func _settle() -> void:
	if UiMotion.is_moving(self):
		return
	scale = Vector2.ONE
	rotation = 0.0


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
