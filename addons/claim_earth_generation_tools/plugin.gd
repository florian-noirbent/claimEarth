@tool
extends EditorPlugin


const GenerationMainScreenScript = preload("res://addons/claim_earth_generation_tools/generation_main_screen.gd")

var _main_screen


func _enter_tree() -> void:
	_main_screen = GenerationMainScreenScript.new()
	get_editor_interface().get_editor_main_screen().add_child(_main_screen)
	_make_visible(false)


func _exit_tree() -> void:
	if _main_screen != null:
		if _main_screen.has_method("deactivate"):
			_main_screen.deactivate()
		_main_screen.queue_free()
		_main_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _main_screen != null:
		_main_screen.visible = visible
		if visible and _main_screen.has_method("activate"):
			_main_screen.call_deferred("activate")
		elif not visible and _main_screen.has_method("deactivate"):
			_main_screen.deactivate()


func _get_plugin_name() -> String:
	return "World Gen"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Node2D", "EditorIcons")
