class_name ScenarioDriver
extends RefCounted


static func press_action_for_physics_frames(action_name: String, frame_count: int) -> void:
	Input.action_press(action_name)
	for _index in range(frame_count):
		await Engine.get_main_loop().process_frame
	Input.action_release(action_name)


static func press_action_until(action_name: String, predicate: Callable, max_frames: int) -> bool:
	Input.action_press(action_name)
	for _index in range(max_frames):
		await Engine.get_main_loop().process_frame
		if predicate.call():
			Input.action_release(action_name)
			return true
	Input.action_release(action_name)
	return false


static func set_mouse_world_position(target: Node, global_position: Vector2) -> void:
	if target.get_viewport() == null:
		return
	target.get_viewport().warp_mouse(target.get_viewport().get_canvas_transform() * global_position)


static func wait_process_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await Engine.get_main_loop().process_frame


static func wait_physics_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await Engine.get_main_loop().physics_frame
