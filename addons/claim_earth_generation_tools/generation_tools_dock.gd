@tool
extends VBoxContainer


const PASS_CATALOG_PATH := "res://config/generation/pass_catalog.tres"
const GENERATED_ITEM_CATALOG_PATH := "res://config/generation/item_catalog.tres"
const NO_TERRAIN_ID := 256

var _preview: Control
var _terrain_registry := TerrainRegistry.new()
var _pass_catalog: Resource
var _generated_item_catalog: GeneratedItemPlacementCatalog
var _profile: GenerationProfile
var _saved_profile_snapshot: GenerationProfile
var _saved_pass_values_by_key := {}
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
var _revert_button := Button.new()
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
	_generated_item_catalog = load(GENERATED_ITEM_CATALOG_PATH) as GeneratedItemPlacementCatalog
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
	if _profile != null:
		_profile.ensure_pass_seed_keys()
	if profile != null:
		_saved_profile_snapshot = profile.duplicate(true) as GenerationProfile
	else:
		_saved_profile_snapshot = null
	_capture_saved_pass_values(_profile)
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
	_profile_path_label.tooltip_text = "The generation profile resource currently being edited."
	top_row.add_child(_profile_path_label)
	var browse_button := Button.new()
	browse_button.name = "BrowseProfileButton"
	browse_button.text = "Browse"
	browse_button.tooltip_text = "Load a different generation profile resource from disk."
	browse_button.pressed.connect(_file_dialog.popup_centered_ratio.bind(0.75))
	top_row.add_child(browse_button)
	var save_button := Button.new()
	save_button.name = "SaveProfileButton"
	save_button.text = "Save"
	save_button.tooltip_text = "Save the current profile values back to the selected resource."
	save_button.pressed.connect(_save_profile)
	top_row.add_child(save_button)
	_revert_button.name = "RevertProfileButton"
	_revert_button.text = "Revert"
	_revert_button.tooltip_text = "Restore the profile values from the last saved version on disk."
	_revert_button.disabled = true
	_revert_button.pressed.connect(_revert_profile)
	top_row.add_child(_revert_button)

	var seed_row := HBoxContainer.new()
	add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_label.tooltip_text = "Seed used for the editor preview generation."
	seed_row.add_child(seed_label)
	_seed_input.name = "SeedInput"
	_seed_input.min_value = -2147483648
	_seed_input.max_value = 2147483647
	_seed_input.step = 1
	_seed_input.value = _preview_seed
	_seed_input.tooltip_text = "Change the preview seed to generate another deterministic world layout."
	_seed_input.value_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_input)
	var regenerate_button := Button.new()
	regenerate_button.name = "RegenerateButton"
	regenerate_button.text = "Regenerate"
	regenerate_button.tooltip_text = "Generate the preview again using the current seed and profile settings."
	regenerate_button.pressed.connect(request_regenerate)
	seed_row.add_child(regenerate_button)
	_auto_refresh_check.name = "AutoRefreshCheck"
	_auto_refresh_check.text = "Auto"
	_auto_refresh_check.button_pressed = _auto_refresh
	_auto_refresh_check.tooltip_text = "Automatically refresh the preview shortly after each profile change."
	_auto_refresh_check.toggled.connect(func(pressed: bool) -> void:
		_auto_refresh = pressed
	)
	seed_row.add_child(_auto_refresh_check)

	var pass_controls := HBoxContainer.new()
	add_child(pass_controls)
	_pass_type_picker.name = "PassTypePicker"
	_pass_type_picker.tooltip_text = "Choose which registered pass type to add to the profile."
	pass_controls.add_child(_pass_type_picker)
	_add_pass_button.name = "AddPassButton"
	_add_pass_button.text = "Add"
	_add_pass_button.tooltip_text = "Add a new pass instance of the selected type."
	_add_pass_button.pressed.connect(_add_selected_pass_type)
	pass_controls.add_child(_add_pass_button)
	_catalog_status_label.name = "CatalogStatusLabel"
	_catalog_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_catalog_status_label.visible = false
	_catalog_status_label.tooltip_text = "Status and warnings for loading the registered generation pass catalog."
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
	_profile = loaded.duplicate(true) as GenerationProfile
	_profile.take_over_path(path)
	_saved_profile_snapshot = loaded.duplicate(true) as GenerationProfile
	_profile.ensure_pass_seed_keys()
	_capture_saved_pass_values(_profile)
	_profile_path_label.text = _profile.resource_path
	_selected_pass_index = 0 if not _profile.passes.is_empty() else -1
	_refresh_profile_ui()
	_update_revert_state()
	_activation_pending = true
	_next_preview_should_fit = true


