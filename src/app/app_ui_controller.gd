## Owns menu, HUD, pause, results, and leaderboard presentation.
class_name AppUiController
extends CanvasLayer

signal start_requested
signal leaderboard_requested
signal menu_requested
signal pause_requested
signal item_selected(index: int)
signal reward_selected(index: int)
signal score_confirmed(player_name: String)
signal restart_requested
signal settings_requested
signal phone_controls_changed(enabled: bool)
signal frame_limit_changed(fps: int)
signal fullscreen_requested
signal touch_move_changed(vector: Vector2)
signal touch_aim_changed(vector: Vector2)
signal touch_aim_released
signal touch_hook_pressed(aim: Vector2)
signal touch_hook_released

@export var item_toolbar_slot_scene: PackedScene
@export var reward_picker_card_scene: PackedScene

@onready var title_image: TextureRect = %Title
@onready var score_corner: MarginContainer = $ScoreCorner
@onready var owner_label: Label = %OwnerLabel
@onready var status_label: Label = %Status
@onready var warning_label: Label = %WarningLabel
@onready var controls_label: Label = %ControlsLabel
@onready var menu_art_background: TextureRect = $MenuBackground
@onready var menu_background: ColorRect = $Background
@onready var menu_root: CenterContainer = $Center
@onready var menu_panel: VBoxContainer = %MenuPanel
@onready var menu_start_button: Button = %StartButton
@onready var menu_help_button: Button = %HelpButton
@onready var menu_settings_button: Button = %SettingsButton
@onready var menu_leaderboard_button: Button = %LeaderboardButton
@onready var help_panel: PanelContainer = %HelpPanel
@onready var help_back_button: Button = %HelpBackButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var phone_controls_toggle: CheckButton = %PhoneControlsToggle
@onready var frame_limit_slider: HSlider = %FrameLimitSlider
@onready var frame_limit_value_label: Label = %FrameLimitValueLabel
@onready var settings_back_button: Button = %SettingsBackButton
@onready var overlay_root: Control = %OverlayRoot
@onready var playing_panel: VBoxContainer = %PlayingPanel
@onready var hazard_meter_stack = %HazardMeterStack
@onready var play_status_label: Label = %PlayStatus
@onready var run_state_label: Label = %RunStateLabel
@onready var fps_label: Label = %FpsLabel
@onready var fps_timer: Timer = %FpsTimer
@onready var top_right_controls: HBoxContainer = %TopRightControls
@onready var pause_button: Button = %PauseButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var item_toolbar: PanelContainer = %ItemToolbar
@onready var item_toolbar_content: HBoxContainer = %ItemToolbarContent
@onready var selection_name_label: Label = %SelectionNameLabel
@onready var selection_name_timer: Timer = %SelectionNameTimer
@onready var reward_picker_layer: Control = %RewardPickerLayer
@onready var reward_picker_title: Label = %RewardPickerTitle
@onready var reward_picker_cards: HBoxContainer = %RewardPickerCards
@onready var name_entry_panel: PanelContainer = %NameEntryPanel
@onready var name_entry_status: Label = %NameEntryStatus
@onready var player_name_input: LineEdit = %PlayerNameInput
@onready var confirm_score_button: Button = %ConfirmScoreButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_status: Label = %ResultStatus
@onready var restart_button: Button = %RestartButton
@onready var result_menu_button: Button = %ResultMenuButton
@onready var pause_panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var pause_help_button: Button = %PauseHelpButton
@onready var pause_settings_button: Button = %PauseSettingsButton
@onready var pause_restart_button: Button = %PauseRestartButton
@onready var pause_menu_button: Button = %PauseMenuButton
@onready var leaderboard_panel: PanelContainer = %LeaderboardPanel
@onready var leaderboard_status: Label = %LeaderboardStatus
@onready var leaderboard_rows: RichTextLabel = %LeaderboardRows
@onready var leaderboard_back_button: Button = %LeaderboardBackButton
@onready var left_touch_pad: Control = %LeftTouchPad
@onready var right_touch_pad: Control = %RightTouchPad

