extends GutTest


const GenerationToolsDockScript = preload("res://addons/claim_earth_generation_tools/generation_tools_dock.gd")
const GenerationPassCatalogScript = preload("res://src/generation/generation_pass_catalog.gd")
const GenerationPassCatalogEntryScript = preload("res://src/generation/generation_pass_catalog_entry.gd")
const BaseNoisePassScript = preload("res://src/generation/base_noise_pass.gd")
const PocketNoisePassScript = preload("res://src/generation/pocket_noise_pass.gd")


class PreviewStub extends Control:
	var call_count := 0
	var last_profile: GenerationProfile
	var last_seed := 0
	var last_fit_camera := false
	var has_rendered := false

	func request_preview(profile: GenerationProfile, run_seed: int, fit_camera := false) -> void:
		call_count += 1
		last_profile = profile
		last_seed = run_seed
		last_fit_camera = fit_camera
		has_rendered = true

	func has_rendered_preview() -> bool:
		return has_rendered


func _catalog_entry(label: String, pass_script: Script) -> Resource:
	var entry := GenerationPassCatalogEntryScript.new()
	entry.label = label
	entry.pass_script = pass_script
	return entry


func _catalog(entries: Array) -> Resource:
	var catalog := GenerationPassCatalogScript.new()
	catalog.entries = entries
	return catalog


func _pass_picker(dock: Control) -> OptionButton:
	return dock.find_child("PassTypePicker", true, false) as OptionButton


func _add_pass_button(dock: Control) -> Button:
	return dock.find_child("AddPassButton", true, false) as Button


func _catalog_status_label(dock: Control) -> Label:
	return dock.find_child("CatalogStatusLabel", true, false) as Label


func _pass_editor_list(dock: Control) -> VBoxContainer:
	return dock.find_child("PassEditorList", true, false) as VBoxContainer


func _pass_section(dock: Control, index: int) -> VBoxContainer:
	return dock.find_child("PassSection_%d" % index, true, false) as VBoxContainer


func _pass_body(dock: Control, index: int) -> Control:
	var section := _pass_section(dock, index)
	return section.find_child("SectionBody", true, false) as Control if section != null else null


func _pass_toggle_button(dock: Control, index: int) -> Button:
	var section := _pass_section(dock, index)
	return section.find_child("ToggleButton", true, false) as Button if section != null else null


func _picker_labels(dock: Control) -> PackedStringArray:
	var labels := PackedStringArray()
	var picker := _pass_picker(dock)
	for index in range(picker.item_count):
		labels.append(picker.get_item_text(index))
	return labels


func test_generation_tools_dock_adds_duplicates_and_reorders_passes() -> void:
	var dock = GenerationToolsDockScript.new()
	add_child_autofree(dock)
	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Base Noise", BaseNoisePassScript),
		_catalog_entry("Pocket Noise", PocketNoisePassScript),
	]))
	dock.set_profile_for_test(GenerationProfile.new())

	dock.add_pass_for_test(BaseNoisePassScript)
	dock.add_pass_for_test(PocketNoisePassScript)
	dock.set_selected_pass_index_for_test(0)
	dock.duplicate_selected_pass_for_test()
	dock.move_selected_pass_for_test(1)

	var profile := dock._profile as GenerationProfile
	assert_eq(profile.passes.size(), 3)
	assert_eq(profile.passes[0].get_display_name(), "Base Noise")
	assert_eq(profile.passes[1].get_display_name(), "Pocket Noise")
	assert_eq(profile.passes[2].get_display_name(), "Base Noise")
	assert_eq(_pass_editor_list(dock).get_child_count(), 3)
	assert_false(_pass_body(dock, 0).visible)
	assert_false(_pass_body(dock, 1).visible)
	assert_false(_pass_body(dock, 2).visible)


func test_generation_tools_dock_saves_whitelist_round_trip() -> void:
	var dock = GenerationToolsDockScript.new()
	add_child_autofree(dock)
	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Pocket Noise", PocketNoisePassScript),
	]))
	var profile := GenerationProfile.new()
	dock.set_profile_for_test(profile)
	dock.add_pass_for_test(PocketNoisePassScript)
	var save_path := "user://gut_generation_tools_profile.tres"

	var pass_resource := dock.selected_pass_for_test()
	pass_resource.set("allowed_target_ids", PackedInt32Array([1, 2]))
	var save_error := dock.save_profile_to_path_for_test(save_path)
	var reloaded := load(save_path) as GenerationProfile

	assert_eq(save_error, OK)
	assert_not_null(reloaded)
	assert_eq((reloaded.passes[0].get("allowed_target_ids") as PackedInt32Array).size(), 2)

	pass_resource = null
	reloaded = null
	profile = null
	await wait_process_frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func test_generation_tools_dock_activate_flushes_pending_preview() -> void:
	var root := Control.new()
	root.custom_minimum_size = Vector2(1200, 800)
	add_child_autofree(root)
	var preview := PreviewStub.new()
	preview.custom_minimum_size = Vector2(800, 600)
	root.add_child(preview)
	var dock = GenerationToolsDockScript.new()
	root.add_child(dock)
	await wait_process_frames(1)

	var profile := GenerationProfile.new()
	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Base Noise", BaseNoisePassScript),
	]))
	dock.set_profile_for_test(profile)
	dock._preview = preview
	dock._preview_enabled = true
	dock._activation_pending = true
	dock.activate()
	await wait_process_frames(1)

	assert_eq(preview.call_count, 1)
	assert_same(preview.last_profile, profile)
	assert_eq(preview.last_seed, 12345)


