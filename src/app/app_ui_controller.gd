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
signal statistics_requested
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
## Focus outline given to every menu-style button so keyboard and gamepad focus reads clearly.
@export var button_focus_style: StyleBox

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
@onready var menu_statistics_button: Button = %StatisticsButton
@onready var menu_leaderboard_button: Button = %LeaderboardButton
@onready var help_panel: PanelContainer = %HelpPanel
@onready var help_back_button: Button = %HelpBackButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var phone_controls_toggle: CheckButton = %PhoneControlsToggle
@onready var frame_limit_slider: HSlider = %FrameLimitSlider
@onready var frame_limit_value_label: Label = %FrameLimitValueLabel
@onready var settings_back_button: Button = %SettingsBackButton
@onready var statistics_page: StatisticsPage = %StatisticsPage
@onready var overlay_root: Control = %OverlayRoot
@onready var playing_panel: VBoxContainer = %PlayingPanel
@onready var hazard_meter_stack = %HazardMeterStack
@onready var perk_stack: PerkStack = get_node_or_null("%PerkStack") as PerkStack
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
@onready var modal_dim: ColorRect = %ModalDim
@onready var transition_curtain: ColorRect = %TransitionCurtain
@onready var effects_layer: Control = %EffectsLayer
@onready var generation_progress: ProgressBar = %GenerationProgress
@onready var hud_toast: Label = %HudToast
@onready var name_entry_record_label: Label = %NameEntryRecordLabel
@onready var result_record_label: Label = %ResultRecordLabel
@onready var reward_picker_panel: PanelContainer = $OverlayRoot/RewardPickerLayer/Center/Panel

var _selected_item_name := ""
var _phone_controls_enabled := false
var _touch_controls_requested := true
var _web_fullscreen_available := false
var _fullscreen_active := false
var _current_state: StringName = RunPhase.MAIN_MENU
var _state_applied := false
var _toolbar_dealt := false
var _depth_seen := false
var _last_depth := 0
var _deepest_milestone := 0
var _last_personal_best := -1
var _beyond_personal_best := false
var _celebrated_personal_best := false
var _pending_depth_is_record := false
var _score_was_confirmed := false
var _modal_dim_wanted := false
var _toast_tween: Tween
var _play_status_color := Color.WHITE
var _result_title_color := Color.WHITE

const FRAME_LIMIT_OPTIONS := [30, 60, 90, 120, 0]
const _MENU_SHELL_STATES: Array[StringName] = [RunPhase.MAIN_MENU, RunPhase.GENERATING, RunPhase.LEADERBOARD]
const _ACTIVE_PLAY_STATES: Array[StringName] = [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT]
const _RESULT_STATES: Array[StringName] = [RunPhase.SUBMITTING, RunPhase.DEATH, RunPhase.RESULT]
const _TOOLBAR_SLOT_KEY := &"toolbar_catalog_index"


func _ready() -> void:
	menu_start_button.pressed.connect(start_requested.emit)
	menu_help_button.pressed.connect(_show_help_page)
	menu_settings_button.pressed.connect(_show_settings_page)
	menu_statistics_button.pressed.connect(statistics_requested.emit)
	menu_leaderboard_button.pressed.connect(leaderboard_requested.emit)
	help_back_button.pressed.connect(_hide_help_page)
	settings_back_button.pressed.connect(_hide_settings_page)
	statistics_page.back_requested.connect(_hide_statistics_page)
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
	_setup_motion()


