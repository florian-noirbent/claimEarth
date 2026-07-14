@tool
extends Control


const WorldPresenterScript = preload("res://src/presentation/world_presenter.gd")
const WorldBackgroundScript = preload("res://src/presentation/world_background.gd")
const WorldPresentationConfigResource = preload("res://config/presentation/default_world_presentation.tres")

var _subviewport: SubViewport
var _subviewport_container: SubViewportContainer
var _root: Node2D
var _camera: Camera2D
var _presenter
var _background: WorldBackground
var _status_label := Label.new()
var _terrain_registry := TerrainRegistry.new()
var _current_profile: GenerationProfile
var _current_seed := 0
var _pending_preview_request := false
var _pending_camera_fit := false
var _is_active := false
var _has_rendered_once := false
var _dragging := false
var _active_request_count := 0
const CAMERA_FIT_PADDING := 1.35


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_shell()
	set_process(false)
	_set_status("No profile")


func activate() -> void:
	_is_active = true
	_ensure_runtime()
	set_process(true)
	if _current_profile != null and not _has_rendered_once:
		_pending_preview_request = true
		_pending_camera_fit = true
		_set_status("Generating")
	_attempt_preview()


func deactivate() -> void:
	_is_active = false
	set_process(false)
	_dragging = false
	_pending_preview_request = false
	_pending_camera_fit = false
	if _current_profile != null:
		_has_rendered_once = false
	_free_runtime()
	if _current_profile == null:
		_set_status("No profile")
	else:
		_set_status("Preview paused")


func request_preview(profile: GenerationProfile, run_seed: int, fit_camera := false) -> void:
	_current_profile = profile
	_current_seed = run_seed
	_pending_preview_request = profile != null
	_pending_camera_fit = fit_camera
	if profile == null:
		_has_rendered_once = false
	_set_status("No profile" if profile == null else "Generating")
	if _is_active:
		_ensure_runtime()
		_attempt_preview()


func has_rendered_preview() -> bool:
	return _has_rendered_once




func _process(_delta: float) -> void:
	if _pending_preview_request:
		_attempt_preview()
	elif _pending_camera_fit:
		_attempt_camera_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_viewport()
		if _pending_preview_request and _is_active:
			_attempt_preview()
		elif _pending_camera_fit and _is_active:
			_attempt_camera_fit()


func _gui_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mouse_event.pressed
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_apply_zoom(1.1)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_apply_zoom(1.0 / 1.1)
	elif event is InputEventMouseMotion and _dragging:
		var motion_event := event as InputEventMouseMotion
		var zoom_scale := maxf(_camera.zoom.x, 0.05)
		_camera.position -= motion_event.relative / zoom_scale


func _build_shell() -> void:
	var background := PanelContainer.new()
	background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(background)

	var overlay := MarginContainer.new()
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(overlay)

	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_status_label)


func _ensure_runtime() -> void:
	if _subviewport_container != null:
		_resize_viewport()
		return
	_subviewport_container = SubViewportContainer.new()
	_subviewport_container.name = "PreviewViewportContainer"
	_subviewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subviewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_subviewport_container.stretch = false
	add_child(_subviewport_container)
	move_child(_subviewport_container, 0)

	_subviewport = SubViewport.new()
	_subviewport.disable_3d = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.transparent_bg = false
	_subviewport_container.add_child(_subviewport)

	_root = Node2D.new()
	_root.name = "PreviewRoot"
	_subviewport.add_child(_root)
	_background = WorldBackgroundScript.new()
	_background.name = "WorldBackground"
	_background.presentation_config = WorldPresentationConfigResource
	_root.add_child(_background)
	_presenter = WorldPresenterScript.new()
	_presenter.name = "WorldPresenter"
	_presenter.presentation_config = WorldPresentationConfigResource
	_root.add_child(_presenter)
	_camera = Camera2D.new()
	_camera.name = "PreviewCamera"
	_camera.enabled = true
	_camera.position_smoothing_enabled = false
	_root.add_child(_camera)
	_resize_viewport()


func _free_runtime() -> void:
	if _subviewport_container != null:
		_subviewport_container.queue_free()
	_subviewport_container = null
	_subviewport = null
	_root = null
	_camera = null
	_presenter = null
	_background = null