var _selected_item_name := ""
var _phone_controls_enabled := false
var _touch_controls_requested := true
var _web_fullscreen_available := false
var _fullscreen_active := false
var _current_state: StringName = RunPhase.MAIN_MENU

const FRAME_LIMIT_OPTIONS := [30, 60, 90, 120, 0]


func _ready() -> void:
	menu_start_button.pressed.connect(start_requested.emit)
	menu_help_button.pressed.connect(_show_help_page)
	menu_settings_button.pressed.connect(_show_settings_page)
	menu_leaderboard_button.pressed.connect(leaderboard_requested.emit)
	help_back_button.pressed.connect(_hide_help_page)
	settings_back_button.pressed.connect(_hide_settings_page)
	phone_controls_toggle.toggled.connect(_on_phone_controls_toggled)
	frame_limit_slider.value_changed.connect(_on_frame_limit_slider_changed)
	pause_button.pressed.connect(pause_requested.emit)
	fullscreen_button.pressed.connect(fullscreen_requested.emit)
	resume_button.pressed.connect(pause_requested.emit)
	pause_help_button.pressed.connect(_show_help_page)
	pause_settings_button.pressed.connect(_show_settings_page)
	pause_restart_button.pressed.connect(restart_requested.emit)
	pause_menu_button.pressed.connect(menu_requested.emit)
	result_menu_button.pressed.connect(menu_requested.emit)
	leaderboard_back_button.pressed.connect(menu_requested.emit)
	restart_button.pressed.connect(restart_requested.emit)
	confirm_score_button.pressed.connect(_on_confirm_score_pressed)
	selection_name_timer.timeout.connect(_on_selection_name_timeout)
	fps_timer.timeout.connect(_on_fps_timer_timeout)
	left_touch_pad.connect(&"stick_changed", touch_move_changed.emit)
	right_touch_pad.connect(&"stick_changed", touch_aim_changed.emit)
	right_touch_pad.connect(&"stick_released", touch_aim_released.emit)
	right_touch_pad.connect(&"hook_pressed", touch_hook_pressed.emit)
	right_touch_pad.connect(&"hook_released", touch_hook_released.emit)
	controls_label.visible = false
	owner_label.text = "Best: Nobody yet"
	_update_top_right_controls()


