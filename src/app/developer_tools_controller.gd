## Debug-build-only F3 overlay and shortcut router.
class_name DeveloperToolsController
extends CanvasLayer

var app: AppRoot
var panel := PanelContainer.new()
var readout := Label.new()
var categories := VBoxContainer.new()
var submenu := VBoxContainer.new()
var submenu_scroll := ScrollContainer.new()
var _groups: Array[Dictionary] = []
var _selected_group := 0

func configure(value: AppRoot) -> void:
	app = value
	panel.visible = false
	panel.position = Vector2(24, 88)
	panel.custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(readout)
	box.add_child(HSeparator.new())
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 12)
	categories.custom_minimum_size = Vector2(170, 0)
	submenu.custom_minimum_size = Vector2(300, 0)
	submenu_scroll.custom_minimum_size = Vector2(320, 440)
	submenu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	submenu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panes.add_child(categories)
	panes.add_child(VSeparator.new())
	submenu_scroll.add_child(submenu)
	panes.add_child(submenu_scroll)
	box.add_child(panes)
	panel.add_child(box); add_child(panel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		panel.visible = not panel.visible
		if panel.visible: _refresh()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	readout.text = "DEV TOOLS\nSeed %d | Depth %d\nF3 closes" % [app._current_seed, HexMetrics.offset_for_world(app.get_player().global_position, app.world_presenter.hex_radius).y] if app.get_player() != null else "DEV TOOLS\nStart a run first."
	_groups.clear()
	_add_action_group("Teleport", [
		["25%", _teleport.bind(0.25)],
		["50%", _teleport.bind(0.5)],
		["75%", _teleport.bind(0.75)],
	])
	if app.item_controller != null:
		var item_actions: Array = []
		for data in app.item_controller.debug_item_picker_data():
			item_actions.append([str(data.name), _grant_item.bind(int(data.index))])
		_add_action_group("Grant item", item_actions)
		_add_action_group("Objects", [["Clear world objects", _clear_objects]])
	if app.perk_controller != null:
		var perk_actions: Array = []
		for data in app.perk_controller.debug_perk_picker_data():
			perk_actions.append([str(data.name), _grant_perk.bind(int(data.stable_id))])
		_add_action_group("Grant perk", perk_actions)
	_selected_group = clampi(_selected_group, 0, maxi(0, _groups.size() - 1))
	_rebuild_category_pane()
	_show_group(_selected_group)


func _add_action_group(title: String, entries: Array) -> void:
	_groups.append({"title": title, "entries": entries})


func _rebuild_category_pane() -> void:
	for child in categories.get_children():
		child.queue_free()
	for index in _groups.size():
		var group := _groups[index]
		var button := Button.new()
		button.text = "%s  ›" % String(group.title)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = index == _selected_group
		button.pressed.connect(_show_group.bind(index))
		categories.add_child(button)


func _show_group(index: int) -> void:
	if index < 0 or index >= _groups.size():
		return
	_selected_group = index
	for child in submenu.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = String(_groups[index].title)
	heading.add_theme_font_size_override("font_size", 16)
	submenu.add_child(heading)
	for entry in _groups[index].entries:
		var button := Button.new()
		button.text = str(entry[0])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(entry[1])
		submenu.add_child(button)
	for category_index in categories.get_child_count():
		(categories.get_child(category_index) as Button).button_pressed = category_index == index

func _grant_item(index: int) -> void: if app.item_controller != null: app.item_controller.debug_grant_item(index)
func _grant_perk(stable_id: int) -> void:
	if app.perk_controller != null:
		app.perk_controller.debug_grant_perk(stable_id)
		_refresh()
func _teleport(fraction: float) -> void: if app.world_controller != null: app.world_controller.debug_teleport_to_fraction(fraction)
func _clear_objects() -> void: if app.item_controller != null: app.item_controller.debug_clear_world_items()
