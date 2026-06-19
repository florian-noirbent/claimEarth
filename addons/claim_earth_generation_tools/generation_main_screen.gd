@tool
extends PanelContainer


const GenerationPreviewScript = preload("res://addons/claim_earth_generation_tools/generation_preview.gd")
const GenerationToolsPanelScript = preload("res://addons/claim_earth_generation_tools/generation_tools_dock.gd")

var _workspace_built := false
var _active := false
var _layout: MarginContainer
var _split: HSplitContainer
var _preview_host: VBoxContainer
var _side_panel_host: PanelContainer
var _hint: Label
var _preview
var _tools_panel


func _ready() -> void:
	name = "World Gen"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_shell()


func activate() -> void:
	_active = true
	if not _workspace_built:
		_build_workspace()
	if _preview != null:
		_preview.activate()
	if _tools_panel != null:
		_tools_panel.activate()


func deactivate() -> void:
	_active = false
	if _tools_panel != null:
		_tools_panel.deactivate()
	if _preview != null:
		_preview.deactivate()


func _build_shell() -> void:
	_layout = MarginContainer.new()
	_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("margin_left", 12)
	_layout.add_theme_constant_override("margin_top", 12)
	_layout.add_theme_constant_override("margin_right", 12)
	_layout.add_theme_constant_override("margin_bottom", 12)
	add_child(_layout)

	_split = HSplitContainer.new()
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.split_offset = 920
	_layout.add_child(_split)

	_preview_host = VBoxContainer.new()
	_preview_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_preview_host)

	_hint = Label.new()
	_hint.text = "Middle mouse drag to pan. Mouse wheel to zoom."
	_preview_host.add_child(_hint)

	_side_panel_host = PanelContainer.new()
	_side_panel_host.custom_minimum_size = Vector2(360.0, 0.0)
	_side_panel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_side_panel_host)


func _build_workspace() -> void:
	_workspace_built = true
	_preview = GenerationPreviewScript.new()
	_preview.name = "GenerationPreview"
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_host.add_child(_preview)

	_tools_panel = GenerationToolsPanelScript.new()
	_tools_panel.name = "GenerationToolsPanel"
	_tools_panel.set_preview(_preview)
	_tools_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_panel_host.add_child(_tools_panel)