func _save_profile() -> void:
	if _profile == null or _profile.resource_path.is_empty():
		return
	ResourceSaver.save(_profile, _profile.resource_path)
	_saved_profile_snapshot = _profile.duplicate(true) as GenerationProfile
	_capture_saved_pass_values(_profile)
	_update_revert_state()


func _revert_profile() -> void:
	if _profile == null or _saved_profile_snapshot == null:
		return
	var resource_path := _profile.resource_path
	_profile = _saved_profile_snapshot.duplicate(true) as GenerationProfile
	if _profile != null and not resource_path.is_empty():
		_profile.take_over_path(resource_path)
	_profile.ensure_pass_seed_keys()
	_capture_saved_pass_values(_profile)
	_selected_pass_index = 0 if not _profile.passes.is_empty() else -1
	_refresh_profile_ui()
	_update_revert_state()
	_mark_preview_dirty()


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
	_update_revert_state()
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
	_update_revert_state()
	_mark_preview_dirty()


func _delete_selected_pass() -> void:
	if _profile == null or _selected_pass_index < 0 or _selected_pass_index >= _profile.passes.size():
		return
	_profile.passes.remove_at(_selected_pass_index)
	_selected_pass_index = mini(_selected_pass_index, _profile.passes.size() - 1)
	_refresh_profile_ui()
	_update_revert_state()
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
	_update_revert_state()
	_mark_preview_dirty()


func _on_pass_selected(index: int) -> void:
	_selected_pass_index = index
	_refresh_pass_editor()


func _refresh_profile_ui() -> void:
	_refresh_pass_editor()


func _refresh_pass_editor() -> void:
	for child in _pass_editor_list.get_children():
		# This method is also called from pass-header button callbacks.  Detach
		# first and defer destruction so the emitting Control stays valid until
		# Godot has finished dispatching its signal.
		_pass_editor_list.remove_child(child)
		child.queue_free()
	if _profile == null:
		return
	for index in range(_profile.passes.size()):
		var pass_resource = _profile.passes[index]
		_pass_editor_list.add_child(_build_pass_section(index, pass_resource))


