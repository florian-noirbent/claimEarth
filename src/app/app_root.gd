class_name AppRoot
extends Control


signal generation_started
signal gameplay_started


@export var generation_delay_seconds := 0.05

@onready var title_label: Label = %Title
@onready var status_label: Label = %Status
@onready var menu_panel: VBoxContainer = %MenuPanel
@onready var menu_start_button: Button = %StartButton
@onready var menu_leaderboard_button: Button = %LeaderboardButton
@onready var playing_panel: VBoxContainer = %PlayingPanel
@onready var play_status_label: Label = %PlayStatus
@onready var back_to_menu_button: Button = %BackToMenuButton

var _run_coordinator := RunCoordinator.new()


func _ready() -> void:
	_run_coordinator.state_changed.connect(_on_state_changed)
	menu_start_button.pressed.connect(_on_start_pressed)
	menu_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_apply_state(_run_coordinator.current_state)
	print("Claim Earth app shell started")


func get_run_state() -> StringName:
	return _run_coordinator.current_state


func transition_to(next_state: StringName) -> void:
	_run_coordinator.transition_to(next_state)


func _on_start_pressed() -> void:
	transition_to(RunPhase.GENERATING)


func _on_leaderboard_pressed() -> void:
	status_label.text = "Leaderboard placeholder - online flow arrives in Step 11."


func _on_back_to_menu_pressed() -> void:
	transition_to(RunPhase.MAIN_MENU)


func _on_state_changed(_previous_state: StringName, next_state: StringName) -> void:
	_apply_state(next_state)


func _apply_state(next_state: StringName) -> void:
	match next_state:
		RunPhase.MAIN_MENU:
			title_label.text = "CLAIM EARTH"
			status_label.text = "Ready to descend"
			menu_panel.visible = true
			playing_panel.visible = false
		RunPhase.GENERATING:
			title_label.text = "CLAIM EARTH"
			status_label.text = "Generating run..."
			menu_panel.visible = true
			playing_panel.visible = false
			generation_started.emit()
			_begin_generation_delay()
		RunPhase.PLAYING:
			title_label.text = "CLAIM EARTH"
			status_label.text = "Run active"
			menu_panel.visible = false
			playing_panel.visible = true
			play_status_label.text = "Gameplay placeholder - terrain, player, and camera land in the next steps."
			gameplay_started.emit()
		_:
			push_error("Unknown run state: %s" % [next_state])


func _begin_generation_delay() -> void:
	await get_tree().create_timer(generation_delay_seconds).timeout
	if _run_coordinator.current_state == RunPhase.GENERATING:
		transition_to(RunPhase.PLAYING)
