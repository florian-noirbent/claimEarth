@tool
extends VBoxContainer


const PASS_CATALOG_PATH := "res://config/generation/pass_catalog.tres"

var _preview: Control
var _terrain_registry := TerrainRegistry.new()
var _pass_catalog: Resource
var _profile: GenerationProfile
var _selected_pass_index := -1
var _preview_seed := 12345
var _auto_refresh := true
var _preview_enabled := false
var _activation_pending := false
var _loaded_default_profile := false
var _expanded_passes := {}
var _next_preview_should_fit := false

var _file_dialog: Window
var _refresh_timer := Timer.new()
var _profile_path_label := LineEdit.new()
var _seed_input := SpinBox.new()
var _auto_refresh_check := CheckBox.new()
var _pass_type_picker := OptionButton.new()
var _add_pass_button := Button.new()
var _catalog_status_label := Label.new()
var _editor_scroll := ScrollContainer.new()
var _pass_editor_list := VBoxContainer.new()


func _ready() -> void:
	name = "World Gen"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(360.0, 0.0)
	_preview_enabled = Engine.is_editor_hint()
	var terrain_catalog := load("res://config/terrain/catalog.tres") as TerrainCatalog
	_terrain_registry.try_configure(terrain_catalog)
	_build_ui()
	_load_pass_catalog(PASS_CATALOG_PATH)


func set_preview(preview: Control) -> void:
	_preview = preview


func activate() -> void:
	if not _preview_enabled:
		return
	if _profile == null and not _loaded_default_profile:
		_loaded_default_profile = true
		_load_profile("res://config/generation/default_profile.tres")
	_activation_pending = true
	call_deferred("_flush_pending_preview")


func deactivate() -> void:
	_refresh_timer.stop()
	_activation_pending = false


func request_regenerate() -> void:
	_activation_pending = true
	_flush_pending_preview()


func set_profile_for_test(profile: GenerationProfile) -> void:
	_profile = profile
	_selected_pass_index = 0 if _profile != null and not _profile.passes.is_empty() else -1
	_refresh_profile_ui()


func selected_pass_for_test() -> Resource:
	return _selected_pass() if _selected_pass_index >= 0 else null


func add_pass_for_test(pass_script: Script) -> void:
	_add_pass_instance(pass_script.new())


func set_pass_catalog_for_test(catalog: Resource) -> void:
	_apply_pass_catalog(catalog)


func load_pass_catalog_from_path_for_test(path: String) -> void:
	_load_pass_catalog(path)


func set_selected_pass_index_for_test(index: int) -> void:
	_selected_pass_index = clampi(index, -1, _profile.passes.size() - 1) if _profile != null else -1
	_refresh_profile_ui()


func duplicate_selected_pass_for_test() -> void:
	_duplicate_selected_pass()


func move_selected_pass_for_test(direction: int) -> void:
	_move_selected_pass(direction)


func save_profile_to_path_for_test(path: String) -> Error:
	if _profile == null:
		return ERR_INVALID_DATA
	return ResourceSaver.save(_profile, path)


func activation_pending_for_test() -> bool:
	return _activation_pending


func pass_section_count_for_test() -> int:
	return _pass_editor_list.get_child_count()


func pass_section_body_visible_for_test(index: int) -> bool:
	if index < 0 or index >= _pass_editor_list.get_child_count():
		return false
	var section := _pass_editor_list.get_child(index) as VBoxContainer
	return (section.get_meta("body") as Control).visible


func toggle_pass_section_for_test(index: int) -> void:
	if index < 0 or index >= _pass_editor_list.get_child_count():
		return
	var section := _pass_editor_list.get_child(index) as VBoxContainer
	var header_button := section.get_meta("toggle_button") as Button
	header_button.pressed.emit()


