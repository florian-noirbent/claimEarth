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