func _build_pass_section(index: int, pass_resource: Resource) -> Control:
	var section := VBoxContainer.new()
	section.name = "PassSection_%d" % index
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.set_meta("pass_resource", pass_resource)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(panel)
	var panel_root := VBoxContainer.new()
	panel_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(panel_root)

	var header := HBoxContainer.new()
	panel_root.add_child(header)
	var expanded := bool(_expanded_passes.get(_pass_expand_key(pass_resource), false))
	var enabled_check := CheckBox.new()
	enabled_check.name = "EnabledCheck"
	enabled_check.text = ""
	enabled_check.button_pressed = pass_resource.enabled
	enabled_check.tooltip_text = "Enable or disable this pass without removing it from the stack."
	enabled_check.toggled.connect(func(pressed: bool) -> void:
		pass_resource.enabled = pressed
		_mark_preview_dirty()
		_update_revert_state()
	)
	header.add_child(enabled_check)
	var toggle_button := Button.new()
	toggle_button.name = "ToggleButton"
	toggle_button.text = _pass_toggle_text(pass_resource, expanded)
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_button.tooltip_text = "Expand or collapse this pass settings panel."
	toggle_button.icon = _editor_icon("GuiTreeArrowDown" if expanded else "GuiTreeArrowRight")
	header.add_child(toggle_button)

	var up_button := Button.new()
	up_button.name = "MoveUpButton"
	up_button.icon = _editor_icon("MoveUp")
	up_button.flat = true
	up_button.tooltip_text = "Move this pass earlier in the generation order."
	up_button.pressed.connect(func() -> void:
		_selected_pass_index = index
		_move_selected_pass(-1)
	)
	header.add_child(up_button)
	var down_button := Button.new()
	down_button.name = "MoveDownButton"
	down_button.icon = _editor_icon("MoveDown")
	down_button.flat = true
	down_button.tooltip_text = "Move this pass later in the generation order."
	down_button.pressed.connect(func() -> void:
		_selected_pass_index = index
		_move_selected_pass(1)
	)
	header.add_child(down_button)
	var duplicate_button := Button.new()
	duplicate_button.name = "DuplicateButton"
	duplicate_button.icon = _editor_icon("Duplicate")
	duplicate_button.flat = true
	duplicate_button.tooltip_text = "Duplicate this pass with the same settings."
	duplicate_button.pressed.connect(func() -> void:
		_selected_pass_index = index
		_duplicate_selected_pass()
	)
	header.add_child(duplicate_button)
	var delete_button := Button.new()
	delete_button.name = "DeleteButton"
	delete_button.icon = _editor_icon("Remove")
	delete_button.flat = true
	delete_button.tooltip_text = "Delete this pass from the profile."
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
		toggle_button.icon = _editor_icon("GuiTreeArrowDown" if next_expanded else "GuiTreeArrowRight")
	)
	for property_info in pass_resource.get_property_list():
		if not _is_editable_property(property_info):
			continue
		if property_info.name == "allowed_target_ids":
			body.add_child(_build_whitelist_editor(pass_resource))
			continue
		if property_info.name == "fill_terrain":
			body.add_child(_build_fill_terrain_editor(pass_resource))
			continue
		if property_info.name == "item_definition":
			body.add_child(_build_generated_item_editor(pass_resource))
			continue
		body.add_child(_build_property_editor(pass_resource, property_info))
	return section