func apply_state(state: StringName, run_seed: int, storage_warning: String, pending_depth: int, player_name: String) -> void:
	var previous_state := _current_state
	var first_state := not _state_applied
	_state_applied = true
	_current_state = state
	var show_menu_shell := state in [RunPhase.MAIN_MENU, RunPhase.GENERATING, RunPhase.LEADERBOARD]
	if state != RunPhase.MAIN_MENU:
		_hide_help_page()
		_hide_settings_page()
		_hide_statistics_page()
	menu_art_background.visible = show_menu_shell
	menu_background.visible = show_menu_shell
	menu_root.visible = show_menu_shell
	title_image.visible = show_menu_shell and state != RunPhase.LEADERBOARD and not statistics_page.visible
	owner_label.visible = show_menu_shell and state != RunPhase.LEADERBOARD and not statistics_page.visible
	status_label.visible = show_menu_shell and state != RunPhase.LEADERBOARD and not statistics_page.visible
	warning_label.visible = show_menu_shell and not storage_warning.is_empty() and not statistics_page.visible
	controls_label.visible = false
	menu_panel.visible = state in [RunPhase.MAIN_MENU, RunPhase.GENERATING] and not help_panel.visible and not settings_panel.visible and not statistics_page.visible
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
	if perk_stack != null:
		perk_stack.visible = is_active_play
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
		clear_perks()

	match state:
		RunPhase.MAIN_MENU:
			status_label.text = "Ready to descend | Seed %d" % run_seed
		RunPhase.GENERATING:
			status_label.text = "Generating run..."
		RunPhase.NAME_ENTRY:
			UiMotion.finish_value(name_entry_status)
			name_entry_status.text = "Depth: %d" % pending_depth
			player_name_input.text = player_name
			player_name_input.grab_focus()
		RunPhase.SUBMITTING, RunPhase.RESULT:
			result_title.text = "Flag Planted"
		RunPhase.DEATH:
			result_title.text = "Run Lost"
	_apply_state_presentation(previous_state, state, first_state, pending_depth)


func dismiss_menu_shell() -> void:
	_hide_help_page()
	_hide_settings_page()
	_hide_statistics_page()
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
	if (help_panel.visible or settings_panel.visible or statistics_page.visible) and (event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed(InputActions.MENU_BACK)):
		if help_panel.visible:
			_hide_help_page()
		elif settings_panel.visible:
			_hide_settings_page()
		else:
			_hide_statistics_page()
		get_viewport().set_input_as_handled()


func _show_help_page() -> void:
	_hide_statistics_page()
	settings_panel.visible = false
	menu_panel.visible = false
	status_label.visible = false
	warning_label.visible = false
	_show_auxiliary_page_shell()
	help_panel.visible = true
	_play_panel_open(help_panel)


func _hide_help_page() -> void:
	if not is_node_ready():
		return
	var was_open := help_panel.visible
	help_panel.visible = false
	_restore_auxiliary_page_parent()
	if was_open:
		_play_page_return()


func _show_settings_page() -> void:
	_hide_statistics_page()
	help_panel.visible = false
	menu_panel.visible = false
	status_label.visible = false
	warning_label.visible = false
	_show_auxiliary_page_shell()
	settings_panel.visible = true
	_play_panel_open(settings_panel)
	settings_requested.emit()


func _hide_settings_page() -> void:
	if not is_node_ready():
		return
	var was_open := settings_panel.visible
	settings_panel.visible = false
	_restore_auxiliary_page_parent()
	if was_open:
		_play_page_return()


## Shows the main-menu statistics page with presentation data prepared by the app root.
func show_statistics(view: StatisticsViewData) -> void:
	help_panel.visible = false
	settings_panel.visible = false
	menu_panel.visible = false
	status_label.visible = false
	warning_label.visible = false
	title_image.visible = false
	owner_label.visible = false
	statistics_page.show_statistics(view)
	statistics_page.visible = true
	statistics_page.focus_default()
	_play_panel_open(statistics_page)


func _hide_statistics_page() -> void:
	if not is_node_ready() or not statistics_page.visible:
		return
	statistics_page.visible = false
	if _current_state == RunPhase.MAIN_MENU:
		title_image.visible = true
		owner_label.visible = true
	_restore_auxiliary_page_parent()
	_play_page_return()


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
	var appeared := visible and not left_touch_pad.visible
	left_touch_pad.visible = visible
	right_touch_pad.visible = visible
	if appeared:
		UiMotion.fade_in(left_touch_pad)
		UiMotion.fade_in(right_touch_pad)
	if not visible:
		left_touch_pad.call(&"reset")
		right_touch_pad.call(&"reset")


func show_generation_progress(progress: float, label: String) -> void:
	status_label.text = "%s %d%%" % [label, int(progress * 100.0)]
	_show_generation_bar(progress)


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


