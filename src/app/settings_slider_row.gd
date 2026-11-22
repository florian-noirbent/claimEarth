## One labelled percentage slider of the Settings panel. Values are shares: 1.0 is 100%.
class_name SettingsSliderRow
extends HBoxContainer


## The slider moved, by dragging, keyboard, or gamepad.
signal value_changed(value: float)
## The player settled on a value: a drag ended, or the value changed without a drag.
signal value_committed(value: float)

@export var title := "":
	set(value):
		title = value
		if is_node_ready():
			title_label.text = value
@export_range(5, 400, 5) var max_percent := 100
@export_range(1, 50, 1) var step_percent := 5
## Shown instead of "0%".
@export var zero_text := "Off"

@onready var title_label: Label = %TitleLabel
@onready var slider: HSlider = %Slider
@onready var value_label: Label = %ValueLabel

var _dragging := false


func _ready() -> void:
	title_label.text = title
	slider.max_value = max_percent
	slider.step = step_percent
	slider.value_changed.connect(_on_slider_value_changed)
	slider.drag_started.connect(_on_drag_started)
	slider.drag_ended.connect(_on_drag_ended)
	_refresh_value_label()


func value() -> float:
	return slider.value / 100.0


## Shows a value without reporting it as a change.
func set_value_no_signal(share: float) -> void:
	slider.set_value_no_signal(share * 100.0)
	_refresh_value_label()


func _on_slider_value_changed(_percent: float) -> void:
	_refresh_value_label()
	value_changed.emit(value())
	if not _dragging:
		value_committed.emit(value())


func _on_drag_started() -> void:
	_dragging = true


func _on_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	value_committed.emit(value())


func _refresh_value_label() -> void:
	var percent := roundi(slider.value)
	value_label.text = zero_text if percent <= 0 and not zero_text.is_empty() else "%d%%" % percent