func _build_property_editor(pass_resource: Resource, property_info: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.name = "Property_%s" % property_info.name
	row.set_meta("pass_seed_key", String(pass_resource.get("pass_seed_key")))
	row.set_meta("property_name", property_info.name)
	var current_value = pass_resource.get(property_info.name)
	row.set_meta("saved_value", _copy_editor_value(current_value))
	row.tooltip_text = _property_tooltip(property_info.name)
	var label_row := HBoxContainer.new()
	row.add_child(label_row)
	var label := Label.new()
	label.text = property_info.name.capitalize().replace("_", " ")
	label.tooltip_text = row.tooltip_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)
	var reset_button := _build_property_reset_button(pass_resource, property_info.name, "Restore the saved value for this setting.", row)
	label_row.add_child(reset_button)
	if int(property_info.type) == TYPE_INT and int(property_info.hint) == PROPERTY_HINT_ENUM:
		var picker := OptionButton.new()
		picker.name = "ValueOptionButton"
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.tooltip_text = row.tooltip_text
		var options := _enum_options(property_info.hint_string)
		for option_index in range(options.size()):
			picker.add_item(options[option_index], option_index)
		picker.select(int(current_value))
		picker.item_selected.connect(func(selected_index: int) -> void:
			pass_resource.set(property_info.name, selected_index)
			_update_revert_state()
			_update_property_row_state(row, pass_resource)
			_mark_preview_dirty()
		)
		row.add_child(picker)
		return row
	match int(property_info.type):
		TYPE_BOOL:
			var check := CheckBox.new()
			check.name = "ValueCheckBox"
			check.button_pressed = bool(current_value)
			check.tooltip_text = row.tooltip_text
			check.toggled.connect(func(pressed: bool) -> void:
				pass_resource.set(property_info.name, pressed)
				_update_revert_state()
				_update_property_row_state(row, pass_resource)
				_update_pass_section_header(pass_resource)
				_mark_preview_dirty()
			)
			row.add_child(check)
		TYPE_INT, TYPE_FLOAT:
			var slider_row := HBoxContainer.new()
			var slider := HSlider.new()
			slider.name = "ValueSlider"
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var spin := SpinBox.new()
			spin.name = "ValueSpinBox"
			slider.tooltip_text = row.tooltip_text
			spin.tooltip_text = row.tooltip_text
			_apply_range_hint(slider, spin, property_info.hint_string)
			slider.value = float(current_value)
			spin.value = float(current_value)
			slider.value_changed.connect(func(value: float) -> void:
				pass_resource.set(property_info.name, int(value) if property_info.type == TYPE_INT else value)
				spin.value = value
				_update_revert_state()
				_update_property_row_state(row, pass_resource)
				_mark_preview_dirty()
			)
			spin.value_changed.connect(func(value: float) -> void:
				pass_resource.set(property_info.name, int(value) if property_info.type == TYPE_INT else value)
				slider.value = value
				_update_revert_state()
				_update_property_row_state(row, pass_resource)
				_mark_preview_dirty()
			)
			slider_row.add_child(slider)
			slider_row.add_child(spin)
			row.add_child(slider_row)
		TYPE_STRING:
			var line_edit := LineEdit.new()
			line_edit.name = "ValueLineEdit"
			line_edit.text = String(current_value)
			line_edit.tooltip_text = row.tooltip_text
			line_edit.text_changed.connect(func(text: String) -> void:
				pass_resource.set(property_info.name, text)
				_update_revert_state()
				_update_property_row_state(row, pass_resource)
				_update_pass_section_header(pass_resource)
				_mark_preview_dirty()
			)
			row.add_child(line_edit)
	return row


func _build_generated_item_editor(pass_resource: Resource) -> Control:
	var container := VBoxContainer.new()
	container.name = "Property_item_definition"
	container.set_meta("pass_seed_key", String(pass_resource.get("pass_seed_key")))
	container.set_meta("property_name", "item_definition")
	container.set_meta("saved_value", pass_resource.get("item_definition"))
	container.tooltip_text = "Choose the generated item this pass places."
	var label_row := HBoxContainer.new()
	container.add_child(label_row)
	var label := Label.new()
	label.text = "Generated Item"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)
	label_row.add_child(_build_property_reset_button(pass_resource, "item_definition", "Restore the saved generated item.", container))
	var picker := OptionButton.new()
	picker.name = "GeneratedItemOptionButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.tooltip_text = container.tooltip_text
	var current := pass_resource.get("item_definition") as GeneratedItemPlacementDefinition
	if _generated_item_catalog != null:
		for index in _generated_item_catalog.definitions.size():
			var definition := _generated_item_catalog.definitions[index]
			if definition == null:
				continue
			picker.add_item(_generated_item_label(definition), index)
			if definition == current:
				picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(selected_id: int) -> void:
		if _generated_item_catalog == null or selected_id < 0 or selected_id >= _generated_item_catalog.definitions.size():
			return
		pass_resource.set("item_definition", _generated_item_catalog.definitions[selected_id])
		_update_revert_state()
		_update_property_row_state(container, pass_resource)
		_mark_preview_dirty()
	)
	container.add_child(picker)
	return container


func _generated_item_label(definition: GeneratedItemPlacementDefinition) -> String:
	return definition.resource_path.get_file().get_basename().capitalize().replace("_", " ")