func test_generation_tools_dock_request_regenerate_uses_latest_seed() -> void:
	var root := Control.new()
	root.custom_minimum_size = Vector2(1200, 800)
	add_child_autofree(root)
	var preview := PreviewStub.new()
	preview.custom_minimum_size = Vector2(800, 600)
	root.add_child(preview)
	var dock = GenerationToolsDockScript.new()
	root.add_child(dock)
	await wait_process_frames(1)

	var profile := GenerationProfile.new()
	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Base Noise", BaseNoisePassScript),
	]))
	dock.set_profile_for_test(profile)
	dock._preview = preview
	dock._preview_enabled = true
	dock._preview_seed = 6789
	dock.request_regenerate()

	assert_eq(preview.call_count, 1)
	assert_same(preview.last_profile, profile)
	assert_eq(preview.last_seed, 6789)


func test_generation_tools_dock_auto_refresh_coalesces_pending_preview() -> void:
	var root := Control.new()
	root.custom_minimum_size = Vector2(1200, 800)
	add_child_autofree(root)
	var preview := PreviewStub.new()
	preview.custom_minimum_size = Vector2(800, 600)
	root.add_child(preview)
	var dock = GenerationToolsDockScript.new()
	root.add_child(dock)
	await wait_process_frames(1)

	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Base Noise", BaseNoisePassScript),
	]))
	dock.set_profile_for_test(GenerationProfile.new())
	dock._preview = preview
	dock._preview_enabled = true
	dock._mark_preview_dirty()
	dock._mark_preview_dirty()
	await wait_seconds(0.4)
	await wait_process_frames(1)

	assert_eq(preview.call_count, 1)
	assert_false(dock.activation_pending_for_test())


func test_generation_tools_dock_toggle_expands_in_place_without_rebuilding_sections() -> void:
	var dock = GenerationToolsDockScript.new()
	add_child_autofree(dock)
	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Base Noise", BaseNoisePassScript),
		_catalog_entry("Pocket Noise", PocketNoisePassScript),
	]))
	dock.set_profile_for_test(GenerationProfile.new())
	dock.add_pass_for_test(BaseNoisePassScript)
	dock.add_pass_for_test(PocketNoisePassScript)
	await wait_process_frames(1)

	assert_eq(_pass_editor_list(dock).get_child_count(), 2)
	assert_false(_pass_body(dock, 0).visible)
	assert_false(_pass_body(dock, 1).visible)

	_pass_toggle_button(dock, 0).pressed.emit()

	assert_eq(_pass_editor_list(dock).get_child_count(), 2)
	assert_true(_pass_body(dock, 0).visible)
	assert_false(_pass_body(dock, 1).visible)


func test_generation_tools_dock_uses_catalog_order_for_picker_and_adds_selected_type() -> void:
	var dock = GenerationToolsDockScript.new()
	add_child_autofree(dock)
	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Pocket Noise", PocketNoisePassScript),
		_catalog_entry("Base Noise", BaseNoisePassScript),
	]))
	dock.set_profile_for_test(GenerationProfile.new())

	assert_eq(_picker_labels(dock), PackedStringArray(["Pocket Noise", "Base Noise"]))

	_pass_picker(dock).select(1)
	dock._add_selected_pass_type()

	assert_same(dock.selected_pass_for_test().get_script(), BaseNoisePassScript)


func test_generation_tools_dock_empty_or_missing_catalog_disables_add_without_crashing() -> void:
	var dock = GenerationToolsDockScript.new()
	add_child_autofree(dock)
	dock.set_profile_for_test(GenerationProfile.new())

	dock.set_pass_catalog_for_test(_catalog([]))
	assert_eq(_picker_labels(dock).size(), 0)
	assert_true(_add_pass_button(dock).disabled)

	dock._add_selected_pass_type()
	assert_eq((dock._profile as GenerationProfile).passes.size(), 0)

	dock.load_pass_catalog_from_path_for_test("res://config/generation/missing_pass_catalog.tres")
	assert_true(_add_pass_button(dock).disabled)
	assert_true(_catalog_status_label(dock).text.contains("Unable to load generation pass catalog"))


func test_generation_tools_dock_pass_header_shows_label_and_type() -> void:
	var dock = GenerationToolsDockScript.new()
	add_child_autofree(dock)
	dock.set_pass_catalog_for_test(_catalog([
		_catalog_entry("Base Noise", BaseNoisePassScript),
	]))
	dock.set_profile_for_test(GenerationProfile.new())
	dock.add_pass_for_test(BaseNoisePassScript)
	dock.add_pass_for_test(BaseNoisePassScript)
	var first_pass: Resource = dock._profile.passes[0]
	first_pass.label = "Base Terrain"
	var second_pass: Resource = dock._profile.passes[1]
	second_pass.label = ""
	dock._refresh_profile_ui()

	assert_true(_pass_toggle_button(dock, 0).text.contains("Base Terrain (Base Noise)"))
	assert_true(_pass_toggle_button(dock, 1).text.contains("[+] [x] Base Noise"))