func _build_ui() -> void:
	if Engine.is_editor_hint():
		_file_dialog = EditorFileDialog.new()
		(_file_dialog as EditorFileDialog).access = EditorFileDialog.ACCESS_RESOURCES
	else:
		_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	(_file_dialog as FileDialog).add_filter("*.tres", "Generation Profiles")
	(_file_dialog as FileDialog).file_selected.connect(_on_profile_file_selected)
	add_child(_file_dialog)

	_refresh_timer.one_shot = true
	_refresh_timer.wait_time = 0.35
	_refresh_timer.timeout.connect(_flush_pending_preview)
	add_child(_refresh_timer)

	var top_row := HBoxContainer.new()
	add_child(top_row)
	_profile_path_label.editable = false
	_profile_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_profile_path_label)
	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_file_dialog.popup_centered_ratio.bind(0.75))
	top_row.add_child(browse_button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_profile)
	top_row.add_child(save_button)

	var seed_row := HBoxContainer.new()
	add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_row.add_child(seed_label)
	_seed_input.min_value = -2147483648
	_seed_input.max_value = 2147483647
	_seed_input.step = 1
	_seed_input.value = _preview_seed
	_seed_input.value_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_input)
	var regenerate_button := Button.new()
	regenerate_button.text = "Regenerate"
	regenerate_button.pressed.connect(request_regenerate)
	seed_row.add_child(regenerate_button)
	_auto_refresh_check.text = "Auto"
	_auto_refresh_check.button_pressed = _auto_refresh
	_auto_refresh_check.toggled.connect(func(pressed: bool) -> void:
		_auto_refresh = pressed
	)
	seed_row.add_child(_auto_refresh_check)

	var pass_controls := HBoxContainer.new()
	add_child(pass_controls)
	_pass_type_picker.name = "PassTypePicker"
	pass_controls.add_child(_pass_type_picker)
	_add_pass_button.name = "AddPassButton"
	_add_pass_button.text = "Add"
	_add_pass_button.pressed.connect(_add_selected_pass_type)
	pass_controls.add_child(_add_pass_button)
	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(_duplicate_selected_pass)
	pass_controls.add_child(duplicate_button)
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_delete_selected_pass)
	pass_controls.add_child(delete_button)
	var up_button := Button.new()
	up_button.text = "Up"
	up_button.pressed.connect(_move_selected_pass.bind(-1))
	pass_controls.add_child(up_button)
	var down_button := Button.new()
	down_button.text = "Down"
	down_button.pressed.connect(_move_selected_pass.bind(1))
	pass_controls.add_child(down_button)
	_catalog_status_label.name = "CatalogStatusLabel"
	_catalog_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_catalog_status_label.visible = false
	add_child(_catalog_status_label)

	_editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pass_editor_list.name = "PassEditorList"
	_pass_editor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass_editor_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_scroll.add_child(_pass_editor_list)
	add_child(_editor_scroll)


func _load_profile(path: String) -> void:
	var loaded := load(path) as GenerationProfile
	if loaded == null:
		return
	_profile = loaded
	_profile.ensure_pass_seed_keys()
	_profile_path_label.text = _profile.resource_path
	_selected_pass_index = 0 if not _profile.passes.is_empty() else -1
	_refresh_profile_ui()
	_activation_pending = true
	_next_preview_should_fit = true


func _save_profile() -> void:
	if _profile == null or _profile.resource_path.is_empty():
		return
	ResourceSaver.save(_profile, _profile.resource_path)


func _on_profile_file_selected(path: String) -> void:
	_load_profile(path)
	call_deferred("_flush_pending_preview")


func _on_seed_changed(value: float) -> void:
	_preview_seed = int(value)
	_mark_preview_dirty()


func _add_selected_pass_type() -> void:
	var entry := _selected_catalog_entry()
	if entry == null:
		return
	var pass_resource: Resource = entry.instantiate_pass() if entry.has_method("instantiate_pass") else null
	if pass_resource == null:
		return
	_add_pass_instance(pass_resource)