func _attempt_preview() -> void:
	if not _is_active or not _pending_preview_request or _current_profile == null:
		return
	if size.x <= 4.0 or size.y <= 4.0:
		return
	_ensure_runtime()
	var terrain_catalog := load("res://config/terrain/catalog.tres") as TerrainCatalog
	if not _terrain_registry.try_configure(terrain_catalog):
		_set_status("Generation failed")
		push_error("\n".join(_terrain_registry.validation_errors))
		return
	_pending_preview_request = false
	_active_request_count += 1
	_set_status("Generating")
	_presenter.reset()
	_presenter.set_force_full_brightness(true)
	var generator := WorldGenerator.new()
	var result := generator.generate(_current_profile, _terrain_registry, _current_seed)
	if result == null:
		_set_status("Generation failed")
		return
	_presenter.visible_row_count = result.world.dimensions.depth
	_configure_background_bounds(result.world)
	_presenter.configure(result.world, _terrain_registry)
	_has_rendered_once = true
	_attempt_camera_fit()
	_set_status("")


func _resize_viewport() -> void:
	if _subviewport != null:
		_subviewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))


func _apply_zoom(multiplier: float) -> void:
	if _camera == null:
		return
	_camera.zoom *= Vector2(multiplier, multiplier)
	_camera.zoom.x = clampf(_camera.zoom.x, 0.05, 10.0)
	_camera.zoom.y = clampf(_camera.zoom.y, 0.05, 10.0)


func _attempt_camera_fit() -> void:
	if not _pending_camera_fit or _camera == null or _current_profile == null:
		return
	var viewport_size := _subviewport.size if _subviewport != null else Vector2i.ZERO
	if viewport_size.x <= 32 or viewport_size.y <= 32:
		return
	_refresh_camera_fit()
	_pending_camera_fit = false


func _fit_camera(profile: GenerationProfile) -> void:
	if _camera == null or _presenter == null:
		return
	var left_edge: float = HexMetrics.center_for_offset(0, 0, _presenter.hex_radius).x - _presenter.hex_radius
	var right_edge: float = HexMetrics.center_for_offset(profile.width - 1, 0, _presenter.hex_radius).x + _presenter.hex_radius
	var top_edge: float = HexMetrics.center_for_offset(0, 0, _presenter.hex_radius).y - _presenter.hex_radius
	var bottom_edge: float = HexMetrics.center_for_offset(0, profile.depth - 1, _presenter.hex_radius).y + _presenter.hex_radius
	var world_size := Vector2(maxf(1.0, right_edge - left_edge), maxf(1.0, bottom_edge - top_edge))
	var viewport_size := Vector2(maxf(1.0, float(_subviewport.size.x)), maxf(1.0, float(_subviewport.size.y))) if _subviewport != null else Vector2(maxf(1.0, size.x), maxf(1.0, size.y))
	var zoom_factor: float = minf(viewport_size.x / world_size.x, viewport_size.y / world_size.y) / CAMERA_FIT_PADDING
	zoom_factor = clampf(zoom_factor, 0.05, 10.0)
	_camera.zoom = Vector2(zoom_factor, zoom_factor)
	_camera.position = Vector2((left_edge + right_edge) * 0.5, (top_edge + bottom_edge) * 0.5)


func _configure_background_bounds(world: WorldGrid) -> void:
	if _background == null or _presenter == null:
		return
	var left_edge: float = HexMetrics.center_for_offset(0, 0, _presenter.hex_radius).x - _presenter.hex_radius
	var right_edge: float = HexMetrics.center_for_offset(world.dimensions.width - 1, 0, _presenter.hex_radius).x + _presenter.hex_radius
	var bottom_edge: float = HexMetrics.center_for_offset(0, world.dimensions.depth - 1, _presenter.hex_radius).y + _presenter.hex_radius
	_background.configure_bounds(left_edge, right_edge, 0.0, bottom_edge)


func _refresh_camera_fit() -> void:
	if _current_profile != null:
		_fit_camera(_current_profile)


func _set_status(text: String) -> void:
	_status_label.text = text
	_status_label.visible = not text.is_empty()
