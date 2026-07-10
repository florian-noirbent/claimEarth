@tool
## Shared visual tuning for playable runs and static editor world previews.
class_name WorldPresentationConfig
extends Resource


@export_category("Terrain")
@export var terrain_shader: Shader:
	set(value):
		terrain_shader = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var fluid_alpha := 0.56:
	set(value):
		fluid_alpha = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var fluid_caustic_strength := 0.28:
	set(value):
		fluid_caustic_strength = value
		emit_changed()
@export_range(0.001, 0.1, 0.001) var fluid_caustic_scale := 0.012:
	set(value):
		fluid_caustic_scale = value
		emit_changed()
@export_range(0.0, 4.0, 0.01) var fluid_caustic_speed := 0.35:
	set(value):
		fluid_caustic_speed = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var fluid_shimmer_strength := 0.1:
	set(value):
		fluid_shimmer_strength = value
		emit_changed()
@export_range(0.0, 24.0, 0.25) var fluid_surface_glow_width := 5.0:
	set(value):
		fluid_surface_glow_width = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var fluid_surface_glow_strength := 0.35:
	set(value):
		fluid_surface_glow_strength = value
		emit_changed()
@export_range(0.0, 2.0, 0.01) var fluid_hot_glow_strength := 0.65:
	set(value):
		fluid_hot_glow_strength = value
		emit_changed()
@export_range(0.0, 16.0, 0.05) var exposed_edge_corner_radius := 10.0:
	set(value):
		exposed_edge_corner_radius = value
		emit_changed()
@export_range(0.0, 8.0, 0.05) var exposed_edge_jitter_strength := 5.0:
	set(value):
		exposed_edge_jitter_strength = value
		emit_changed()
@export_range(0.02, 0.5, 0.01) var exposed_edge_jitter_scale := 0.12:
	set(value):
		exposed_edge_jitter_scale = value
		emit_changed()

@export_category("Background")
@export var background_shader: Shader:
	set(value):
		background_shader = value
		emit_changed()
@export var cave_texture: Texture2D:
	set(value):
		cave_texture = value
		emit_changed()
@export var cave_texture_scale := 1.0:
	set(value):
		cave_texture_scale = value
		emit_changed()
@export var grass_band_texture: Texture2D:
	set(value):
		grass_band_texture = value
		emit_changed()
@export var grass_band_scale := 0.2:
	set(value):
		grass_band_scale = value
		emit_changed()
@export var grass_band_y_offset := 5.0:
	set(value):
		grass_band_y_offset = value
		emit_changed()
@export_range(0.0, 8.0, 0.5) var grass_band_top_crop_px := 1.0:
	set(value):
		grass_band_top_crop_px = value
		emit_changed()
@export_range(0.0, 8.0, 0.5) var grass_band_bottom_crop_px := 0.0:
	set(value):
		grass_band_bottom_crop_px = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var cave_saturation := 0.9:
	set(value):
		cave_saturation = value
		emit_changed()
@export_range(0.0, 1.5, 0.01) var cave_brightness := 0.85:
	set(value):
		cave_brightness = value
		emit_changed()
@export_range(0.0, 1.5, 0.01) var cave_contrast := 0.78:
	set(value):
		cave_contrast = value
		emit_changed()
@export var cave_tint := Color(0.42, 0.55, 0.62, 1.0):
	set(value):
		cave_tint = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var cave_tint_strength := 0.28:
	set(value):
		cave_tint_strength = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var depth_darkening := 0.28:
	set(value):
		depth_darkening = value
		emit_changed()
@export var depth_darkening_distance := 3200.0:
	set(value):
		depth_darkening_distance = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var side_vignette_strength := 0.22:
	set(value):
		side_vignette_strength = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var side_vignette_inner := 0.42:
	set(value):
		side_vignette_inner = value
		emit_changed()
@export var sky_height := 800.0:
	set(value):
		sky_height = value
		emit_changed()
@export var sky_top_color := Color(0.33, 0.62, 0.92, 1.0):
	set(value):
		sky_top_color = value
		emit_changed()
@export var sky_horizon_color := Color(0.78, 0.88, 0.94, 1.0):
	set(value):
		sky_horizon_color = value
		emit_changed()
@export var sky_gradient_steps := 256:
	set(value):
		sky_gradient_steps = value
		emit_changed()