func _add_pass_instance(pass_resource: Resource) -> void:
	if _profile == null:
		return
	_profile.passes.append(pass_resource)
	_selected_pass_index = _profile.passes.size() - 1
	_profile.ensure_pass_seed_keys()
	_refresh_profile_ui()
	_mark_preview_dirty()


func _duplicate_selected_pass() -> void:
	var pass_resource := _selected_pass()
	if pass_resource == null or _profile == null:
		return
	var duplicate_resource: Resource = pass_resource.duplicate_pass() if pass_resource.has_method("duplicate_pass") else pass_resource.duplicate(true)
	_profile.passes.insert(_selected_pass_index + 1, duplicate_resource)
	_selected_pass_index += 1
	_profile.ensure_pass_seed_keys()
	_refresh_profile_ui()
	_mark_preview_dirty()


func _delete_selected_pass() -> void:
	if _profile == null or _selected_pass_index < 0 or _selected_pass_index >= _profile.passes.size():
		return
	_profile.passes.remove_at(_selected_pass_index)
	_selected_pass_index = mini(_selected_pass_index, _profile.passes.size() - 1)
	_refresh_profile_ui()
	_mark_preview_dirty()


func _move_selected_pass(direction: int) -> void:
	if _profile == null or _selected_pass_index < 0:
		return
	var target_index := clampi(_selected_pass_index + direction, 0, _profile.passes.size() - 1)
	if target_index == _selected_pass_index:
		return
	var moved_resource: Resource = _profile.passes.pop_at(_selected_pass_index)
	_profile.passes.insert(target_index, moved_resource)
	_selected_pass_index = target_index
	_refresh_profile_ui()
	_mark_preview_dirty()


func _on_pass_selected(index: int) -> void:
	_selected_pass_index = index
	_refresh_pass_editor()


func _refresh_profile_ui() -> void:
	_refresh_pass_editor()


func _refresh_pass_editor() -> void:
	for child in _pass_editor_list.get_children():
		child.free()
	if _profile == null:
		return
	for index in range(_profile.passes.size()):
		var pass_resource = _profile.passes[index]
		_pass_editor_list.add_child(_build_pass_section(index, pass_resource))


func _build_pass_section(index: int, pass_resource: Resource) -> Control:
	var section := VBoxContainer.new()
	section.name = "PassSection_%d" % index
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(panel)
	var panel_root := VBoxContainer.new()
	panel_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(panel_root)

	var header := HBoxContainer.new()
	panel_root.add_child(header)
	var expanded := bool(_expanded_passes.get(_pass_expand_key(pass_resource), false))
	var toggle_button := Button.new()
	toggle_button.name = "ToggleButton"
	toggle_button.text = _pass_toggle_text(pass_resource, expanded)
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(toggle_button)

	var enabled_check := CheckBox.new()
	enabled_check.text = "On"
	enabled_check.button_pressed = pass_resource.enabled
	enabled_check.toggled.connect(func(pressed: bool) -> void:
		pass_resource.enabled = pressed
		_mark_preview_dirty()
		_refresh_pass_editor()
	)
	header.add_child(enabled_check)

	var up_button := Button.new()
	up_button.text = "Up"
	up_button.pressed.connect(func() -> void:
		_selected_pass_index = index
		_move_selected_pass(-1)
	)
	header.add_child(up_button)
	var down_button := Button.new()
	down_button.text = "Down"
	down_button.pressed.connect(func() -> void:
		_selected_pass_index = index
		_move_selected_pass(1)
	)
	header.add_child(down_button)
	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(func() -> void:
		_selected_pass_index = index
		_duplicate_selected_pass()
	)
	header.add_child(duplicate_button)
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(func() -> void:
		_selected_pass_index = index
		_delete_selected_pass()
	)
	header.add_child(delete_button)

	var body := VBoxContainer.new()
	body.name = "SectionBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.visible = expanded
	panel_root.add_child(body)
	section.set_meta("body", body)
	section.set_meta("toggle_button", toggle_button)
	toggle_button.pressed.connect(func() -> void:
		var next_expanded := not bool(_expanded_passes.get(_pass_expand_key(pass_resource), false))
		_expanded_passes[_pass_expand_key(pass_resource)] = next_expanded
		body.visible = next_expanded
		toggle_button.text = _pass_toggle_text(pass_resource, next_expanded)
	)
	for property_info in pass_resource.get_property_list():
		if not _is_editable_property(property_info):
			continue
		if property_info.name == "allowed_target_ids":
			body.add_child(_build_whitelist_editor(pass_resource))
			continue
		body.add_child(_build_property_editor(pass_resource, property_info))
	return section


