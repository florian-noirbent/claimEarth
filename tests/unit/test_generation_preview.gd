extends GutTest


const GenerationPreviewScript = preload("res://addons/claim_earth_generation_tools/generation_preview.gd")


func _default_profile() -> GenerationProfile:
	return load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile


func _status_label(preview: Control) -> Label:
	return preview.find_child("StatusLabel", true, false) as Label


func _camera(preview: Control) -> Camera2D:
	return preview.find_child("PreviewCamera", true, false) as Camera2D


func _subviewport(preview: Control) -> SubViewport:
	return preview._subviewport as SubViewport


func _presenter(preview: Control):
	return preview._presenter


func test_preview_request_while_inactive_is_queued() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1200, 800)
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345)

	assert_true(preview._pending_preview_request)
	assert_false(preview._has_rendered_once)


func test_preview_activates_only_after_size_is_valid() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345)
	preview.activate()
	await wait_process_frames(2)
	assert_true(preview._pending_preview_request)
	assert_false(preview._has_rendered_once)

	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	preview.size = Vector2(900, 700)
	await wait_process_frames(2)

	assert_false(preview._pending_preview_request)
	assert_true(preview._has_rendered_once)
	assert_eq(_status_label(preview).text, "")


func test_preview_resize_updates_viewport_when_growing_and_shrinking() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	preview.size = Vector2(900, 700)
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345)
	preview.activate()
	await wait_process_frames(2)

	var initial_size := _subviewport(preview).size
	preview.size = Vector2(640, 480)
	await wait_process_frames(1)
	var smaller_size := _subviewport(preview).size
	preview.size = Vector2(960, 720)
	await wait_process_frames(1)
	var larger_size := _subviewport(preview).size

	assert_lt(smaller_size.x, initial_size.x)
	assert_lt(smaller_size.y, initial_size.y)
	assert_gt(larger_size.x, smaller_size.x)
	assert_gt(larger_size.y, smaller_size.y)


func test_preview_resize_preserves_camera_center_and_zoom() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	preview.size = Vector2(900, 700)
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345)
	preview.activate()
	await wait_process_frames(2)
	_camera(preview).zoom = Vector2(2.0, 2.0)
	var before_position := _camera(preview).position
	var before_zoom := _camera(preview).zoom.x

	preview.size = Vector2(640, 480)
	await wait_process_frames(1)

	assert_eq(_camera(preview).zoom.x, before_zoom)
	assert_eq(_camera(preview).position, before_position)


func test_preview_regenerate_preserves_camera_center_and_zoom() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	preview.size = Vector2(900, 700)
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345, true)
	preview.activate()
	await wait_process_frames(3)
	_camera(preview).zoom = Vector2(2.0, 2.0)
	var before_position := Vector2(250.0, 400.0)
	_camera(preview).position = before_position
	var before_zoom := _camera(preview).zoom.x

	preview.request_preview(_default_profile(), 12345, false)
	await wait_process_frames(3)

	assert_eq(_camera(preview).zoom.x, before_zoom)
	assert_eq(_camera(preview).position, before_position)


func test_preview_successful_generation_configures_presenter_and_reactivation_rerenders_once() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	preview.size = Vector2(900, 700)
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345)
	preview.activate()
	await wait_process_frames(2)
	var request_count: int = preview._active_request_count

	assert_true(preview._has_rendered_once)
	assert_gt(_presenter(preview).visible_chunk_count(), 0)
	assert_lt(_camera(preview).zoom.x, 1.0)

	preview.deactivate()
	preview.activate()
	await wait_process_frames(2)

	assert_true(preview._has_rendered_once)
	assert_eq(preview._active_request_count, request_count + 1)


func test_preview_wheel_up_increases_zoom_value_and_wheel_down_decreases_it() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	preview.size = Vector2(900, 700)
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345)
	preview.activate()
	await wait_process_frames(2)
	_camera(preview).zoom = Vector2(1.0, 1.0)
	var initial_zoom := _camera(preview).zoom.x
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	preview._gui_input(wheel_up)
	var wheel_up_zoom := _camera(preview).zoom.x
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	preview._gui_input(wheel_down)
	var wheel_down_zoom := _camera(preview).zoom.x

	assert_gt(wheel_up_zoom, initial_zoom)
	assert_lt(wheel_down_zoom, wheel_up_zoom)


func test_preview_drag_scales_with_zoom_level() -> void:
	var host := Control.new()
	host.custom_minimum_size = Vector2(1200, 800)
	host.size = Vector2(1200, 800)
	add_child_autofree(host)
	var preview = GenerationPreviewScript.new()
	preview.size = Vector2(900, 700)
	host.add_child(preview)
	await wait_process_frames(1)

	preview.request_preview(_default_profile(), 12345)
	preview.activate()
	await wait_process_frames(2)
	var drag_start := InputEventMouseButton.new()
	drag_start.button_index = MOUSE_BUTTON_MIDDLE
	drag_start.pressed = true
	preview._gui_input(drag_start)

	_camera(preview).zoom = Vector2(0.5, 0.5)
	var initial_position := _camera(preview).position
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10.0, 0.0)
	preview._gui_input(motion)
	var zoomed_out_delta := absf(_camera(preview).position.x - initial_position.x)

	_camera(preview).zoom = Vector2(2.0, 2.0)
	initial_position = _camera(preview).position
	preview._gui_input(motion)
	var zoomed_in_delta := absf(_camera(preview).position.x - initial_position.x)

	assert_gt(zoomed_out_delta, zoomed_in_delta)
