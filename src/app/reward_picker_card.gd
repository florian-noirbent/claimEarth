## Displays one generic item or perk reward choice.
class_name RewardPickerCard
extends Button


const _DISABLED_MODULATE := Color(0.72, 0.72, 0.72, 1.0)

## Stylebox shown while the chosen card plays its confirmation.
@export var confirmed_style: StyleBox

@onready var shortcut_label: Label = %ShortcutLabel
@onready var icon_rect: TextureRect = %Icon
@onready var title_label: Label = %Title
@onready var description_label: Label = %Description
@onready var quantity_label: Label = %Quantity


func _ready() -> void:
	UiMotion.attach_button(self)


func configure(choice: RewardChoiceViewData, shortcut: String) -> void:
	shortcut_label.text = shortcut
	icon_rect.texture = choice.icon
	title_label.text = choice.title
	description_label.text = choice.description
	quantity_label.text = choice.quantity_text
	tooltip_text = "%s: %s" % [choice.title, choice.description]


func set_choice_enabled(enabled: bool) -> void:
	disabled = not enabled
	UiMotion.set_rest_modulate(self, Color.WHITE if enabled else _DISABLED_MODULATE)


## Deals the card in; `delay` staggers neighboring cards.
func play_deal_in(delay: float) -> void:
	UiMotion.pop_in(self, delay)


## Plays the leaving animation of a card detached from the picker, then frees it.
## The chosen card swells and lifts away; the others just fade.
func play_dismiss(chosen: bool) -> void:
	disabled = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = ""
	if not UiMotion.can_animate(self):
		queue_free()
		return
	UiMotion.stop(self)
	var settings := UiMotion.config()
	if not chosen:
		UiMotion.fade_out(self, queue_free, settings.reward_dismiss_duration)
		return
	if confirmed_style != null:
		add_theme_stylebox_override(&"disabled", confirmed_style)
	modulate = Color.WHITE
	pivot_offset_ratio = Vector2(0.5, 0.5)
	var swell := Vector2.ONE * settings.reward_confirm_scale
	var hold := settings.reward_confirm_duration * 0.4
	var leave := settings.reward_confirm_duration * 0.6
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, ^"scale", swell, hold).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"scale", swell * 0.82, leave).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, ^"position:y", position.y - size.y * 0.12, leave).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, ^"modulate:a", 0.0, leave).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
