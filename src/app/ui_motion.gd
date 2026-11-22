## Reusable cosmetic motion for UI controls.
##
## Every effect animates on top of a control's logical state: callers set visibility, text,
## and values first, then ask for motion. Starting an effect on a channel ends the previous
## effect on that channel at its rest state, so interrupted controls never keep a partial
## scale, rotation, or opacity. With motion disabled every call applies its final state at once.
class_name UiMotion
extends RefCounted


const DEFAULT_CONFIG_PATH := "res://config/ui/ui_motion.tres"

const _TRANSFORM := &"ui_motion_transform"
const _COLOR := &"ui_motion_color"
const _VALUE := &"ui_motion_value"
const _BUTTON_TINT := &"ui_motion_button_tint"
const _REST_MODULATE := &"ui_motion_rest_modulate"
const _FINAL_VALUE := &"ui_motion_final_value"
const _BUTTON_ATTACHED := &"ui_motion_button_attached"
const _BUTTON_HELD := &"ui_motion_button_held"
const _CENTER := Vector2(0.5, 0.5)

## Motion is skipped without a display so headless runs observe final states immediately.
static var enabled := DisplayServer.get_name() != "headless"

static var _config: UiMotionConfig


static func config() -> UiMotionConfig:
	if _config == null:
		_config = load(DEFAULT_CONFIG_PATH) as UiMotionConfig
		if _config == null:
			push_error("UI motion config is missing at %s; using defaults." % DEFAULT_CONFIG_PATH)
			_config = UiMotionConfig.new()
		for error in _config.validate():
			push_error(error)
	return _config


static func set_config(value: UiMotionConfig) -> void:
	_config = value


static func can_animate(control: Control) -> bool:
	return enabled and is_instance_valid(control) and control.is_inside_tree()


## True while a scale or rotation effect is still playing on the control.
static func is_moving(control: Control) -> bool:
	return _running_tween(control, _TRANSFORM) != null


## Ends every effect on the control and leaves it at rest.
static func stop(control: Control) -> void:
	if not is_instance_valid(control):
		return
	for channel: StringName in [_TRANSFORM, _COLOR, _VALUE, _BUTTON_TINT]:
		_end_channel(control, channel)
	control.self_modulate = Color.WHITE


## Fades and scales a control in from slightly smaller than its rest size.
static func pop_in(control: Control, delay: float = 0.0, from_scale: float = 0.0) -> void:
	if not can_animate(control):
		return
	var settings := config()
	var start_scale := from_scale if from_scale > 0.0 else settings.pop_from_scale
	fade_in(control, delay)
	var tween := _begin(control, _TRANSFORM)
	control.pivot_offset_ratio = _CENTER
	control.scale = Vector2.ONE * start_scale
	tween.tween_property(control, ^"scale", Vector2.ONE, settings.pop_duration) \
		.from(Vector2.ONE * start_scale).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func fade_in(control: Control, delay: float = 0.0, duration: float = -1.0) -> void:
	if not can_animate(control):
		return
	var rest := rest_modulate(control)
	_animate_modulate(control, Color(rest, 0.0), rest, config().fade_duration if duration < 0.0 else duration, delay)