## Updates the generic acquired-perk badge stack when the host scene provides one.
func show_perks(perks: Array) -> void:
	if perk_stack != null:
		perk_stack.show_perks(perks)


func clear_perks() -> void:
	if perk_stack != null:
		perk_stack.clear_perks()


func show_run_status(depth: int, personal_best: int, hooked: bool, item_status: Dictionary) -> void:
	var best_text := "PB:%d" % personal_best if personal_best >= 0 else "PB:-"
	var rope_text := "Hooked" if hooked else "Free"
	play_status_label.text = "Depth %d  |  %s" % [depth, best_text]
	var run_state_text := "Flag in flight" if bool(item_status["flag_in_flight"]) else rope_text
	if run_state_label.text != run_state_text:
		run_state_label.text = run_state_text
		UiMotion.punch(run_state_label)
	_update_depth_feedback(depth, personal_best)
	_update_item_toolbar(item_status.get("items", []))


func _update_item_toolbar(items: Array) -> void:
	var gained_slots := _reconcile_item_toolbar(items)
	for index in items.size():
		var item: Dictionary = items[index]
		var slot := item_toolbar_content.get_child(index) as ItemToolbarSlot
		var selected := bool(item.get("selected", false))
		slot.configure(
			item.get("icon") as Texture2D,
			str(item.get("shortcut", index + 1)),
			str(item.get("count_text", str(roundi(float(item.get("count", 0.0)))))),
			selected,
			float(item.get("count", NAN))
		)
		if selected:
			_show_selection_name_if_changed(str(item.get("name", "Item")))
	for slot in gained_slots:
		slot.play_gained()


## Matches toolbar slots to the items by catalog index so a slot keeps its state while the
## inventory grows or shrinks. Returns the slots of items picked up since the last update.
func _reconcile_item_toolbar(items: Array) -> Array[ItemToolbarSlot]:
	var gained: Array[ItemToolbarSlot] = []
	var unchanged := item_toolbar_content.get_child_count() == items.size()
	if unchanged:
		for index in items.size():
			if int(item_toolbar_content.get_child(index).get_meta(_TOOLBAR_SLOT_KEY, -1)) != _toolbar_key(items, index):
				unchanged = false
				break
	if unchanged:
		return gained
	var reusable := {}
	for child in item_toolbar_content.get_children():
		reusable[int(child.get_meta(_TOOLBAR_SLOT_KEY, -1))] = child
	for index in items.size():
		var key := _toolbar_key(items, index)
		var slot := reusable.get(key) as ItemToolbarSlot
		if slot != null:
			reusable.erase(key)
		else:
			slot = item_toolbar_slot_scene.instantiate() as ItemToolbarSlot
			slot.set_meta(_TOOLBAR_SLOT_KEY, key)
			item_toolbar_content.add_child(slot)
			slot.pressed.connect(_on_item_slot_pressed.bind(key))
			if _toolbar_dealt:
				gained.append(slot)
			else:
				UiMotion.pop_in(slot, UiMotion.config().stagger_delay * index)
		item_toolbar_content.move_child(slot, index)
	for stale: Node in reusable.values():
		stale.free()
	_toolbar_dealt = true
	return gained


func _toolbar_key(items: Array, index: int) -> int:
	return int((items[index] as Dictionary).get("catalog_index", index))


func _clear_item_toolbar() -> void:
	for child in item_toolbar_content.get_children():
		child.free()
	_toolbar_dealt = false


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
	UiMotion.pop_in(selection_name_label)


func _on_selection_name_timeout() -> void:
	UiMotion.fade_out(selection_name_label, selection_name_label.hide)


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
		card.play_deal_in(UiMotion.config().stagger_delay * 1.5 * (index + 1))
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
			_choose_reward(index)
			return true
	return event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed(InputActions.MENU_BACK)


func _on_reward_card_pressed(index: int) -> void:
	_choose_reward(index)


func _choose_reward(index: int) -> void:
	reward_selected.emit(index)
	if _current_state != RunPhase.REWARD_PICKER:
		_play_reward_dismissal(index)


