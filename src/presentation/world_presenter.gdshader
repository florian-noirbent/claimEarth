shader_type canvas_item;

uniform sampler2D world_data : filter_nearest;
uniform sampler2D style_data : filter_nearest;
uniform sampler2D terrain_properties : filter_nearest;
uniform sampler2D edge_style_data : filter_nearest;
uniform sampler2D material_atlas : filter_linear;
uniform float hex_radius = 16.0;
uniform vec2 world_size = vec2(1.0, 1.0);
uniform float edge_width_normalization = 16.0;
uniform int material_atlas_columns = 1;
uniform float material_atlas_tile_size = 1024.0;
uniform float material_atlas_gutter_size = 1.0;
uniform vec2 material_atlas_size = vec2(1.0, 1.0);
uniform float fluid_alpha = 0.56;
uniform float fluid_caustic_strength = 0.28;
uniform float fluid_caustic_scale = 0.012;
uniform float fluid_caustic_speed = 0.35;
uniform float fluid_shimmer_strength = 0.1;
uniform float fluid_surface_glow_width = 5.0;
uniform float fluid_surface_glow_strength = 0.35;
uniform float fluid_hot_glow_strength = 0.65;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

vec3 cube_round(vec3 cube) {
	vec3 rounded = floor(cube + vec3(0.5));
	vec3 diff = abs(rounded - cube);
	if (diff.x > diff.y && diff.x > diff.z) {
		rounded.x = -rounded.y - rounded.z;
	} else if (diff.y > diff.z) {
		rounded.y = -rounded.x - rounded.z;
	} else {
		rounded.z = -rounded.x - rounded.y;
	}
	return rounded;
}

vec2 world_to_offset(vec2 position) {
	float q = (2.0 / 3.0 * position.x) / hex_radius;
	float r = ((-1.0 / 3.0 * position.x) + (1.7320508 / 3.0 * position.y)) / hex_radius;
	vec3 rounded = cube_round(vec3(q, r, -q - r));
	float col = rounded.x;
	float parity = mod(abs(col), 2.0);
	float row = rounded.y + (col - parity) * 0.5;
	return vec2(col, row);
}

vec2 center_for_offset(vec2 cell) {
	float parity = mod(abs(cell.x), 2.0);
	return vec2(
		hex_radius * 1.5 * cell.x,
		hex_radius * 1.7320508 * (cell.y + parity * 0.5)
	);
}

bool inside_hex(vec2 local) {
	float half_height = hex_radius * 1.7320508 * 0.5;
	float ax = abs(local.x);
	float ay = abs(local.y);
	if (ax > hex_radius || ay > half_height) {
		return false;
	}
	if (ax <= hex_radius * 0.5) {
		return true;
	}
	return ay <= 1.7320508 * (hex_radius - ax);
}

float fill_line_y(float fill_amount) {
	float half_height = hex_radius * 1.7320508 * 0.5;
	return mix(half_height, -half_height, fill_amount);
}

float edge_distance(vec2 local, int side) {
	float half_height = hex_radius * 1.7320508 * 0.5;
	float diagonal_limit = hex_radius * 1.7320508;
	if (side == 0) {
		return (diagonal_limit - (1.7320508 * local.x + local.y)) * 0.5;
	}
	if (side == 1) {
		return half_height - local.y;
	}
	if (side == 2) {
		return (diagonal_limit - (-1.7320508 * local.x + local.y)) * 0.5;
	}
	if (side == 3) {
		return (diagonal_limit - (-1.7320508 * local.x - local.y)) * 0.5;
	}
	if (side == 4) {
		return local.y + half_height;
	}
	return (diagonal_limit - (1.7320508 * local.x - local.y)) * 0.5;
}

int nearest_edge(vec2 local, out float distance_to_edge) {
	int nearest = 0;
	distance_to_edge = edge_distance(local, 0);
	for (int side = 1; side < 6; side++) {
		float candidate = edge_distance(local, side);
		if (candidate < distance_to_edge) {
			distance_to_edge = candidate;
			nearest = side;
		}
	}
	return nearest;
}

vec2 neighbor_for_edge(vec2 cell, int side) {
	float parity = mod(abs(cell.x), 2.0);
	if (side == 0) {
		return cell + vec2(1.0, parity);
	}
	if (side == 1) {
		return cell + vec2(0.0, 1.0);
	}
	if (side == 2) {
		return cell + vec2(-1.0, parity);
	}
	if (side == 3) {
		return cell + vec2(-1.0, parity - 1.0);
	}
	if (side == 4) {
		return cell + vec2(0.0, -1.0);
	}
	return cell + vec2(1.0, parity - 1.0);
}