func apply_state(state: StringName, run_seed: int, storage_warning: String, pending_depth: int, player_name: String) -> void:
	_current_state = state
	var show_menu_shell := state in [RunPhase.MAIN_MENU, RunPhase.GENERATING, RunPhase.LEADERBOARD]
	if state != RunPhase.MAIN_MENU:
		_hide_help_page()
		_hide_settings_page()
	menu_art_background.visible = show_menu_shell
	menu_background.visible = show_menu_shell
	menu_root.visible = show_menu_shell
	title_image.visible = show_menu_shell and state != RunPhase.LEADERBOARD
	owner_label.visible = show_menu_shell and state != RunPhase.LEADERBOARD
	status_label.visible = show_menu_shell and state != RunPhase.LEADERBOARD
	warning_label.visible = show_menu_shell and not storage_warning.is_empty()
	controls_label.visible = false
	menu_panel.visible = state in [RunPhase.MAIN_MENU, RunPhase.GENERATING] and not help_panel.visible and not settings_panel.visible
	overlay_root.visible = state in [
		RunPhase.PLAYING,
		RunPhase.FLAG_IN_FLIGHT,
		RunPhase.NAME_ENTRY,
		RunPhase.PAUSED,
		RunPhase.SUBMITTING,
		RunPhase.DEATH,
		RunPhase.RESULT,
		RunPhase.REWARD_PICKER,
	]
	var is_active_play := state in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]
	playing_panel.visible = is_active_play
	fps_label.visible = is_active_play
	if is_active_play:
		show_fps(roundi(Engine.get_frames_per_second()))
		if fps_timer.is_stopped():
			fps_timer.start()
	else:
		fps_timer.stop()
	hazard_meter_stack.visible = state in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]
	pause_button.visible = state in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]
	_update_top_right_controls()
	item_toolbar.visible = state in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]
	_update_touch_controls_visibility()
	if state not in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]:
		selection_name_label.visible = false
		selection_name_timer.stop()
	name_entry_panel.visible = state == RunPhase.NAME_ENTRY
	result_panel.visible = state in [RunPhase.SUBMITTING, RunPhase.DEATH, RunPhase.RESULT]
	pause_panel.visible = state == RunPhase.PAUSED
	reward_picker_layer.visible = state == RunPhase.REWARD_PICKER
	leaderboard_panel.visible = state == RunPhase.LEADERBOARD
	warning_label.text = storage_warning
	if state in [RunPhase.MAIN_MENU, RunPhase.GENERATING]:
		hazard_meter_stack.clear_hazards()

	match state:
		RunPhase.MAIN_MENU:
			status_label.text = "Ready to descend | Seed %d" % run_seed
		RunPhase.GENERATING:
			status_label.text = "Generating run..."
		RunPhase.NAME_ENTRY:
			name_entry_status.text = "Depth: %d" % pending_depth
			player_name_input.text = player_name
			player_name_input.grab_focus()
		RunPhase.SUBMITTING, RunPhase.RESULT:
			result_title.text = "Flag Planted"
		RunPhase.DEATH:
			result_title.text = "Run Lost"


func dismiss_menu_shell() -> void:
	_hide_help_page()
	_hide_settings_page()
	menu_art_background.visible = false
	menu_background.visible = false
	menu_root.visible = false
	title_image.visible = false
	owner_label.visible = false
	status_label.visible = false
	warning_label.visible = false
	menu_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if handle_reward_picker_input(event):
		get_viewport().set_input_as_handled()
		return
	if (help_panel.visible or settings_panel.visible) and (event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed(InputActions.MENU_BACK)):
		if help_panel.visible:
			_hide_help_page()
		else:
			_hide_settings_page()
		get_viewport().set_input_as_handled()


func _show_help_page() -> void:
	settings_panel.visible = false
	menu_panel.visible = false
	status_label.visible = false
	warning_label.visible = false
	_show_auxiliary_page_shell()
	help_panel.visible = true


func _hide_help_page() -> void:
	if not is_node_ready():
		return
	help_panel.visible = false
	_restore_auxiliary_page_parent()


func _show_settings_page() -> void:
	help_panel.visible = false
	menu_panel.visible = false
	status_label.visible = false
	warning_label.visible = false
	_show_auxiliary_page_shell()
	settings_panel.visible = true
	settings_requested.emit()


func _hide_settings_page() -> void:
	if not is_node_ready():
		return
	settings_panel.visible = false
	_restore_auxiliary_page_parent()


func _show_auxiliary_page_shell() -> void:
	if _current_state == RunPhase.PAUSED:
		pause_panel.visible = false
		overlay_root.visible = false
		menu_root.visible = true


func _restore_auxiliary_page_parent() -> void:
	if _current_state in [RunPhase.MAIN_MENU, RunPhase.GENERATING]:
		menu_panel.visible = true
		status_label.visible = true
		warning_label.visible = not warning_label.text.is_empty()
	elif _current_state == RunPhase.PAUSED and not help_panel.visible and not settings_panel.visible:
		menu_root.visible = false
		overlay_root.visible = true
		pause_panel.visible = true


func set_phone_controls_enabled(enabled: bool) -> void:
	_phone_controls_enabled = enabled
	phone_controls_toggle.set_pressed_no_signal(enabled)
	_update_touch_controls_visibility()