func show_name_error(message: String) -> void:
	UiMotion.finish_value(name_entry_status)
	name_entry_status.text = message
	UiMotion.flash(name_entry_status, UiMotion.config().danger_color)
	UiMotion.shake(player_name_input, UiMotion.config().shake_degrees * 0.3)


func show_result(message: String) -> void:
	result_status.text = message
	if result_panel.visible:
		UiMotion.fade_in(result_status)


func show_leaderboard_loading() -> void:
	leaderboard_status.text = "Loading leaderboard..."
	leaderboard_rows.text = ""


func show_leaderboard(status: String, rows: String, top_user: String = "") -> void:
	leaderboard_status.text = status
	leaderboard_rows.text = rows
	if leaderboard_panel.visible:
		UiMotion.fade_in(leaderboard_rows)
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
	if _current_state in [RunPhase.SUBMITTING, RunPhase.RESULT]:
		_score_was_confirmed = true
		_refresh_record_labels()


func show_submission_result(player_name: String, depth: int, personal_best: int, failed: bool, message: String) -> void:
	var summary := "%s claimed depth %d. Personal best: %d." % [player_name, depth, personal_best]
	show_result(summary + ("\nOnline submit failed: %s" % message if failed else "\nScore submitted."))


# --- Cosmetic motion and feedback -------------------------------------------------------------
# Everything below animates on top of state that the methods above already applied. None of it
# changes visibility rules, emitted intents, or text that gameplay depends on.


