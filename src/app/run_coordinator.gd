class_name RunCoordinator
extends RefCounted


signal state_changed(previous_state: StringName, next_state: StringName)


var current_state: StringName = RunPhase.MAIN_MENU


func transition_to(next_state: StringName) -> void:
	if current_state == next_state:
		return

	var previous_state := current_state
	current_state = next_state
	state_changed.emit(previous_state, next_state)
