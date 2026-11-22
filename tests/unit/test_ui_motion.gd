extends GutTest


const SETTLE_SECONDS := 0.7

var _motion_was_enabled := false


func before_each() -> void:
	_motion_was_enabled = UiMotion.enabled
	UiMotion.enabled = true


func after_each() -> void:
	UiMotion.enabled = _motion_was_enabled


func test_default_config_resource_is_valid_and_snappy() -> void:
	var config := load(UiMotion.DEFAULT_CONFIG_PATH) as UiMotionConfig
	assert_not_null(config)
	assert_eq(config.validate(), PackedStringArray())
	assert_same(UiMotion.config(), config)

	var slow := UiMotionConfig.new()
	slow.pop_duration = 0.9
	slow.button_press_scale = 0.0
	slow.hazard_min_pulse_hz = 9.0
	slow.hazard_max_pulse_hz = 2.0
	assert_eq(slow.validate().size(), 3)


func test_disabled_motion_applies_final_state_immediately() -> void:
	UiMotion.enabled = false
	var label := _add_label("7")
	var bar := ProgressBar.new()
	add_child_autofree(bar)
	label.modulate = Color(1.0, 1.0, 1.0, 0.5)
	var finished := [false]

	UiMotion.pop_in(label)
	UiMotion.punch(label)
	UiMotion.shake(label)
	UiMotion.flash(label, Color.RED)
	UiMotion.count_to(label, 0, 42, "Depth: %d")
	UiMotion.tween_range(bar, 60.0)
	UiMotion.fade_out(label, func() -> void: finished[0] = true)
	UiMotion.tint_to(label, Color(1.0, 1.0, 1.0, 0.25))

	assert_eq(label.scale, Vector2.ONE)
	assert_eq(label.rotation, 0.0)
	assert_eq(label.text, "Depth: 42")
	assert_eq(bar.value, 60.0)
	assert_true(finished[0], "A skipped fade still runs its completion callback.")
	assert_eq(label.modulate, Color(1.0, 1.0, 1.0, 0.25))
	assert_false(UiMotion.is_moving(label))


func test_pop_in_starts_hidden_and_small_then_settles_on_the_resting_modulate() -> void:
	var label := _add_label("Perk")
	var dimmed := Color(1.0, 1.0, 1.0, 0.5)
	label.modulate = dimmed

	UiMotion.pop_in(label)
	assert_eq(label.modulate.a, 0.0)
	assert_lt(label.scale.x, 1.0)
	assert_eq(UiMotion.rest_modulate(label), dimmed)
	assert_true(UiMotion.is_moving(label))

	await wait_seconds(SETTLE_SECONDS)
	assert_eq(label.scale, Vector2.ONE)
	assert_eq(label.modulate, dimmed)
	assert_false(UiMotion.is_moving(label))


func test_interrupted_effects_never_leave_a_partial_transform_or_opacity() -> void:
	var label := _add_label("Slot")
	UiMotion.pop_in(label, 0.2)
	await wait_process_frames(2)
	UiMotion.shake(label)
	await wait_process_frames(2)
	UiMotion.punch(label)
	UiMotion.flash(label, Color(2.0, 2.0, 0.5, 1.0))
	await wait_process_frames(2)
	UiMotion.fade_in(label)
	UiMotion.squash(label)

	UiMotion.stop(label)
	assert_eq(label.scale, Vector2.ONE)
	assert_eq(label.rotation, 0.0)
	assert_eq(label.modulate, Color.WHITE)

	UiMotion.shake(label)
	UiMotion.pop_in(label)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(label.scale, Vector2.ONE)
	assert_eq(label.rotation, 0.0)
	assert_eq(label.modulate, Color.WHITE)


func test_fade_out_hides_then_restores_opacity_and_can_be_cancelled() -> void:
	var label := _add_label("Toast")
	UiMotion.fade_out(label, label.hide)
	await wait_seconds(SETTLE_SECONDS)
	assert_false(label.visible)
	assert_eq(label.modulate, Color.WHITE, "A hidden control is back at rest for its next reveal.")

	label.show()
	var finished := [false]
	UiMotion.fade_out(label, func() -> void: finished[0] = true)
	await wait_process_frames(2)
	UiMotion.fade_in(label)
	await wait_seconds(SETTLE_SECONDS)
	assert_false(finished[0], "A cancelled fade-out must not run its completion callback.")
	assert_eq(label.modulate, Color.WHITE)


func test_set_rest_modulate_wins_over_a_running_fade() -> void:
	var label := _add_label("Card")
	UiMotion.pop_in(label)
	var disabled_tint := Color(0.72, 0.72, 0.72, 1.0)
	UiMotion.set_rest_modulate(label, disabled_tint)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(label.modulate, disabled_tint)


func test_count_and_bar_animations_end_on_their_final_values() -> void:
	var label := _add_label("")
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	add_child_autofree(bar)

	UiMotion.count_to(label, 0, 250, "Depth: %d")
	UiMotion.tween_range(bar, 0.75, -1.0, 0.0, 0.0)
	assert_eq(label.text, "Depth: 0")
	assert_eq(bar.value, 0.0)
	await wait_seconds(UiMotion.config().count_up_duration + 0.3)
	assert_eq(label.text, "Depth: 250")
	assert_almost_eq(bar.value, 0.75, 0.0001)

	UiMotion.count_to(label, 0, 90, "%d")
	UiMotion.tween_range(bar, 0.2)
	await wait_process_frames(2)
	UiMotion.finish_value(label)
	UiMotion.finish_value(bar)
	assert_eq(label.text, "90")
	assert_almost_eq(bar.value, 0.2, 0.0001)


func test_button_response_presses_releases_and_resets_when_hidden() -> void:
	var button := Button.new()
	button.text = "Start"
	add_child_autofree(button)
	UiMotion.attach_button(button)
	UiMotion.attach_button(button)
	assert_eq(button.button_down.get_connections().size(), 1, "Attaching twice must not double the response.")
	var settings := UiMotion.config()

	button.button_down.emit()
	await wait_seconds(settings.button_duration + 0.15)
	assert_almost_eq(button.scale.x, settings.button_press_scale, 0.001)

	button.button_up.emit()
	await wait_seconds(settings.button_duration + 0.15)
	assert_almost_eq(button.scale.x, 1.0, 0.001)

	button.grab_focus()
	await wait_seconds(settings.button_duration + 0.15)
	assert_almost_eq(button.scale.x, settings.button_hover_scale, 0.001)
	assert_gt(button.self_modulate.r, 1.0)

	button.button_down.emit()
	await wait_process_frames(2)
	button.hide()
	assert_eq(button.scale, Vector2.ONE)
	assert_eq(button.self_modulate, Color.WHITE)


func test_effects_on_a_control_outside_the_tree_are_ignored() -> void:
	var detached := Label.new()
	autofree(detached)
	UiMotion.pop_in(detached)
	UiMotion.shake(detached)
	UiMotion.count_to(detached, 0, 5)
	assert_eq(detached.scale, Vector2.ONE)
	assert_eq(detached.modulate, Color.WHITE)
	assert_eq(detached.text, "5")
	assert_false(UiMotion.is_moving(detached))


func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	add_child_autofree(label)
	return label
