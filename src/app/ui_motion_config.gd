## Tuning for cosmetic UI and HUD motion. Durations are seconds; scales are multipliers.
class_name UiMotionConfig
extends Resource


@export_group("Shared motion")
@export_range(0.0, 1.0, 0.01) var fade_duration := 0.14
@export_range(0.0, 1.0, 0.01) var fade_out_duration := 0.16
@export_range(0.0, 1.0, 0.01) var pop_duration := 0.22
## Scale a control starts from when it pops in.
@export_range(0.1, 1.0, 0.01) var pop_from_scale := 0.86
## Scale a large panel or page starts from when it opens.
@export_range(0.1, 1.0, 0.01) var panel_from_scale := 0.93
## Delay between consecutive controls of a staggered reveal.
@export_range(0.0, 0.5, 0.005) var stagger_delay := 0.045
@export_range(0.0, 1.0, 0.01) var punch_duration := 0.2
@export_range(1.0, 2.0, 0.01) var punch_scale := 1.16
@export_range(0.0, 1.0, 0.01) var shake_duration := 0.28
@export_range(0.0, 45.0, 0.5) var shake_degrees := 7.0
@export_range(0.0, 2.0, 0.01) var count_up_duration := 0.55
@export_range(0.0, 2.0, 0.01) var bar_grow_duration := 0.45

@export_group("Buttons")
@export_range(1.0, 1.5, 0.005) var button_hover_scale := 1.04
@export_range(0.5, 1.0, 0.005) var button_press_scale := 0.95
@export_range(0.0, 0.5, 0.01) var button_duration := 0.1
## Self-modulate multiplier of a hovered or focused button.
@export_range(1.0, 2.0, 0.01) var button_hover_brightness := 1.12

@export_group("Screens")
@export var curtain_color := Color(0.02, 0.015, 0.03, 1.0)
@export_range(0.0, 1.0, 0.01) var curtain_duration := 0.32
@export var modal_dim_color := Color(0.015, 0.012, 0.02, 0.6)
@export var death_dim_color := Color(0.16, 0.02, 0.015, 0.62)
@export var reward_dim_color := Color(0.015, 0.012, 0.02, 0.78)
@export_range(0.0, 1.0, 0.01) var modal_dim_duration := 0.22
@export_range(0.0, 1.0, 0.01) var progress_smooth_duration := 0.2
## Opacity of the menu buttons while a run is being generated.
@export_range(0.0, 1.0, 0.01) var generating_menu_alpha := 0.45
@export var record_color := Color(1.0, 0.86, 0.36, 1.0)
@export var danger_color := Color(1.0, 0.42, 0.32, 1.0)

@export_group("HUD")
## A toast announces every multiple of this depth the first time a run reaches it.
@export_range(1, 500, 1) var depth_milestone_interval := 50
@export_range(0.0, 5.0, 0.05) var toast_hold_duration := 1.2
@export_range(1.0, 1.5, 0.01) var depth_bump_scale := 1.07
@export_range(1.0, 2.0, 0.01) var item_gain_scale := 1.28
@export var item_gain_color := Color(1.9, 1.6, 0.8, 1.0)
@export var item_empty_modulate := Color(0.6, 0.6, 0.6, 0.45)
## Normalized hazard level at which a building meter starts to shake.
@export_range(0.0, 1.0, 0.01) var hazard_shake_start_level := 0.5
@export_range(0.0, 15.0, 0.1) var hazard_max_shake_degrees := 1.6
@export_range(0.0, 0.5, 0.005) var hazard_max_pulse_scale := 0.06
@export_range(0.1, 20.0, 0.1) var hazard_min_pulse_hz := 1.1
@export_range(0.1, 20.0, 0.1) var hazard_max_pulse_hz := 5.0

@export_group("Rewards")
@export_range(1.0, 1.5, 0.01) var reward_confirm_scale := 1.1
@export_range(0.0, 1.0, 0.01) var reward_confirm_duration := 0.3
@export_range(0.0, 1.0, 0.01) var reward_dismiss_duration := 0.14


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var durations := {
		"fade_duration": fade_duration,
		"fade_out_duration": fade_out_duration,
		"pop_duration": pop_duration,
		"punch_duration": punch_duration,
		"shake_duration": shake_duration,
		"button_duration": button_duration,
		"curtain_duration": curtain_duration,
		"modal_dim_duration": modal_dim_duration,
		"reward_confirm_duration": reward_confirm_duration,
		"reward_dismiss_duration": reward_dismiss_duration,
	}
	for duration_name: String in durations:
		var duration: float = durations[duration_name]
		if duration < 0.0 or duration > 0.5:
			errors.append("ui motion %s must stay within 0 and 0.5 seconds" % duration_name)
	if pop_from_scale <= 0.0 or pop_from_scale > 1.0:
		errors.append("ui motion pop_from_scale must be in (0, 1]")
	if button_press_scale <= 0.0 or button_press_scale > 1.0:
		errors.append("ui motion button_press_scale must be in (0, 1]")
	if button_hover_scale < 1.0:
		errors.append("ui motion button_hover_scale must be at least 1")
	if depth_milestone_interval < 1:
		errors.append("ui motion depth_milestone_interval must be positive")
	if hazard_max_pulse_hz < hazard_min_pulse_hz:
		errors.append("ui motion hazard pulse range is inverted")
	if hazard_shake_start_level < 0.0 or hazard_shake_start_level >= 1.0:
		errors.append("ui motion hazard_shake_start_level must be in [0, 1)")
	return errors