bool in_world(vec2 cell) {
	return cell.x >= 0.0 && cell.y >= 0.0 && cell.x < world_size.x && cell.y < world_size.y;
}

vec4 sample_world_cell(vec2 cell) {
	return texture(world_data, (cell + vec2(0.5)) / world_size);
}

float terrain_kind(vec4 terrain) {
	return floor(terrain.r * 255.0 + 0.5);
}

float terrain_motion(float cell_kind) {
	vec2 style_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
	vec4 properties = texture(terrain_properties, style_uv);
	return floor(properties.r * 255.0 + 0.5);
}

bool should_draw_edge(vec2 cell, float current_kind, int side) {
	vec2 neighbor_cell = neighbor_for_edge(cell, side);
	if (!in_world(neighbor_cell)) {
		return true;
	}
	vec4 neighbor = sample_world_cell(neighbor_cell);
	float neighbor_kind = terrain_kind(neighbor);
	return abs(neighbor_kind - current_kind) > 0.5;
}

bool has_exposed_liquid_surface(vec2 cell, float current_kind) {
	vec2 above_cell = neighbor_for_edge(cell, 4);
	if (!in_world(above_cell)) {
		return true;
	}
	vec4 above = sample_world_cell(above_cell);
	float above_kind = terrain_kind(above);
	return abs(above_kind - current_kind) > 0.5;
}

float soft_band(float value, float width) {
	return 1.0 - smoothstep(0.0, width, abs(value));
}

float caustic_pattern(vec2 position, float time) {
	vec2 p = position * fluid_caustic_scale;
	float phase = time * fluid_caustic_speed;
	vec2 broad_warp = vec2(
		sin(p.y * 0.72 + phase) + sin((p.x + p.y) * 0.31 - phase * 0.58) * 0.55,
		sin(p.x * 0.48 - phase * 0.82) + cos((p.x - p.y) * 0.27 + phase * 0.44) * 0.45
	);
	vec2 wobble = vec2(
		sin(p.y * 1.74 - phase * 1.13) + cos(p.x * 0.96 + phase * 0.37) * 0.35,
		cos(p.x * 1.28 + phase * 0.91) + sin(p.y * 0.83 - phase * 0.46) * 0.4
	);
	vec2 vertical_p = p + broad_warp * 0.85 + wobble * 0.22;
	vec2 slow_p = p + vec2(broad_warp.y, -broad_warp.x) * 0.72 + wobble * vec2(-0.18, 0.28);
	vec2 diagonal_p = p + broad_warp * vec2(-0.42, 0.58) + wobble * 0.36;
	float vertical = soft_band(sin(vertical_p.x * 1.28 + sin(vertical_p.y * 0.5 + phase) * 1.45), 0.28);
	float slow_vertical = soft_band(sin(slow_p.x * 0.55 - slow_p.y * 0.24 - phase * 0.35), 0.34);
	float diagonal = soft_band(sin(diagonal_p.x * 0.58 + diagonal_p.y * 0.86 + phase * 0.28), 0.24);
	float haze = sin((p.x + broad_warp.x * 0.7) * 0.22 - (p.y + broad_warp.y * 0.5) * 0.18 + phase * 0.2) * 0.5 + 0.5;
	float pattern = vertical * 0.44 + slow_vertical * 0.36 + diagonal * 0.32 + haze * 0.16;
	return smoothstep(0.16, 0.74, clamp(pattern, 0.0, 1.0));
}

float hot_liquid_factor(vec3 tint) {
	float warm_bias = tint.r - max(tint.g, tint.b);
	float brightness = max(max(tint.r, tint.g), tint.b);
	return clamp(warm_bias * 2.0 + brightness * 0.15, 0.0, 1.0);
}

bool is_streaming_liquid(vec2 cell, float fill_amount) {
	if (fill_amount >= 0.999) {
		return false;
	}
	vec2 below_cell = neighbor_for_edge(cell, 1);
	if (!in_world(below_cell)) {
		return true;
	}
	vec4 below = sample_world_cell(below_cell);
	float below_kind = terrain_kind(below);
	if (below_kind <= 0.5 || below.g <= 0.0) {
		return true;
	}
	float below_motion = terrain_motion(below_kind);
	return below_motion > 1.5 && below.g < 0.999;
}

bool is_streaming_falling_solid(vec2 cell, float fill_amount) {
	if (fill_amount >= 0.999) {
		return false;
	}
	vec2 below_cell = neighbor_for_edge(cell, 1);
	if (!in_world(below_cell)) {
		return true;
	}
	vec4 below = sample_world_cell(below_cell);
	float below_kind = terrain_kind(below);
	if (below_kind <= 0.5 || below.g <= 0.0) {
		return true;
	}
	float below_motion = terrain_motion(below_kind);
	return below_motion > 0.5 && below.g < 0.999;
}