func _build_whitelist_editor(pass_resource: Resource) -> Control:
	var container := VBoxContainer.new()
	container.name = "Property_allowed_target_ids"
	container.set_meta("pass_seed_key", String(pass_resource.get("pass_seed_key")))
	container.set_meta("property_name", "allowed_target_ids")
	container.set_meta("saved_value", _copy_editor_value(pass_resource.get("allowed_target_ids")))
	container.tooltip_text = "Restrict this pass to replacing only certain existing terrain types. All means no whitelist."
	var label_row := HBoxContainer.new()
	container.add_child(label_row)
	var label := Label.new()
	label.text = "Allowed Target Terrain"
	label.tooltip_text = container.tooltip_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)
	var reset_button := _build_property_reset_button(pass_resource, "allowed_target_ids", "Restore the saved terrain replacement whitelist for this pass.", container)
	label_row.add_child(reset_button)
	var menu_button := MenuButton.new()
	menu_button.name = "AllowedTargetMenuButton"
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button.tooltip_text = container.tooltip_text
	container.add_child(menu_button)
	_configure_whitelist_menu(menu_button, pass_resource)
	return container


func _build_fill_terrain_editor(pass_resource: Resource) -> Control:
	var container := VBoxContainer.new()
	container.name = "Property_fill_terrain"
	container.set_meta("pass_seed_key", String(pass_resource.get("pass_seed_key")))
	container.set_meta("property_name", "fill_terrain")
	container.set_meta("saved_value", pass_resource.get("fill_terrain"))
	container.tooltip_text = "Choose the terrain type written into this pass's depth band."
	var label_row := HBoxContainer.new()
	container.add_child(label_row)
	var label := Label.new()
	label.text = "Fill Terrain"
	label.tooltip_text = container.tooltip_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)
	var reset_button := _build_property_reset_button(pass_resource, "fill_terrain", "Restore the saved fill terrain.", container)
	label_row.add_child(reset_button)
	var picker := OptionButton.new()
	picker.name = "FillTerrainOptionButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.tooltip_text = container.tooltip_text
	picker.add_item("Select terrain", NO_TERRAIN_ID)
	for definition in _terrain_registry.all_definitions():
		picker.add_item(definition.display_name, definition.stable_id)
	_select_fill_terrain_picker(picker, pass_resource.get("fill_terrain") as TerrainDefinition)
	picker.item_selected.connect(func(selected_index: int) -> void:
		var terrain_id := picker.get_item_id(selected_index)
		pass_resource.set("fill_terrain", _terrain_registry.get_definition(terrain_id))
		_update_revert_state()
		_update_property_row_state(container, pass_resource)
		_mark_preview_dirty()
	)
	container.add_child(picker)
	return container


func _select_fill_terrain_picker(picker: OptionButton, definition: TerrainDefinition) -> void:
	var selected_id := definition.stable_id if definition != null else NO_TERRAIN_ID
	for index in range(picker.item_count):
		if picker.get_item_id(index) == selected_id:
			picker.select(index)
			return
	picker.select(0)


func _configure_whitelist_menu(menu_button: MenuButton, pass_resource: Resource) -> void:
	var popup := menu_button.get_popup()
	popup.clear()
	popup.hide_on_checkable_item_selection = false
	popup.hide_on_item_selection = false
	var selected_ids := pass_resource.get("allowed_target_ids") as PackedInt32Array
	popup.add_check_item("All")
	popup.set_item_checked(0, selected_ids.is_empty())
	if popup.has_meta("whitelist_handler"):
		var previous_handler: Callable = popup.get_meta("whitelist_handler")
		if popup.id_pressed.is_connected(previous_handler):
			popup.id_pressed.disconnect(previous_handler)
	var handler := Callable(self, "_on_whitelist_popup_id_pressed").bind(pass_resource, menu_button)
	popup.set_meta("whitelist_handler", handler)
	popup.id_pressed.connect(handler)
	var menu_index := 1
	for definition in _terrain_registry.all_definitions():
		popup.add_check_item(definition.display_name, definition.stable_id)
		popup.set_item_checked(menu_index, selected_ids.has(definition.stable_id))
		menu_index += 1
	menu_button.text = _whitelist_summary_text(selected_ids)