## Fades a control out, calls `on_finished` (usually to hide it), then restores its opacity.
static func fade_out(control: Control, on_finished: Callable = Callable(), duration: float = -1.0) -> void:
	if not can_animate(control):
		if on_finished.is_valid():
			on_finished.call()
		return
	var rest := rest_modulate(control)
	var tween := _begin(control, _COLOR)
	control.set_meta(_REST_MODULATE, rest)
	tween.tween_property(control, ^"modulate", Color(rest, 0.0), config().fade_out_duration if duration < 0.0 else duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if on_finished.is_valid():
		tween.tween_callback(on_finished)


## Moves a control's resting modulate to `target`, for states such as dimmed or tinted.
static func tint_to(control: Control, target: Color, duration: float = -1.0) -> void:
	if not is_instance_valid(control) or rest_modulate(control) == target:
		return
	if not can_animate(control):
		_end_channel(control, _COLOR)
		control.modulate = target
		return
	var from := control.modulate
	_animate_modulate(control, from, target, config().fade_duration if duration < 0.0 else duration, 0.0)


## Flashes a control with `color` and settles back to its resting modulate.
static func flash(control: Control, color: Color, duration: float = -1.0) -> void:
	if not can_animate(control):
		return
	var rest := rest_modulate(control)
	_animate_modulate(control, color, rest, config().punch_duration * 1.6 if duration < 0.0 else duration, 0.0)


## Sets a control's resting modulate at once, ending any fade that would overwrite it.
static func set_rest_modulate(control: Control, color: Color) -> void:
	if not is_instance_valid(control):
		return
	_end_channel(control, _COLOR)
	control.modulate = color


## The modulate the control settles on once its current fade ends.
static func rest_modulate(control: Control) -> Color:
	if control.has_meta(_REST_MODULATE):
		return control.get_meta(_REST_MODULATE) as Color
	return control.modulate


## Jumps to a larger scale and settles back, for "something changed here" feedback.
static func punch(control: Control, peak_scale: float = 0.0) -> void:
	if not can_animate(control):
		return
	var settings := config()
	var peak := Vector2.ONE * (peak_scale if peak_scale > 0.0 else settings.punch_scale)
	_scale_back(control, peak, settings.punch_duration)


## Squashes wide and flat and springs back, for "this was used" feedback.
static func squash(control: Control) -> void:
	if not can_animate(control):
		return
	var settings := config()
	_scale_back(control, Vector2(settings.punch_scale, 2.0 - settings.punch_scale), settings.punch_duration)


## Wobbles a control around its center, for "not available" feedback.
static func shake(control: Control, degrees: float = -1.0) -> void:
	if not can_animate(control):
		return
	var settings := config()
	var angle := deg_to_rad(settings.shake_degrees if degrees < 0.0 else degrees)
	var step := settings.shake_duration / 5.0
	var tween := _begin(control, _TRANSFORM)
	control.pivot_offset_ratio = _CENTER
	control.rotation = angle
	for factor: float in [-1.0, 0.6, -0.35, 0.15, 0.0]:
		tween.tween_property(control, ^"rotation", angle * factor, step).set_trans(Tween.TRANS_SINE)


## Counts an integer label up or down to `to`; `format` receives the integer.
static func count_to(label: Label, from: int, to: int, format: String = "%d", duration: float = -1.0, delay: float = 0.0) -> void:
	if not is_instance_valid(label):
		return
	_end_channel(label, _VALUE)
	label.text = format % to
	if not can_animate(label) or from == to:
		return
	var set_text := func(value: float) -> void: label.text = format % roundi(value)
	var tween := _begin(label, _VALUE)
	label.set_meta(_FINAL_VALUE, set_text.bind(float(to)))
	label.text = format % from
	tween.tween_method(set_text, float(from), float(to), config().count_up_duration if duration < 0.0 else duration) \
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Moves a bar or slider to `to`, from `from` when given or from its current value.
static func tween_range(bar: Range, to: float, duration: float = -1.0, delay: float = 0.0, from: float = NAN) -> void:
	if not is_instance_valid(bar):
		return
	_end_channel(bar, _VALUE)
	if not can_animate(bar):
		bar.value = to
		return
	var start := bar.value if is_nan(from) else from
	var set_value := func(value: float) -> void: bar.value = value
	var tween := _begin(bar, _VALUE)
	bar.set_meta(_FINAL_VALUE, set_value.bind(to))
	bar.value = start
	tween.tween_method(set_value, start, to, config().bar_grow_duration if duration < 0.0 else duration) \
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Ends a running count or bar animation at its final value.
static func finish_value(control: Control) -> void:
	if is_instance_valid(control):
		_end_channel(control, _VALUE)


## Gives a button hover, focus, and press response. Safe to call more than once.
static func attach_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta(_BUTTON_ATTACHED):
		return
	button.set_meta(_BUTTON_ATTACHED, true)
	button.mouse_entered.connect(_refresh_button.bind(button))
	button.mouse_exited.connect(_refresh_button.bind(button))
	button.focus_entered.connect(_refresh_button.bind(button))
	button.focus_exited.connect(_refresh_button.bind(button))
	button.button_down.connect(_set_button_held.bind(button, true))
	button.button_up.connect(_set_button_held.bind(button, false))
	button.visibility_changed.connect(_on_button_visibility_changed.bind(button))


## Attaches the button response to every button below `root`, including instanced scenes.
static func attach_buttons_in(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		attach_button(node as BaseButton)


static func _set_button_held(button: BaseButton, held: bool) -> void:
	button.set_meta(_BUTTON_HELD, held)
	_refresh_button(button)


static func _on_button_visibility_changed(button: BaseButton) -> void:
	if not button.is_visible_in_tree():
		button.set_meta(_BUTTON_HELD, false)
		_end_channel(button, _TRANSFORM)
		_end_channel(button, _BUTTON_TINT)
		button.self_modulate = Color.WHITE


static func _refresh_button(button: BaseButton) -> void:
	if not can_animate(button):
		return
	var settings := config()
	var held := bool(button.get_meta(_BUTTON_HELD, false))
	var lit := not button.disabled and (button.is_hovered() or button.has_focus())
	var target := 1.0
	if held and not button.disabled:
		target = settings.button_press_scale
	elif lit:
		target = settings.button_hover_scale
	var current_scale := button.scale
	var tween := _begin(button, _TRANSFORM, false)
	button.pivot_offset_ratio = _CENTER
	button.scale = current_scale
	var scale_step := tween.tween_property(button, ^"scale", Vector2.ONE * target, settings.button_duration)
	if held:
		scale_step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		scale_step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var brightness := settings.button_hover_brightness if lit else 1.0
	var tint := _begin(button, _BUTTON_TINT, false)
	tint.tween_property(button, ^"self_modulate", Color(brightness, brightness, brightness, 1.0), settings.button_duration)


static func _scale_back(control: Control, from: Vector2, duration: float) -> void:
	var tween := _begin(control, _TRANSFORM)
	control.pivot_offset_ratio = _CENTER
	control.scale = from
	tween.tween_property(control, ^"scale", Vector2.ONE, duration).from(from) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _animate_modulate(control: Control, from: Color, to: Color, duration: float, delay: float) -> void:
	var tween := _begin(control, _COLOR)
	control.set_meta(_REST_MODULATE, to)
	control.modulate = from
	tween.tween_property(control, ^"modulate", to, duration).from(from).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Ends the channel's previous effect at rest and returns a fresh tween for the next one.
## `settle_on_finish` false keeps the animated end value, as button hover needs.
static func _begin(control: Control, channel: StringName, settle_on_finish: bool = true) -> Tween:
	_end_channel(control, channel)
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	control.set_meta(channel, tween)
	if settle_on_finish:
		tween.finished.connect(_end_channel.bind(control, channel))
	return tween


static func _end_channel(control: Control, channel: StringName) -> void:
	if not is_instance_valid(control):
		return
	if control.has_meta(channel):
		var tween := control.get_meta(channel) as Tween
		control.remove_meta(channel)
		if tween != null and tween.is_valid():
			tween.kill()
	match channel:
		_TRANSFORM:
			control.scale = Vector2.ONE
			control.rotation = 0.0
		_COLOR:
			if control.has_meta(_REST_MODULATE):
				control.modulate = control.get_meta(_REST_MODULATE) as Color
				control.remove_meta(_REST_MODULATE)
		_VALUE:
			if control.has_meta(_FINAL_VALUE):
				var apply_final := control.get_meta(_FINAL_VALUE) as Callable
				control.remove_meta(_FINAL_VALUE)
				apply_final.call()


static func _running_tween(control: Control, channel: StringName) -> Tween:
	if not is_instance_valid(control) or not control.has_meta(channel):
		return null
	var tween := control.get_meta(channel) as Tween
	return tween if tween != null and tween.is_valid() and tween.is_running() else null