func _setup_motion() -> void:
	UiMotion.attach_buttons_in(self)
	_play_status_color = play_status_label.get_theme_color(&"font_color")
	_result_title_color = result_title.get_theme_color(&"font_color")
	var menu_button_style := menu_start_button.get_theme_stylebox(&"normal")
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button.get_theme_stylebox(&"normal") != menu_button_style:
			continue
		var font_color := button.get_theme_color(&"font_color")
		for color_name: StringName in [&"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]:
			if not button.has_theme_color_override(color_name):
				button.add_theme_color_override(color_name, font_color)
		if button_focus_style != null and not button.has_theme_stylebox_override(&"focus"):
			button.add_theme_stylebox_override(&"focus", button_focus_style)


func _apply_state_presentation(previous_state: StringName, state: StringName, first_state: bool, pending_depth: int) -> void:
	var settings := UiMotion.config()
	generation_progress.visible = state == RunPhase.GENERATING
	UiMotion.tint_to(menu_panel, Color(1.0, 1.0, 1.0, settings.generating_menu_alpha if state == RunPhase.GENERATING else 1.0))
	if state not in _ACTIVE_PLAY_STATES:
		_hide_toast()
	if state == RunPhase.GENERATING:
		_reset_run_feedback()
	if state == RunPhase.NAME_ENTRY:
		_pending_depth_is_record = pending_depth > _last_personal_best
		_score_was_confirmed = false
	elif state not in [RunPhase.SUBMITTING, RunPhase.RESULT]:
		_pending_depth_is_record = false
		_score_was_confirmed = false
	_refresh_record_labels()
	result_title.add_theme_color_override(&"font_color", settings.danger_color if state == RunPhase.DEATH else _result_title_color)
	_update_modal_dim(state)
	if state == previous_state and not first_state:
		return

	var was_menu_shell := previous_state in _MENU_SHELL_STATES and not first_state
	match state:
		RunPhase.MAIN_MENU, RunPhase.GENERATING:
			if not was_menu_shell:
				if not first_state:
					_play_curtain()
				_play_menu_intro()
			elif previous_state == RunPhase.LEADERBOARD:
				_play_page_return()
		RunPhase.LEADERBOARD:
			_play_panel_open(leaderboard_panel)
		RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT:
			if previous_state == RunPhase.GENERATING:
				_play_curtain()
				_play_hud_intro()
			elif previous_state not in _ACTIVE_PLAY_STATES:
				_play_hud_return()
		RunPhase.PAUSED:
			_play_panel_open(pause_panel)
			_play_staggered([resume_button, pause_help_button, pause_settings_button, pause_restart_button, pause_menu_button])
		RunPhase.REWARD_PICKER:
			_play_panel_open(reward_picker_panel)
		RunPhase.NAME_ENTRY:
			_play_panel_open(name_entry_panel)
			UiMotion.count_to(name_entry_status, 0, pending_depth, "Depth: %d")
			if name_entry_record_label.visible:
				UiMotion.pop_in(name_entry_record_label, settings.count_up_duration)
			_play_staggered([player_name_input, confirm_score_button])
		RunPhase.DEATH:
			_play_result_intro()
			UiMotion.shake(result_title)
		RunPhase.SUBMITTING, RunPhase.RESULT:
			if previous_state not in _RESULT_STATES:
				_play_result_intro()


func _reset_run_feedback() -> void:
	_clear_item_toolbar()
	_depth_seen = false
	_last_depth = 0
	_deepest_milestone = 0
	_celebrated_personal_best = false
	_set_beyond_personal_best(false)
	UiMotion.finish_value(generation_progress)
	generation_progress.value = 0.0


func _refresh_record_labels() -> void:
	name_entry_record_label.visible = _pending_depth_is_record and _current_state == RunPhase.NAME_ENTRY
	var show_result_record := _pending_depth_is_record and _score_was_confirmed and _current_state in [RunPhase.SUBMITTING, RunPhase.RESULT]
	if show_result_record and not result_record_label.visible:
		result_record_label.visible = true
		UiMotion.pop_in(result_record_label, UiMotion.config().pop_duration)
	else:
		result_record_label.visible = show_result_record


## Dims the world behind modal panels and fades the dim away when play resumes.
func _update_modal_dim(state: StringName) -> void:
	var settings := UiMotion.config()
	var color := settings.modal_dim_color
	var wanted := true
	match state:
		RunPhase.PAUSED, RunPhase.NAME_ENTRY, RunPhase.SUBMITTING, RunPhase.RESULT:
			color = settings.modal_dim_color
		RunPhase.DEATH:
			color = settings.death_dim_color
		RunPhase.REWARD_PICKER:
			color = settings.reward_dim_color
		_:
			wanted = false
	var was_wanted := _modal_dim_wanted
	_modal_dim_wanted = wanted
	if wanted:
		modal_dim.color = color
		modal_dim.visible = true
		if not was_wanted:
			UiMotion.fade_in(modal_dim, 0.0, settings.modal_dim_duration)
	elif state in _MENU_SHELL_STATES:
		UiMotion.stop(modal_dim)
		modal_dim.visible = false
	elif was_wanted:
		UiMotion.fade_out(modal_dim, modal_dim.hide, settings.modal_dim_duration)


## Covers the screen and fades away so a scene swap reads as a cut through darkness.
func _play_curtain() -> void:
	if not UiMotion.can_animate(transition_curtain):
		return
	var settings := UiMotion.config()
	transition_curtain.color = settings.curtain_color
	transition_curtain.visible = true
	UiMotion.fade_out(transition_curtain, transition_curtain.hide, settings.curtain_duration)


func _play_menu_intro() -> void:
	var settings := UiMotion.config()
	UiMotion.pop_in(title_image, 0.0, settings.panel_from_scale)
	UiMotion.fade_in(status_label, settings.stagger_delay)
	UiMotion.fade_in(owner_label, settings.stagger_delay)
	_play_staggered(menu_panel.get_children(), settings.stagger_delay * 2.0)


func _play_hud_intro() -> void:
	var settings := UiMotion.config()
	UiMotion.fade_in(playing_panel, settings.curtain_duration * 0.5)
	UiMotion.pop_in(item_toolbar, settings.curtain_duration * 0.5)
	UiMotion.pop_in(pause_button, settings.curtain_duration * 0.5)


func _play_hud_return() -> void:
	UiMotion.fade_in(playing_panel)
	UiMotion.fade_in(item_toolbar)
	UiMotion.fade_in(hazard_meter_stack)
	UiMotion.pop_in(pause_button)


func _play_panel_open(panel: Control) -> void:
	UiMotion.pop_in(panel, 0.0, UiMotion.config().panel_from_scale)


## Brings back whatever a closed page had replaced: the menu buttons or the pause panel.
func _play_page_return() -> void:
	if pause_panel.is_visible_in_tree():
		_play_panel_open(pause_panel)
	elif menu_panel.is_visible_in_tree():
		_play_staggered(menu_panel.get_children())
		UiMotion.fade_in(status_label)


func _play_result_intro() -> void:
	var settings := UiMotion.config()
	_play_panel_open(result_panel)
	UiMotion.punch(result_title)
	UiMotion.fade_in(result_status, settings.stagger_delay * 2.0)
	_play_staggered([restart_button, result_menu_button], settings.stagger_delay * 3.0)


func _play_staggered(controls: Array, start_delay: float = 0.0) -> void:
	var step := UiMotion.config().stagger_delay
	var shown := 0
	for node: Variant in controls:
		var control := node as Control
		if control == null or not control.visible:
			continue
		UiMotion.pop_in(control, start_delay + step * shown)
		shown += 1


func _show_generation_bar(progress: float) -> void:
	var target := clampf(progress, 0.0, 1.0)
	if target < generation_progress.value:
		UiMotion.finish_value(generation_progress)
		generation_progress.value = target
	else:
		UiMotion.tween_range(generation_progress, target, UiMotion.config().progress_smooth_duration)


## Reacts to the depth readout: a small bump while descending, a toast at each depth
## milestone, and one celebration per run when the player first passes their best depth.
func _update_depth_feedback(depth: int, personal_best: int) -> void:
	_last_personal_best = personal_best
	var previous_depth := _last_depth
	_last_depth = depth
	if not _depth_seen:
		_depth_seen = true
		return
	_set_beyond_personal_best(personal_best > 0 and depth > personal_best)
	if depth <= previous_depth:
		return
	var settings := UiMotion.config()
	@warning_ignore("integer_division")
	var milestone := depth / settings.depth_milestone_interval
	if _beyond_personal_best and not _celebrated_personal_best:
		_celebrated_personal_best = true
		_deepest_milestone = maxi(_deepest_milestone, milestone)
		_show_toast("Deeper than your best!", settings.record_color)
		UiMotion.punch(play_status_label)
	elif milestone > _deepest_milestone:
		_deepest_milestone = milestone
		_show_toast("Depth %d" % (milestone * settings.depth_milestone_interval), _play_status_color)
		UiMotion.punch(play_status_label)
	elif not UiMotion.is_moving(play_status_label):
		UiMotion.punch(play_status_label, settings.depth_bump_scale)


func _set_beyond_personal_best(beyond: bool) -> void:
	if beyond == _beyond_personal_best:
		return
	_beyond_personal_best = beyond
	play_status_label.add_theme_color_override(&"font_color", UiMotion.config().record_color if beyond else _play_status_color)


## Shows a short celebratory line under the hazard meters. Purely cosmetic: without motion
## the readout itself already carries the information.
func _show_toast(text: String, color: Color) -> void:
	if not UiMotion.can_animate(hud_toast):
		return
	_hide_toast()
	hud_toast.text = text
	hud_toast.add_theme_color_override(&"font_color", color)
	hud_toast.visible = true
	UiMotion.pop_in(hud_toast)
	_toast_tween = create_tween()
	_toast_tween.tween_interval(UiMotion.config().toast_hold_duration)
	_toast_tween.tween_callback(UiMotion.fade_out.bind(hud_toast, hud_toast.hide))


func _hide_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	UiMotion.stop(hud_toast)
	hud_toast.visible = false


## Lifts the reward cards out of the closed picker so the chosen one can confirm while the
## others fade. The detached cards ignore input and free themselves.
func _play_reward_dismissal(chosen_index: int) -> void:
	if not UiMotion.can_animate(effects_layer):
		return
	var cards := reward_picker_cards.get_children()
	for index in cards.size():
		var card := cards[index] as RewardPickerCard
		if card == null:
			continue
		UiMotion.stop(card)
		var card_rect := card.get_global_rect()
		reward_picker_cards.remove_child(card)
		effects_layer.add_child(card)
		card.position = card_rect.position
		card.size = card_rect.size
		card.play_dismiss(index == chosen_index)