func _on_whitelist_popup_id_pressed(item_id: int, pass_resource: Resource, menu_button: MenuButton) -> void:
	var next_ids := PackedInt32Array(pass_resource.get("allowed_target_ids"))
	if item_id == -1:
		next_ids = PackedInt32Array()
	else:
		var existing_index := next_ids.find(item_id)
		if existing_index >= 0:
			next_ids.remove_at(existing_index)
		else:
			next_ids.append(item_id)
	pass_resource.set("allowed_target_ids", next_ids)
	_update_revert_state()
	_mark_preview_dirty()
	_configure_whitelist_menu(menu_button, pass_resource)
	_update_property_row_state(menu_button.get_parent() as Control, pass_resource)


func _whitelist_summary_text(selected_ids: PackedInt32Array) -> String:
	if selected_ids.is_empty():
		return "All"
	var names := PackedStringArray()
	for definition in _terrain_registry.all_definitions():
		if selected_ids.has(definition.stable_id):
			names.append(definition.display_name)
	return ", ".join(names)


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
	return _pass_header_title(pass_resource)


func _pass_toggle_text(pass_resource: Resource, expanded: bool) -> String:
	return _pass_title(pass_resource)


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


func _build_property_reset_button(pass_resource: Resource, property_name: String, tooltip: String, row: Control) -> Button:
	var button := Button.new()
	button.name = "Reset_%s" % property_name
	button.flat = true
	button.custom_minimum_size = Vector2(24.0, 24.0)
	button.tooltip_text = tooltip
	button.pressed.connect(func() -> void:
		_reset_property(pass_resource, property_name, row)
	)
	_update_property_reset_button(button, row, pass_resource, property_name)
	return button


func _can_reset_property(pass_resource: Resource, property_name: String) -> bool:
	if pass_resource == null or _saved_profile_snapshot == null:
		return false
	var current_value = pass_resource.get(property_name)
	var saved_value = _saved_pass_value(pass_resource, property_name, current_value)
	return var_to_str(current_value) != var_to_str(saved_value)


func _reset_property(pass_resource: Resource, property_name: String, row: Control) -> void:
	if pass_resource == null:
		return
	var saved_value = _row_saved_value(row, pass_resource.get(property_name))
	pass_resource.set(property_name, saved_value)
	_update_revert_state()
	_sync_property_row_value(row, pass_resource)
	_update_property_row_state(row, pass_resource)
	_update_pass_section_header(pass_resource)
	_mark_preview_dirty()


func _update_property_row_state(row: Control, pass_resource: Resource = null) -> void:
	if row == null:
		return
	var property_name := String(row.get_meta("property_name", ""))
	if pass_resource == null:
		var pass_key := String(row.get_meta("pass_seed_key", ""))
		pass_resource = _pass_resource_for_key(pass_key)
	if pass_resource == null or property_name.is_empty():
		return
	var reset_button := row.find_child("Reset_%s" % property_name, true, false) as Button
	if reset_button != null:
		_update_property_reset_button(reset_button, row, pass_resource, property_name)


func _sync_property_row_value(row: Control, pass_resource: Resource) -> void:
	if row == null or pass_resource == null:
		return
	var property_name := String(row.get_meta("property_name", ""))
	if property_name.is_empty():
		return
	if property_name == "allowed_target_ids":
		var menu_button := row.find_child("AllowedTargetMenuButton", true, false) as MenuButton
		if menu_button != null:
			_configure_whitelist_menu(menu_button, pass_resource)
		return
	if property_name == "fill_terrain":
		var terrain_picker := row.find_child("FillTerrainOptionButton", true, false) as OptionButton
		if terrain_picker != null:
			_select_fill_terrain_picker(terrain_picker, pass_resource.get("fill_terrain") as TerrainDefinition)
		return
	var current_value = pass_resource.get(property_name)
	var value_check := row.find_child("ValueCheckBox", true, false) as CheckBox
	if value_check != null:
		value_check.set_block_signals(true)
		value_check.button_pressed = bool(current_value)
		value_check.set_block_signals(false)
		return
	var value_picker := row.find_child("ValueOptionButton", true, false) as OptionButton
	if value_picker != null:
		value_picker.set_block_signals(true)
		value_picker.select(int(current_value))
		value_picker.set_block_signals(false)
		return
	var value_slider := row.find_child("ValueSlider", true, false) as HSlider
	var value_spin := row.find_child("ValueSpinBox", true, false) as SpinBox
	if value_slider != null and value_spin != null:
		value_slider.set_block_signals(true)
		value_spin.set_block_signals(true)
		value_slider.value = float(current_value)
		value_spin.value = float(current_value)
		value_slider.set_block_signals(false)
		value_spin.set_block_signals(false)
		return
	var value_line_edit := row.find_child("ValueLineEdit", true, false) as LineEdit
	if value_line_edit != null:
		value_line_edit.set_block_signals(true)
		value_line_edit.text = String(current_value)
		value_line_edit.set_block_signals(false)