func _build_property_editor(pass_resource: Resource, property_info: Dictionary) -> Control:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = property_info.name.capitalize().replace("_", " ")
	row.add_child(label)
	var current_value = pass_resource.get(property_info.name)

	match int(property_info.type):
		TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(current_value)
			check.toggled.connect(func(pressed: bool) -> void:
				pass_resource.set(property_info.name, pressed)
				_refresh_pass_editor()
				_mark_preview_dirty()
			)
			row.add_child(check)
		TYPE_INT, TYPE_FLOAT:
			var slider_row := HBoxContainer.new()
			var slider := HSlider.new()
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var spin := SpinBox.new()
			_apply_range_hint(slider, spin, property_info.hint_string)
			slider.value = float(current_value)
			spin.value = float(current_value)
			slider.value_changed.connect(func(value: float) -> void:
				pass_resource.set(property_info.name, int(value) if property_info.type == TYPE_INT else value)
				spin.value = value
				_mark_preview_dirty()
			)
			spin.value_changed.connect(func(value: float) -> void:
				pass_resource.set(property_info.name, int(value) if property_info.type == TYPE_INT else value)
				slider.value = value
				_mark_preview_dirty()
			)
			slider_row.add_child(slider)
			slider_row.add_child(spin)
			row.add_child(slider_row)
		TYPE_STRING:
			var line_edit := LineEdit.new()
			line_edit.text = String(current_value)
			line_edit.text_changed.connect(func(text: String) -> void:
				pass_resource.set(property_info.name, text)
				_refresh_pass_editor()
				_mark_preview_dirty()
			)
			row.add_child(line_edit)
	return row


func _build_whitelist_editor(pass_resource: Resource) -> Control:
	var container := VBoxContainer.new()
	var label := Label.new()
	label.text = "Allowed Target Terrain"
	container.add_child(label)
	var selected_ids := pass_resource.get("allowed_target_ids") as PackedInt32Array
	for definition in _terrain_registry.all_definitions():
		var check := CheckBox.new()
		check.text = definition.display_name
		check.button_pressed = selected_ids.has(definition.stable_id)
		check.toggled.connect(func(pressed: bool, stable_id := definition.stable_id) -> void:
			var next_ids := pass_resource.get("allowed_target_ids") as PackedInt32Array
			if pressed and not next_ids.has(stable_id):
				next_ids.append(stable_id)
			elif not pressed:
				var remove_index := next_ids.find(stable_id)
				if remove_index >= 0:
					next_ids.remove_at(remove_index)
			pass_resource.set("allowed_target_ids", next_ids)
			_mark_preview_dirty()
		)
		container.add_child(check)
	return container


func _apply_range_hint(slider: HSlider, spin: SpinBox, hint_string: String) -> void:
	var parts := hint_string.split(",")
	if parts.size() >= 2:
		var min_value := float(parts[0])
		var max_value := float(parts[1])
		slider.min_value = min_value
		slider.max_value = max_value
		spin.min_value = min_value
		spin.max_value = max_value
	if parts.size() >= 3:
		var step := float(parts[2])
		slider.step = step
		spin.step = step


func _is_editable_property(property_info: Dictionary) -> bool:
	var usage := int(property_info.usage)
	if (usage & PROPERTY_USAGE_EDITOR) == 0:
		return false
	return property_info.name not in ["script", "resource_name", "resource_path", "resource_local_to_scene"]


