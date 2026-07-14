## Debug-build-only F3 overlay and shortcut router.
class_name DeveloperToolsController
extends CanvasLayer

var app: AppRoot
var panel := PanelContainer.new()
var readout := Label.new()
var item_buttons := VBoxContainer.new()

func configure(value: AppRoot) -> void:
	app = value
	panel.visible = false
	panel.position = Vector2(24, 90)
	panel.custom_minimum_size = Vector2(330, 0)
	var box := VBoxContainer.new()
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(readout)
	for data in [["Teleport 75%", _teleport_deep], ["Clear objects", _clear_objects]]:
		var button := Button.new(); button.text = data[0]; button.pressed.connect(data[1]); box.add_child(button)
	box.add_child(HSeparator.new())
	box.add_child(item_buttons)
	panel.add_child(box); add_child(panel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		panel.visible = not panel.visible
		if panel.visible: _refresh()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	readout.text = "DEV TOOLS\nSeed %d | Depth %d\nF3 closes" % [app._current_seed, HexMetrics.offset_for_world(app.get_player().global_position, app.world_presenter.hex_radius).y] if app.get_player() != null else "DEV TOOLS\nStart a run first."
	for child in item_buttons.get_children(): child.queue_free()
	if app.item_controller == null: return
	for data in app.item_controller.debug_item_picker_data():
		var button := Button.new(); button.text = "Grant %s" % data.name; button.pressed.connect(_grant_item.bind(data.index)); item_buttons.add_child(button)

func _grant_item(index: int) -> void: if app.item_controller != null: app.item_controller.debug_grant_item(index)
func _teleport_deep() -> void: if app.world_controller != null: app.world_controller.debug_teleport_to_fraction(0.75)
func _clear_objects() -> void: if app.item_controller != null: app.item_controller.debug_clear_world_items()