func _update_pass_section_header(pass_resource: Resource) -> void:
	if pass_resource == null:
		return
	for child in _pass_editor_list.get_children():
		var section := child as Control
		if section == null:
			continue
		if section.get_meta("pass_resource", null) != pass_resource:
			continue
		var toggle_button := section.find_child("ToggleButton", true, false) as Button
		if toggle_button != null:
			toggle_button.text = _pass_toggle_text(pass_resource, (section.find_child("SectionBody", true, false) as Control).visible)
		return


func _update_property_reset_button(button: Button, row: Control, pass_resource: Resource, property_name: String) -> void:
	if button == null:
		return
	var saved_value = _row_saved_value(row, pass_resource.get(property_name))
	var can_reset := var_to_str(pass_resource.get(property_name)) != var_to_str(saved_value)
	button.icon = _editor_icon("Reload")
	button.disabled = not can_reset
	button.modulate = Color(1.0, 1.0, 1.0, 1.0 if can_reset else 0.0)


func _row_saved_value(row: Control, fallback):
	if row == null or not row.has_meta("saved_value"):
		return fallback
	return _copy_editor_value(row.get_meta("saved_value"))


func _copy_editor_value(value):
	return str_to_var(var_to_str(value))


func _enum_options(hint_string: String) -> PackedStringArray:
	var result := PackedStringArray()
	for option in hint_string.split(",", false):
		var normalized_option := option.strip_edges()
		if normalized_option.contains(":"):
			normalized_option = normalized_option.get_slice(":", 0).strip_edges()
		result.append(normalized_option)
	return result


func _saved_pass_value(pass_resource: Resource, property_name: String, fallback):
	if pass_resource == null:
		return fallback
	var target_key := String(pass_resource.get("pass_seed_key"))
	if target_key.is_empty():
		return fallback
	var saved_values: Dictionary = _saved_pass_values_by_key.get(target_key, {})
	if saved_values.has(property_name):
		return saved_values[property_name]
	var saved_pass := _saved_pass_resource(pass_resource)
	if saved_pass == null:
		return fallback
	return saved_pass.get(property_name)


func _saved_pass_resource(pass_resource: Resource) -> Resource:
	if _saved_profile_snapshot == null or pass_resource == null:
		return null
	var target_key := String(pass_resource.get("pass_seed_key"))
	if target_key.is_empty():
		return null
	for saved_pass in _saved_profile_snapshot.passes:
		if saved_pass != null and String(saved_pass.get("pass_seed_key")) == target_key:
			return saved_pass
	return null


func _pass_resource_for_key(pass_key: String) -> Resource:
	if _profile == null or pass_key.is_empty():
		return null
	for pass_resource in _profile.passes:
		if pass_resource != null and String(pass_resource.get("pass_seed_key")) == pass_key:
			return pass_resource
	return null


