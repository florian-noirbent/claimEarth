extends GutTest


func test_no_central_type_branching_patterns_exist_in_src() -> void:
	var forbidden_patterns := [
		RegEx.create_from_string("\\bmatch\\s+.*(terrain|item)"),
		RegEx.create_from_string("==\\s*[A-Za-z0-9_\\.]+(stable_id|display_name)"),
		RegEx.create_from_string("\\bif\\s+.*(terrain_type|item_type|terrain_id|item_id)"),
	]
	var src_files := _gd_files_in("res://src")
	var violations := PackedStringArray()

	for file_path in src_files:
		var text := FileAccess.get_file_as_string(file_path)
		for pattern in forbidden_patterns:
			if pattern.search(text) != null:
				violations.append(file_path)
				break

	assert_eq(violations.size(), 0, "Forbidden branching pattern found in:\n%s" % "\n".join(violations))


func test_runtime_resource_path_loads_do_not_exist_in_src() -> void:
	var forbidden_pattern := RegEx.create_from_string("\\bload\\s*\\(\\s*\"res://")
	var violations := _files_matching(forbidden_pattern)

	assert_eq(violations.size(), 0, "Use exported scene/resource references instead of runtime load paths:\n%s" % "\n".join(violations))


func test_non_script_preloads_do_not_exist_in_src() -> void:
	var forbidden_pattern := RegEx.create_from_string("\\bpreload\\s*\\(\\s*\"res://[^\"]+\\.(tscn|tres|res|png|jpg|jpeg|svg|gdshader)\"\\s*\\)")
	var violations := _files_matching(forbidden_pattern)

	assert_eq(violations.size(), 0, "Use exported scene/resource references instead of non-script preloads:\n%s" % "\n".join(violations))


func test_render_texture_simulation_backend_never_scans_the_full_grid_on_cpu() -> void:
	var backend_path := "res://src/simulation/render_texture_simulation_backend.gd"
	var text := FileAccess.get_file_as_string(backend_path)

	assert_false("_tick_start_bytes" in text, "Simulation ticks must not copy the full packed world for diffing.")
	assert_false("dimensions.cell_count()" in text, "The render-texture backend must not iterate every map cell on the CPU.")
	assert_false("force_draw(" in text, "Simulation passes must use Godot's normal viewport render phase, not force a global redraw.")
	assert_true("request_frame_drawn_callback" in text, "Simulation passes must complete after Godot's normal viewport render phase.")
	assert_true("const RENDER_BANK_COUNT := 2" in text, "Simulation rendering must alternate two texture banks.")
	assert_true("const RENDER_TARGETS_PER_BANK := PASS_COUNT" in text, "Each bank must preserve one target per dependent pass.")


func test_terrain_simulation_clock_is_fixed_rate_and_not_frame_count_driven() -> void:
	var clock_text := FileAccess.get_file_as_string("res://src/simulation/fixed_simulation_pass_clock.gd")
	var controller_text := FileAccess.get_file_as_string("res://src/app/run_world_controller.gd")
	var app_root_text := FileAccess.get_file_as_string("res://src/app/app_root.gd")

	assert_true("const PASSES_PER_SECOND := 60.0" in clock_text)
	assert_true("_simulation_clock.add_time(delta)" in controller_text)
	assert_true("progress.passes_scheduled" in controller_text, "Only backend-accepted work may reduce simulation debt.")
	assert_false("advance(1)" in controller_text, "The controller must not tie one simulation pass to every rendered frame.")
	assert_true("NOTIFICATION_APPLICATION_FOCUS_OUT" in app_root_text)
	assert_true("_session.reset_simulation_clock()" in app_root_text, "Focus loss must discard background-tab simulation time.")


func _files_matching(pattern: RegEx) -> PackedStringArray:
	var violations := PackedStringArray()
	for file_path in _gd_files_in("res://src"):
		var text := FileAccess.get_file_as_string(file_path)
		if pattern.search(text) != null:
			violations.append(file_path)
	return violations


func _gd_files_in(root: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(root)
	if directory == null:
		return result

	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full_path := root.path_join(entry)
		if directory.current_is_dir():
			result.append_array(_gd_files_in(full_path))
		elif entry.ends_with(".gd"):
			result.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()
	return result