func set_frame_limit_fps(fps: int) -> void:
	var option_index := FRAME_LIMIT_OPTIONS.find(fps)
	if option_index < 0:
		option_index = FRAME_LIMIT_OPTIONS.size() - 1
	frame_limit_slider.set_value_no_signal(option_index)
	frame_limit_value_label.text = _frame_limit_text(FRAME_LIMIT_OPTIONS[option_index])


func set_touch_controls_visible(visible: bool) -> void:
	_touch_controls_requested = visible
	_update_touch_controls_visibility()


func set_web_fullscreen_available(available: bool) -> void:
	_web_fullscreen_available = available
	_update_top_right_controls()


func set_fullscreen_active(active: bool) -> void:
	_fullscreen_active = active
	fullscreen_button.tooltip_text = "Exit fullscreen" if active else "Enter fullscreen"


func _update_top_right_controls() -> void:
	if not is_node_ready():
		return
	fullscreen_button.visible = _web_fullscreen_available
	top_right_controls.visible = pause_button.visible or fullscreen_button.visible
	score_corner.offset_bottom = 140.0 if _web_fullscreen_available else 70.0
	score_corner.add_theme_constant_override(&"margin_top", 86 if _web_fullscreen_available else 18)
	score_corner.add_theme_constant_override(&"margin_right", 24 if _web_fullscreen_available else 18)


func _on_phone_controls_toggled(enabled: bool) -> void:
	_phone_controls_enabled = enabled
	_update_touch_controls_visibility()
	phone_controls_changed.emit(enabled)


func _on_frame_limit_slider_changed(value: float) -> void:
	var option_index := clampi(roundi(value), 0, FRAME_LIMIT_OPTIONS.size() - 1)
	var fps: int = FRAME_LIMIT_OPTIONS[option_index]
	frame_limit_value_label.text = _frame_limit_text(fps)
	frame_limit_changed.emit(fps)


func _frame_limit_text(fps: int) -> String:
	return "Unlimited" if fps == 0 else "%d FPS" % fps


func _update_touch_controls_visibility() -> void:
	if not is_node_ready():
		return
	var visible := _phone_controls_enabled and _touch_controls_requested and _current_state in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]
	left_touch_pad.visible = visible
	right_touch_pad.visible = visible
	if not visible:
		left_touch_pad.call(&"reset")
		right_touch_pad.call(&"reset")


func show_generation_progress(progress: float, label: String) -> void:
	status_label.text = "%s %d%%" % [label, int(progress * 100.0)]


func show_play_status(status_text: String, hint_text: String) -> void:
	play_status_label.text = status_text
	run_state_label.text = hint_text


func show_fps(fps: int) -> void:
	fps_label.text = "FPS: %d" % fps


func _on_fps_timer_timeout() -> void:
	show_fps(roundi(Engine.get_frames_per_second()))


## Updates the generic top-center icon meters from gameplay-owned hazard snapshots.
func show_hazard_statuses(statuses: Array) -> void:
	hazard_meter_stack.update_hazards(statuses)


func show_run_status(depth: int, personal_best: int, hooked: bool, item_status: Dictionary) -> void:
	var best_text := "PB:%d" % personal_best if personal_best >= 0 else "PB:-"
	var rope_text := "Hooked" if hooked else "Free"
	play_status_label.text = "Depth %d  |  %s" % [depth, best_text]
	run_state_label.text = "Flag in flight" if bool(item_status["flag_in_flight"]) else rope_text
	_update_item_toolbar(item_status.get("items", []))


func _update_item_toolbar(items: Array) -> void:
	if item_toolbar_content.get_child_count() != items.size():
		for child in item_toolbar_content.get_children():
			child.free()
		for index in items.size():
			var slot := item_toolbar_slot_scene.instantiate() as ItemToolbarSlot
			item_toolbar_content.add_child(slot)
			slot.pressed.connect(_on_item_slot_pressed.bind(index))
	for index in items.size():
		var item: Dictionary = items[index]
		var slot := item_toolbar_content.get_child(index) as ItemToolbarSlot
		var selected := bool(item.get("selected", false))
		slot.configure(
			item.get("icon") as Texture2D,
			str(item.get("shortcut", index + 1)),
			int(item.get("count", 0)),
			selected
		)
		if selected:
			_show_selection_name_if_changed(str(item.get("name", "Item")))