bool has_same_source(vec2 cell, float cell_kind, int side) {
	vec2 source_cell = neighbor_for_edge(cell, side);
	if (!in_world(source_cell)) {
		return false;
	}
	vec4 source = sample_world_cell(source_cell);
	return source.g > 0.0 && abs(terrain_kind(source) - cell_kind) < 0.5;
}

float source_stream_mask(vec2 local, float fill_amount, bool above_source, bool left_source, bool right_source) {
	float width = mix(0.22, 0.72, clamp(fill_amount, 0.0, 1.0)) * hex_radius;
	float softness = max(2.0, hex_radius * 0.18);
	float half_height = hex_radius * 1.7320508 * 0.5;
	float bottom_widen = smoothstep(-half_height * 0.1, half_height * 0.85, local.y) * hex_radius * 0.16;
	float vertical = 1.0 - smoothstep(width + bottom_widen, width + bottom_widen + softness, abs(local.x));
	if (!above_source) {
		float top_clip = smoothstep(-hex_radius * 0.32, hex_radius * 0.04, local.y);
		vertical *= top_clip;
	}
	float side_window_top = smoothstep(-half_height * 0.35, -half_height * 0.05, local.y);
	float side_window_bottom = 1.0 - smoothstep(half_height * 0.35, half_height * 0.75, local.y);
	float side_window = side_window_top * side_window_bottom;
	float side_softness = max(2.0, hex_radius * 0.16);
	float left_entry = 0.0;
	if (left_source) {
		float blend = clamp((local.y + half_height * 0.2) / max(half_height * 0.8, 0.001), 0.0, 1.0);
		float left_center = -mix(hex_radius * 0.62, 0.0, blend);
		left_entry = (1.0 - smoothstep(width * 0.72, width * 0.72 + side_softness, abs(local.x - left_center))) * side_window;
	}
	float right_entry = 0.0;
	if (right_source) {
		float blend = clamp((local.y + half_height * 0.2) / max(half_height * 0.8, 0.001), 0.0, 1.0);
		float right_center = mix(hex_radius * 0.62, 0.0, blend);
		right_entry = (1.0 - smoothstep(width * 0.72, width * 0.72 + side_softness, abs(local.x - right_center))) * side_window;
	}
	return max(vertical, max(left_entry, right_entry));
}

vec4 render_solid_material(vec4 style, vec4 properties, float mask_alpha) {
	float material_index = floor(properties.b * 255.0 + 0.5);
	if (material_index > 0.5) {
		float texture_scale = max(properties.a * 1024.0, 1.0);
		vec2 tile_uv = fract(world_pos / texture_scale);
		float slot = material_index - 1.0;
		float columns = max(float(material_atlas_columns), 1.0);
		float stride = material_atlas_tile_size + material_atlas_gutter_size * 2.0;
		vec2 atlas_origin = vec2(
			mod(slot, columns) * stride + material_atlas_gutter_size,
			floor(slot / columns) * stride + material_atlas_gutter_size
		);
		vec2 atlas_pixel = atlas_origin + tile_uv * material_atlas_tile_size + vec2(0.5);
		vec2 atlas_uv = atlas_pixel / material_atlas_size;
		vec4 texel = texture(material_atlas, atlas_uv);
		return vec4(texel.rgb, style.a * texel.a * mask_alpha);
	}
	return vec4(style.rgb, style.a * mask_alpha);
}

vec4 render_liquid(vec2 cell, float cell_kind, vec4 style, vec2 local, float fill_amount, bool stream, float mask_alpha) {
	float time = TIME;
	float surface_y = fill_line_y(fill_amount);
	float surface_distance = abs(local.y - surface_y);
	float surface_glow = 0.0;
	if (!stream && (fill_amount < 0.999 || has_exposed_liquid_surface(cell, cell_kind))) {
		surface_glow = 1.0 - smoothstep(0.0, max(fluid_surface_glow_width, 0.001), surface_distance);
	}
	float caustic = caustic_pattern(world_pos, time);
	vec3 tint = style.rgb;
	float heat = hot_liquid_factor(tint);
	vec3 liquid = tint * 0.82;
	liquid += tint * caustic * fluid_caustic_strength;
	liquid += vec3(1.0) * caustic * fluid_shimmer_strength;
	liquid += mix(vec3(1.0), tint, 0.25) * surface_glow * fluid_surface_glow_strength;
	liquid += vec3(1.0, 0.42, 0.08) * heat * fluid_hot_glow_strength * (0.35 + caustic * 0.65);
	liquid += vec3(1.0, 0.78, 0.22) * heat * surface_glow * fluid_hot_glow_strength;
	if (stream) {
		float center = 1.0 - smoothstep(0.0, hex_radius * 0.75, abs(local.x));
		float streak = soft_band(sin(world_pos.x * 0.22 + sin(world_pos.y * 0.045 + time * 1.5) * 0.8), 0.3);
		float flow = sin(world_pos.y * 0.18 - time * 5.0 + local.x * 0.05) * 0.5 + 0.5;
		liquid += mix(vec3(1.0), tint, 0.35) * center * streak * (0.04 + flow * 0.07);
	}
	float opacity = clamp(fluid_alpha + heat * 0.12, 0.0, 1.0);
	return vec4(liquid, style.a * opacity * mask_alpha);
}

