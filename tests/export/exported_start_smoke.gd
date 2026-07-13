## Verifies that the exported pack can load the application and start a playable run.
## Run through tools/smoke_exported_game.ps1 so res:// resolves from the exported PCK.
extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"
const START_BUTTON_PATH := NodePath("UiLayer/Center/Content/MenuPanel/StartButton")
const PLAYING_STATE := &"playing"
const TIMEOUT_MSEC := 5000

var _app_root: Node
var _generation_started := false
var _gameplay_started := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_resource := ResourceLoader.load(MAIN_SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not scene_resource is PackedScene:
		_fail("Could not load exported main scene: %s" % MAIN_SCENE_PATH, 2)
		return

	_app_root = (scene_resource as PackedScene).instantiate()
	if _app_root == null:
		_fail("Could not instantiate exported main scene.", 3)
		return
	if not _app_root.has_method("set_test_mode") or not _app_root.has_method("get_run_state"):
		_fail("Exported main scene does not expose the AppRoot smoke-test contract.", 3)
		return
	if not _app_root.has_signal("generation_started") or not _app_root.has_signal("gameplay_started"):
		_fail("Exported AppRoot is missing run lifecycle signals.", 3)
		return

	_app_root.call("set_test_mode", true)
	if _app_root.has_method("configure_save_path_for_test"):
		_app_root.call("configure_save_path_for_test", "user://exported_start_smoke_save.json")
	if _app_root.has_method("configure_settings_path_for_test"):
		_app_root.call("configure_settings_path_for_test", "user://exported_start_smoke_settings.json")
	_app_root.connect("generation_started", _on_generation_started)
	_app_root.connect("gameplay_started", _on_gameplay_started)
	root.add_child(_app_root)
	await process_frame

	var start_button := _app_root.get_node_or_null(START_BUTTON_PATH) as Button
	if start_button == null:
		_fail("Could not find the exported main menu Start button.", 4)
		return
	if start_button.disabled or not start_button.is_visible_in_tree():
		_fail("The exported main menu Start button is not actionable.", 4)
		return

	start_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _generation_started and _gameplay_started and _app_root.call("get_run_state") == PLAYING_STATE:
			print("EXPORTED_START_SMOKE_OK")
			quit()
			return
		await process_frame

	var state: Variant = _app_root.call("get_run_state")
	_fail(
		"Timed out starting exported game: state=%s, generation_started=%s, gameplay_started=%s"
		% [state, _generation_started, _gameplay_started],
		5
	)


func _on_generation_started() -> void:
	_generation_started = true


func _on_gameplay_started() -> void:
	_gameplay_started = true


func _fail(message: String, exit_code: int) -> void:
	push_error("EXPORTED_START_SMOKE_FAILED: %s" % message)
	quit(exit_code)
