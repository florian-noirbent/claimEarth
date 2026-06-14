class_name AppUiController
extends CanvasLayer


signal start_requested
signal leaderboard_requested
signal menu_requested
signal score_confirmed(player_name: String)
signal restart_requested

@onready var title_label: Label = %Title
@onready var owner_label: Label = %OwnerLabel
@onready var status_label: Label = %Status
@onready var warning_label: Label = %WarningLabel
@onready var controls_label: Label = %ControlsLabel
@onready var menu_background: ColorRect = $Background
@onready var menu_root: CenterContainer = $Center
@onready var menu_panel: VBoxContainer = %MenuPanel
@onready var menu_start_button: Button = %StartButton
@onready var menu_leaderboard_button: Button = %LeaderboardButton
@onready var overlay_root: MarginContainer = %OverlayRoot
@onready var playing_panel: VBoxContainer = %PlayingPanel
@onready var play_status_label: Label = %PlayStatus
@onready var hint_label: Label = %HintLabel
@onready var back_to_menu_button: Button = %BackToMenuButton
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
@onready var leaderboard_panel: PanelContainer = %LeaderboardPanel
@onready var leaderboard_status: Label = %LeaderboardStatus
@onready var leaderboard_rows: RichTextLabel = %LeaderboardRows
@onready var leaderboard_back_button: Button = %LeaderboardBackButton


func _ready() -> void:
	menu_start_button.pressed.connect(start_requested.emit)
	menu_leaderboard_button.pressed.connect(leaderboard_requested.emit)
	back_to_menu_button.pressed.connect(menu_requested.emit)
	result_menu_button.pressed.connect(menu_requested.emit)
	leaderboard_back_button.pressed.connect(menu_requested.emit)
	restart_button.pressed.connect(restart_requested.emit)
	confirm_score_button.pressed.connect(func() -> void:
		score_confirmed.emit(player_name_input.text)
	)
	controls_label.text = "Plant the deepest flag to claim Earth (3).\nUse small bombs (1), large bombs (2), and your grappling hook (RMB)."
	owner_label.text = "Earth owned by: Nobody yet"


func apply_state(state: StringName, seed: int, storage_warning: String, pending_depth: int, player_name: String) -> void:
	var show_menu_shell := state in [RunPhase.MAIN_MENU, RunPhase.GENERATING, RunPhase.LEADERBOARD]
	menu_background.visible = show_menu_shell
	menu_root.visible = show_menu_shell
	title_label.visible = show_menu_shell and state != RunPhase.LEADERBOARD
	owner_label.visible = show_menu_shell and state != RunPhase.LEADERBOARD
	status_label.visible = show_menu_shell and state != RunPhase.LEADERBOARD
	warning_label.visible = show_menu_shell and not storage_warning.is_empty()
	controls_label.visible = show_menu_shell and state == RunPhase.MAIN_MENU
	menu_panel.visible = state in [RunPhase.MAIN_MENU, RunPhase.GENERATING]
	overlay_root.visible = state in [
		RunPhase.PLAYING,
		RunPhase.FLAG_IN_FLIGHT,
		RunPhase.NAME_ENTRY,
		RunPhase.PAUSED,
		RunPhase.SUBMITTING,
		RunPhase.DEATH,
		RunPhase.RESULT,
	]
	playing_panel.visible = state in [RunPhase.PLAYING, RunPhase.FLAG_IN_FLIGHT, RunPhase.PAUSED]
	name_entry_panel.visible = state == RunPhase.NAME_ENTRY
	result_panel.visible = state in [RunPhase.SUBMITTING, RunPhase.DEATH, RunPhase.RESULT]
	pause_panel.visible = state == RunPhase.PAUSED
	leaderboard_panel.visible = state == RunPhase.LEADERBOARD
	warning_label.text = storage_warning

	match state:
		RunPhase.MAIN_MENU:
			title_label.text = "CLAIM EARTH"
			status_label.text = "Ready to descend | Seed %d" % seed
		RunPhase.GENERATING:
			title_label.text = "CLAIM EARTH"
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
	menu_background.visible = false
	menu_root.visible = false
	title_label.visible = false
	owner_label.visible = false
	status_label.visible = false
	warning_label.visible = false


func show_generation_progress(progress: float, label: String) -> void:
	status_label.text = "%s %d%%" % [label, int(progress * 100.0)]


func show_play_status(status_text: String, hint_text: String) -> void:
	play_status_label.text = status_text
	hint_label.text = hint_text


func show_name_error(message: String) -> void:
	name_entry_status.text = message


func show_result(message: String) -> void:
	result_status.text = message


func show_leaderboard_loading() -> void:
	leaderboard_status.text = "Loading leaderboard..."
	leaderboard_rows.text = ""


func show_leaderboard(status: String, rows: String, owner: String = "") -> void:
	leaderboard_status.text = status
	leaderboard_rows.text = rows
	if not owner.is_empty():
		owner_label.text = owner