func _selected_pass() -> Resource:
	if _profile == null or _selected_pass_index < 0 or _selected_pass_index >= _profile.passes.size():
		return null
	return _profile.passes[_selected_pass_index]


func _pass_title(pass_resource: Resource) -> String:
	var prefix := "[x]" if pass_resource.enabled else "[ ]"
	return "%s %s" % [prefix, _pass_header_title(pass_resource)]


func _pass_toggle_text(pass_resource: Resource, expanded: bool) -> String:
	return "%s %s" % ["[-]" if expanded else "[+]", _pass_title(pass_resource)]


func _pass_expand_key(pass_resource: Resource) -> String:
	return pass_resource.pass_seed_key if not pass_resource.pass_seed_key.is_empty() else pass_resource.get_display_name()


func _pass_header_title(pass_resource: Resource) -> String:
	var label := String(pass_resource.get_display_name())
	var type_name := _pass_type_name(pass_resource)
	if label.is_empty() or label == type_name:
		return type_name
	return "%s (%s)" % [label, type_name]


func _pass_type_name(pass_resource: Resource) -> String:
	var script := pass_resource.get_script() as Script
	if pass_resource.has_method("get_pass_type_name"):
		return String(pass_resource.get_pass_type_name())
	if script != null and not script.resource_path.is_empty():
		return script.resource_path.get_file().trim_suffix(".gd").replace("_", " ").capitalize()
	return String(pass_resource.get_display_name())


func _mark_preview_dirty() -> void:
	if _preview_enabled and _auto_refresh:
		_activation_pending = true
		_refresh_timer.start()


func _flush_pending_preview() -> void:
	if not _activation_pending or not _preview_enabled or _profile == null or _preview == null:
		return
	_activation_pending = false
	_profile.ensure_pass_seed_keys()
	var fit_camera := _next_preview_should_fit
	if _preview.has_method("has_rendered_preview"):
		fit_camera = fit_camera or not _preview.has_rendered_preview()
	_next_preview_should_fit = false
	if _preview.has_method("request_preview"):
		_preview.request_preview(_profile, _preview_seed, fit_camera)
	elif _preview.has_method("generate_preview"):
		_preview.generate_preview(_profile, _preview_seed)


func _load_pass_catalog(path: String) -> void:
	if not ResourceLoader.exists(path):
		_apply_pass_catalog(null)
		_set_catalog_status("Unable to load generation pass catalog: %s" % path)
		return
	var catalog := load(path) as Resource
	_apply_pass_catalog(catalog)
	if catalog == null:
		_set_catalog_status("Unable to load generation pass catalog: %s" % path)
	elif (catalog.get("entries") as Array).is_empty():
		_set_catalog_status("Generation pass catalog is empty.")
	else:
		_set_catalog_status("")


func _apply_pass_catalog(catalog: Resource) -> void:
	_pass_catalog = catalog
	_refresh_pass_picker()


func _refresh_pass_picker() -> void:
	_pass_type_picker.clear()
	if _pass_catalog != null:
		var entries = _pass_catalog.get("entries") as Array
		for entry in entries:
			if entry == null:
				continue
			_pass_type_picker.add_item(entry.get_picker_label() if entry.has_method("get_picker_label") else "Generation Pass")
	var has_entries := _pass_type_picker.item_count > 0
	_pass_type_picker.disabled = not has_entries
	_add_pass_button.disabled = not has_entries
	if has_entries:
		_pass_type_picker.select(0)


func _selected_catalog_entry() -> Resource:
	if _pass_catalog == null:
		return null
	var visible_index := 0
	var entries = _pass_catalog.get("entries") as Array
	for entry in entries:
		if entry == null:
			continue
		if visible_index == _pass_type_picker.selected:
			return entry
		visible_index += 1
	return null


func _set_catalog_status(text: String) -> void:
	_catalog_status_label.text = text
	_catalog_status_label.visible = not text.is_empty()