vec4 render_liquid_above_partial_cell(vec2 cell, vec2 local) {
	vec2 above_cell = neighbor_for_edge(cell, 4);
	if (!in_world(above_cell)) {
		return vec4(0.0);
	}
	vec4 terrain = sample_world_cell(above_cell);
	float cell_kind = floor(terrain.r * 255.0 + 0.5);
	if (cell_kind <= 0.5 || terrain.g <= 0.0) {
		return vec4(0.0);
	}
	vec2 style_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
	vec4 properties = texture(terrain_properties, style_uv);
	float motion = floor(properties.r * 255.0 + 0.5);
	if (motion < 1.5) {
		return vec4(0.0);
	}
	vec4 style = texture(style_data, style_uv);
	return render_liquid(above_cell, cell_kind, style, local, 1.0, false, 1.0);
}

void fragment() {
	vec4 out_color = vec4(0.0);
	vec2 cell = world_to_offset(world_pos);
	if (in_world(cell)) {
		vec4 terrain = sample_world_cell(cell);
		float cell_kind = terrain_kind(terrain);
		vec2 local = world_pos - center_for_offset(cell);
		if (cell_kind > 0.5 && inside_hex(local)) {
			vec2 style_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
			vec4 style = texture(style_data, style_uv);
			vec4 properties = texture(terrain_properties, style_uv);
			float motion = floor(properties.r * 255.0 + 0.5);
			float fill_amount = terrain.g;
			if (motion > 1.5) {
				bool stream = is_streaming_liquid(cell, fill_amount);
				float liquid_mask = 1.0;
				if (fill_amount < 0.999) {
					if (stream) {
						bool above_source = has_same_source(cell, cell_kind, 4);
						bool left_source = has_same_source(cell, cell_kind, 3);
						bool right_source = has_same_source(cell, cell_kind, 5);
						liquid_mask = source_stream_mask(local, fill_amount, above_source, left_source, right_source);
					} else if (local.y < fill_line_y(fill_amount)) {
						liquid_mask = 0.0;
					}
				}
				if (liquid_mask > 0.001) {
					out_color = render_liquid(cell, cell_kind, style, local, fill_amount, stream, liquid_mask);
				}
			} else {
				bool partial_falling = motion > 0.5 && fill_amount < 0.999;
				bool falling_stream = partial_falling && is_streaming_falling_solid(cell, fill_amount);
				float solid_mask = 1.0;
				if (partial_falling) {
					if (falling_stream) {
						bool above_source = has_same_source(cell, cell_kind, 4);
						bool left_source = has_same_source(cell, cell_kind, 3);
						bool right_source = has_same_source(cell, cell_kind, 5);
						solid_mask = source_stream_mask(local, fill_amount, above_source, left_source, right_source);
					} else if (local.y < fill_line_y(fill_amount)) {
						solid_mask = 0.0;
					}
				}
				bool current_fill_visible = solid_mask > 0.001;
				if (current_fill_visible) {
					out_color = render_solid_material(style, properties, solid_mask);
				} else if (partial_falling) {
					out_color = render_liquid_above_partial_cell(cell, local);
				}
				vec4 edge_style = texture(edge_style_data, style_uv);
				float edge_width = edge_style.a * edge_width_normalization;
				if (edge_width > 0.0 && current_fill_visible) {
					float distance_to_edge;
					int side = nearest_edge(local, distance_to_edge);
					if (distance_to_edge <= edge_width && should_draw_edge(cell, cell_kind, side)) {
						float edge_alpha = clamp((edge_width - distance_to_edge) / max(edge_width, 0.001), 0.0, 1.0);
						out_color = mix(out_color, vec4(edge_style.rgb, 1.0), edge_alpha);
					}
				}
			}
		}
	}
	COLOR = out_color;
}