func _on_item_slot_pressed(index: int) -> void:
	item_selected.emit(index)


func _show_selection_name_if_changed(item_name: String) -> void:
	if item_name == _selected_item_name:
		return
	var had_selection := not _selected_item_name.is_empty()
	_selected_item_name = item_name
	if not had_selection:
		return
	selection_name_label.text = item_name
	selection_name_label.visible = true
	selection_name_timer.start()


func _on_selection_name_timeout() -> void:
	selection_name_label.visible = false


func show_reward_choices(title: String, choices: Array) -> void:
	reward_picker_title.text = title
	for child in reward_picker_cards.get_children():
		child.free()
	for index in choices.size():
		var choice := choices[index] as RewardChoiceViewData
		if choice == null:
			continue
		var card := reward_picker_card_scene.instantiate() as RewardPickerCard
		reward_picker_cards.add_child(card)
		card.configure(choice, str(index + 1))
		card.pressed.connect(_on_reward_card_pressed.bind(index))
	if reward_picker_cards.get_child_count() > 0:
		(reward_picker_cards.get_child(0) as Control).call_deferred("grab_focus")


func set_reward_picker_enabled(enabled: bool) -> void:
	for child in reward_picker_cards.get_children():
		var card := child as RewardPickerCard
		if card != null:
			card.set_choice_enabled(enabled)


func handle_reward_picker_input(event: InputEvent) -> bool:
	if _current_state != RunPhase.REWARD_PICKER:
		return false
	var choice_actions := [
		InputActions.SELECT_SMALL_BOMB,
		InputActions.SELECT_LARGE_BOMB,
		InputActions.SELECT_FLAG,
	]
	for index in mini(choice_actions.size(), reward_picker_cards.get_child_count()):
		if event.is_action_pressed(choice_actions[index]):
			reward_selected.emit(index)
			return true
	return event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed(InputActions.MENU_BACK)


func _on_reward_card_pressed(index: int) -> void:
	reward_selected.emit(index)


func show_name_error(message: String) -> void:
	name_entry_status.text = message


func show_result(message: String) -> void:
	result_status.text = message


func show_leaderboard_loading() -> void:
	leaderboard_status.text = "Loading leaderboard..."
	leaderboard_rows.text = ""


func show_leaderboard(status: String, rows: String, top_user: String = "") -> void:
	leaderboard_status.text = status
	leaderboard_rows.text = rows
	if not top_user.is_empty():
		owner_label.text = top_user


func show_leaderboard_entries(entries: Array[LeaderboardEntry], failed: bool, message: String) -> void:
	if failed:
		show_leaderboard(message if not message.is_empty() else "Leaderboard unavailable.", "[center]Retry later. Local best still saves.[/center]")
		return
	if entries.is_empty():
		show_leaderboard("Nobody has claimed Earth yet.", "[center]No entries yet.[/center]", "Best: Nobody yet")
		return
	var lines := PackedStringArray()
	for entry in entries:
		lines.append("%d. %s - %d" % [entry.rank, entry.player_name, entry.score_depth])
	show_leaderboard("Top depths", "[code]%s[/code]" % "\n".join(lines), "Best: %s - %d" % [entries[0].player_name, entries[0].score_depth])


func _on_confirm_score_pressed() -> void:
	score_confirmed.emit(player_name_input.text)


func show_submission_result(player_name: String, depth: int, personal_best: int, failed: bool, message: String) -> void:
	var summary := "%s claimed depth %d. Personal best: %d." % [player_name, depth, personal_best]
	show_result(summary + ("\nOnline submit failed: %s" % message if failed else "\nScore submitted."))