func _capture_saved_pass_values(source_profile: GenerationProfile) -> void:
	_saved_pass_values_by_key.clear()
	if source_profile == null:
		return
	for saved_pass in source_profile.passes:
		if saved_pass == null:
			continue
		var pass_key := String(saved_pass.get("pass_seed_key"))
		if pass_key.is_empty():
			continue
		var values := {}
		for property_info in saved_pass.get_property_list():
			if not _is_editable_property(property_info):
				continue
			values[property_info.name] = saved_pass.get(property_info.name)
		_saved_pass_values_by_key[pass_key] = values


func _update_revert_state() -> void:
	if _revert_button == null:
		return
	_revert_button.disabled = _profile == null or _saved_profile_snapshot == null or _profiles_match(_profile, _saved_profile_snapshot)


func _profiles_match(left: GenerationProfile, right: GenerationProfile) -> bool:
	if left == null or right == null:
		return left == right
	var left_passes := left.passes.duplicate(true)
	var right_passes := right.passes.duplicate(true)
	for pass_resource in left_passes:
		if pass_resource != null:
			pass_resource.set("pass_seed_key", "")
	for pass_resource in right_passes:
		if pass_resource != null:
			pass_resource.set("pass_seed_key", "")
	var left_data := var_to_str({
		"width": left.width,
		"depth": left.depth,
		"spawn_width": left.spawn_width,
		"spawn_height": left.spawn_height,
		"spawn_margin_top": left.spawn_margin_top,
		"passes": left_passes,
	})
	var right_data := var_to_str({
		"width": right.width,
		"depth": right.depth,
		"spawn_width": right.spawn_width,
		"spawn_height": right.spawn_height,
		"spawn_margin_top": right.spawn_margin_top,
		"passes": right_passes,
	})
	return left_data == right_data


func _property_tooltip(property_name: String) -> String:
	match property_name:
		"enabled":
			return "Enable or disable this pass without removing it from the stack."
		"label":
			return "Custom label shown in the pass list. The pass type is still shown separately."
		"pass_seed_key":
			return "Stable per-pass seed key used to keep deterministic randomness when passes are reordered."
		"min_depth_ratio":
			return "Top of the depth band where this pass may apply. 0 is the surface and 1 is the bottom."
		"max_depth_ratio":
			return "Bottom of the depth band where this pass may apply. 0 is the surface and 1 is the bottom."
		"top_blend_distance_ratio":
			return "Soft fade distance inward from the top edge of the targeted depth band. Zero keeps the top edge fully applied."
		"bottom_blend_distance_ratio":
			return "Soft fade distance inward from the bottom edge of the targeted depth band. Zero keeps the bottom edge fully applied."
		"allowed_target_ids":
			return "Restrict this pass to replacing only certain existing terrain types. All means no whitelist."
		"octaves":
			return "Number of noise layers combined together. Higher values add finer detail."
		"frequency_x":
			return "Horizontal noise frequency. Higher values create tighter horizontal features."
		"frequency_y":
			return "Vertical noise frequency. Higher values create tighter vertical features."
		"gain":
			return "How strongly each successive noise octave contributes."
		"cave_threshold":
			return "Threshold below which the base noise carves air pockets."
		"dirt_threshold":
			return "Threshold above which the base noise keeps denser stone instead of dirt."
		"placement_threshold":
			return "Minimum noise value required to place this hazard type."
		"hazard_type":
			return "Choose which terrain type this hazard pocket pass places."
		"fill_terrain":
			return "Terrain type written into every allowed cell in this pass's depth band."
		"item_definition":
			return "Generated world-item definition placed by this pass. Add another pass instance for another item kind."
		"area_columns":
			return "Number of vertical map slices used for independent item spawn areas."
		"area_height_rows":
			return "Height in hex rows of each independent item spawn area."
		"column_vertical_offset_rows":
			return "Cumulative row offset that staggers adjacent columns diagonally."
		"area_spawn_chance":
			return "Independent deterministic chance for each grid area to spawn its configured item."
	return "Edit this generation setting for the selected pass."


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


func _editor_icon(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	return get_theme_icon(icon_name, "EditorIcons")
