extends GutTest


func test_transition_emits_state_changed_once() -> void:
	var coordinator := RunCoordinator.new()
	watch_signals(coordinator)

	coordinator.transition_to(RunPhase.GENERATING)

	assert_signal_emitted(coordinator, "state_changed")
	assert_eq(coordinator.current_state, RunPhase.GENERATING)


func test_repeating_same_state_does_not_emit() -> void:
	var coordinator := RunCoordinator.new()
	watch_signals(coordinator)

	coordinator.transition_to(RunPhase.MAIN_MENU)

	assert_signal_not_emitted(coordinator, "state_changed")
