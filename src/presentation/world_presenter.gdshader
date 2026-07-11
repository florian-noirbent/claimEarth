shader_type canvas_item;

uniform sampler2D world_data : filter_nearest;
uniform sampler2D even_world : filter_nearest;
uniform sampler2D style_data : filter_nearest;
uniform sampler2D terrain_properties : filter_nearest;
uniform sampler2D terrain_density : filter_nearest;
uniform sampler2D edge_style_data : filter_nearest;
uniform sampler2D material_atlas : filter_linear;
uniform float hex_radius = 16.0;
uniform vec2 world_size = vec2(1.0, 1.0);
uniform float edge_width_normalization = 16.0;
uniform int material_atlas_columns = 1;
uniform float material_atlas_tile_size = 1024.0;
uniform float material_atlas_gutter_size = 1.0;
uniform vec2 material_atlas_size = vec2(1.0, 1.0);
uniform float light_black_threshold = 30.0;
uniform float light_full_brightness_threshold = 160.0;
uniform float fluid_alpha = 0.56;
uniform float fluid_caustic_strength = 0.28;
uniform float fluid_caustic_scale = 0.012;
uniform float fluid_caustic_speed = 0.35;
uniform float fluid_shimmer_strength = 0.1;
uniform float fluid_surface_glow_width = 5.0;
uniform float fluid_surface_glow_strength = 0.35;
uniform float fluid_hot_glow_strength = 0.65;
uniform float exposed_edge_corner_radius = 10.0;
uniform float exposed_edge_jitter_strength = 5.0;
uniform float exposed_edge_jitter_scale = 0.12;

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

float hash21(vec2 value) {
	vec3 hash = fract(vec3(value.xyx) * 0.1031);
	hash += dot(hash, hash.yzx + 33.33);
	return fract((hash.x + hash.y) * hash.z);
}

float edge_jitter(vec2 position) {
	vec2 scaled_position = position * exposed_edge_jitter_scale;
	vec2 grid = floor(scaled_position);
	vec2 fraction = fract(scaled_position);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float lower_left = hash21(grid);
	float lower_right = hash21(grid + vec2(1.0, 0.0));
	float upper_left = hash21(grid + vec2(0.0, 1.0));
	float upper_right = hash21(grid + vec2(1.0, 1.0));
	return mix(mix(lower_left, lower_right, fraction.x), mix(upper_left, upper_right, fraction.x), fraction.y);
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

void nearest_two_edges(vec2 local, out int nearest, out float nearest_distance, out int second, out float second_distance) {
	nearest = 0;
	second = 1;
	nearest_distance = edge_distance(local, nearest);
	second_distance = edge_distance(local, second);
	if (second_distance < nearest_distance) {
		float distance_swap = nearest_distance;
		nearest_distance = second_distance;
		second_distance = distance_swap;
		int side_swap = nearest;
		nearest = second;
		second = side_swap;
	}
	for (int side = 2; side < 6; side++) {
		float candidate = edge_distance(local, side);
		if (candidate < nearest_distance) {
			second_distance = nearest_distance;
			second = nearest;
			nearest_distance = candidate;
			nearest = side;
		} else if (candidate < second_distance) {
			second_distance = candidate;
			second = side;
		}
	}
}

vec2 corner_position(int corner) {
	float half_height = hex_radius * 1.7320508 * 0.5;
	if (corner == 0) {
		return vec2(hex_radius, 0.0);
	}
	if (corner == 1) {
		return vec2(hex_radius * 0.5, half_height);
	}
	if (corner == 2) {
		return vec2(-hex_radius * 0.5, half_height);
	}
	if (corner == 3) {
		return vec2(-hex_radius, 0.0);
	}
	if (corner == 4) {
		return vec2(-hex_radius * 0.5, -half_height);
	}
	return vec2(hex_radius * 0.5, -half_height);
}

void corner_sides(int corner, out int first_side, out int second_side) {
	if (corner == 0) {
		first_side = 5;
		second_side = 0;
		return;
	}
	first_side = corner - 1;
	second_side = corner;
}

int nearest_corner(vec2 local, out vec2 vertex) {
	int nearest = 0;
	vertex = corner_position(0);
	float nearest_distance = length(local - vertex);
	for (int corner = 1; corner < 6; corner++) {
		vec2 candidate_vertex = corner_position(corner);
		float candidate_distance = length(local - candidate_vertex);
		if (candidate_distance < nearest_distance) {
			nearest = corner;
			vertex = candidate_vertex;
			nearest_distance = candidate_distance;
		}
	}
	return nearest;
}

float corner_radius_at(vec2 cell, vec2 vertex) {
	return max(0.001, exposed_edge_corner_radius);
}

bool in_corner_arc_region(vec2 local, int corner, vec2 vertex, float radius) {
	vec2 previous_vertex = corner_position((corner + 5) % 6);
	vec2 next_vertex = corner_position((corner + 1) % 6);
	vec2 previous_direction = normalize(previous_vertex - vertex);
	vec2 next_direction = normalize(next_vertex - vertex);
	vec2 from_vertex = local - vertex;
	float tangent_length = radius * 0.57735027;
	return dot(from_vertex, previous_direction) <= tangent_length
		&& dot(from_vertex, next_direction) <= tangent_length
		&& dot(from_vertex, normalize(-vertex)) >= 0.0;
}

float corner_circle_distance(vec2 local, vec2 vertex, float radius) {
	vec2 inward = normalize(-vertex);
	vec2 circle_center = vertex + inward * radius * 1.15470054;
	return length(local - circle_center) - radius;
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

vec4 sample_even_cell(vec2 cell) {
	return texture(even_world, (cell + vec2(0.5)) / world_size);
}

float terrain_kind(vec4 terrain) {
	return floor(terrain.r * 255.0 + 0.5);
}

float terrain_motion(float cell_kind) {
	vec2 style_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
	vec4 properties = texture(terrain_properties, style_uv);
	return floor(properties.r * 255.0 + 0.5);
}

float terrain_block_density(float cell_kind) {
	vec2 density_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
	return floor(texture(terrain_density, density_uv).r * 255.0 + 0.5);
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

vec4 sample_world_or_air(vec2 cell) {
	if (!in_world(cell)) {
		return vec4(0.0);
	}
	return sample_world_cell(cell);
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

bool has_even_phase_vertical_source(vec2 cell, float cell_kind) {
	vec2 above_cell = neighbor_for_edge(cell, 4);
	if (!in_world(above_cell)) {
		return false;
	}
	vec4 even_above = sample_even_cell(above_cell);
	vec4 even_current = sample_even_cell(cell);
	vec4 final_current = sample_world_cell(cell);
	float even_current_kind = terrain_kind(even_current);
	if (even_above.g <= 0.0 || abs(terrain_kind(even_above) - cell_kind) > 0.5) {
		return false;
	}
	if (even_current_kind > 0.5 && abs(even_current_kind - cell_kind) > 0.5) {
		return false;
	}
	return final_current.g > even_current.g;
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

float vertical_trail_mask(vec2 local, float fill_amount) {
	float width = mix(0.16, 0.42, clamp(fill_amount, 0.0, 1.0)) * hex_radius;
	float softness = max(2.0, hex_radius * 0.18);
	return 1.0 - smoothstep(width, width + softness, abs(local.x));
}

vec4 render_even_phase_liquid_trail(vec2 cell, vec2 local) {
	vec4 even_terrain = sample_even_cell(cell);
	float cell_kind = terrain_kind(even_terrain);
	if (cell_kind <= 0.5 || even_terrain.g <= 0.0 || terrain_motion(cell_kind) <= 1.5) {
		return vec4(0.0);
	}
	vec2 below_cell = neighbor_for_edge(cell, 1);
	if (!in_world(below_cell)) {
		return vec4(0.0);
	}
	vec4 even_below = sample_even_cell(below_cell);
	vec4 final_below = sample_world_cell(below_cell);
	if (abs(terrain_kind(final_below) - cell_kind) > 0.5 || final_below.g <= even_below.g) {
		return vec4(0.0);
	}
	vec2 style_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
	vec4 style = texture(style_data, style_uv);
	float mask = vertical_trail_mask(local, even_terrain.g);
	return render_liquid(cell, cell_kind, style, local, even_terrain.g, true, mask);
}

bool has_render_priority(float current_kind, float neighbor_kind) {
	float current_density = terrain_block_density(current_kind);
	float neighbor_density = terrain_block_density(neighbor_kind);
	return neighbor_density > current_density || (abs(neighbor_density - current_density) < 0.5 && neighbor_kind > current_kind);
}

vec4 render_boundary_material(vec2 source_cell, vec4 source_terrain) {
	float source_kind = terrain_kind(source_terrain);
	vec2 style_uv = vec2((source_kind + 0.5) / 256.0, 0.5);
	vec4 style = texture(style_data, style_uv);
	vec4 properties = texture(terrain_properties, style_uv);
	vec2 source_local = world_pos - center_for_offset(source_cell);
	float motion = terrain_motion(source_kind);
	float fill_amount = source_terrain.g;
	if (motion > 1.5) {
		bool stream = is_streaming_liquid(source_cell, fill_amount);
		float liquid_mask = 1.0;
		if (fill_amount < 0.999) {
			if (stream) {
				bool above_source = has_same_source(source_cell, source_kind, 4) || has_even_phase_vertical_source(source_cell, source_kind);
				bool left_source = has_same_source(source_cell, source_kind, 3);
				bool right_source = has_same_source(source_cell, source_kind, 5);
				liquid_mask = source_stream_mask(source_local, fill_amount, above_source, left_source, right_source);
			} else if (source_local.y < fill_line_y(fill_amount)) {
				liquid_mask = 0.0;
			}
		}
		if (liquid_mask <= 0.001) {
			return vec4(0.0);
		}
		return render_liquid(source_cell, source_kind, style, source_local, fill_amount, stream, liquid_mask);
	}
	if (motion > 0.5 && fill_amount < 0.999) {
		bool stream = is_streaming_falling_solid(source_cell, fill_amount);
		float solid_mask = 1.0;
		if (stream) {
			bool above_source = has_same_source(source_cell, source_kind, 4);
			bool left_source = has_same_source(source_cell, source_kind, 3);
			bool right_source = has_same_source(source_cell, source_kind, 5);
			solid_mask = source_stream_mask(source_local, fill_amount, above_source, left_source, right_source);
		} else if (source_local.y < fill_line_y(fill_amount)) {
			solid_mask = 0.0;
		}
		if (solid_mask <= 0.001) {
			return render_liquid_above_partial_cell(source_cell, source_local);
		}
		return render_solid_material(style, properties, solid_mask);
	}
	return render_solid_material(style, properties, 1.0);
}

bool is_upward_moving_free_surface(vec2 moving_cell, vec4 moving_terrain, vec2 other_cell, vec4 other_terrain) {
	float moving_kind = terrain_kind(moving_terrain);
	if (moving_kind <= 0.5 || moving_terrain.g <= 0.0 || terrain_motion(moving_kind) <= 0.5) {
		return false;
	}
	if (terrain_kind(other_terrain) > 0.5 && other_terrain.g > 0.0) {
		return false;
	}
	return center_for_offset(other_cell).y < center_for_offset(moving_cell).y - 0.001;
}

void resolve_jittered_boundary(
	vec2 cell,
	vec4 terrain,
	vec2 local,
	out vec2 resolved_cell,
	out vec4 resolved_terrain,
	out float owner_kind,
	out float owner_distance,
	out bool has_boundary
) {
	resolved_cell = cell;
	resolved_terrain = terrain;
	owner_kind = terrain_kind(terrain);
	owner_distance = 9999.0;
	has_boundary = false;
	float current_kind = terrain_kind(terrain);
	float current_density = terrain_block_density(current_kind);
	float jitter = (edge_jitter(world_pos) * 2.0 - 1.0) * exposed_edge_jitter_strength;

	vec2 vertex;
	int corner = nearest_corner(local, vertex);
	float radius = corner_radius_at(cell, vertex);
	if (in_corner_arc_region(local, corner, vertex, radius)) {
		int first_side;
		int second_side;
		corner_sides(corner, first_side, second_side);
		vec2 first_cell = neighbor_for_edge(cell, first_side);
		vec2 second_cell = neighbor_for_edge(cell, second_side);
		vec4 first_terrain = sample_world_or_air(first_cell);
		vec4 second_terrain = sample_world_or_air(second_cell);
		float first_kind = terrain_kind(first_terrain);
		float second_kind = terrain_kind(second_terrain);
		float first_density = terrain_block_density(first_kind);
		float second_density = terrain_block_density(second_kind);
		float circle_distance = corner_circle_distance(local, vertex, radius);
		bool current_top_surface = is_upward_moving_free_surface(cell, terrain, first_cell, first_terrain)
			|| is_upward_moving_free_surface(cell, terrain, second_cell, second_terrain);
		bool neighbor_top_surface = is_upward_moving_free_surface(first_cell, first_terrain, cell, terrain)
			|| is_upward_moving_free_surface(second_cell, second_terrain, cell, terrain);
		if (current_top_surface || neighbor_top_surface) {
			return;
		}

		if (current_density > first_density && current_density > second_density) {
			has_boundary = true;
			owner_kind = current_kind;
			owner_distance = -circle_distance + jitter;
			if (owner_distance < 0.0) {
				float first_edge_distance = edge_distance(local, first_side);
				float second_edge_distance = edge_distance(local, second_side);
				if (first_edge_distance <= second_edge_distance) {
					resolved_cell = first_cell;
					resolved_terrain = first_terrain;
				} else {
					resolved_cell = second_cell;
					resolved_terrain = second_terrain;
				}
			}
			return;
		}

		if (first_density > current_density && second_density > current_density
				&& first_kind > 0.5 && abs(first_kind - second_kind) < 0.5) {
			has_boundary = true;
			owner_kind = first_kind;
			owner_distance = circle_distance + jitter;
			if (owner_distance >= 0.0) {
				resolved_cell = first_cell;
				resolved_terrain = first_terrain;
			}
			return;
		}
	}

	float distance_to_edge;
	int side = nearest_edge(local, distance_to_edge);
	float maximum_band = exposed_edge_jitter_strength + edge_width_normalization;
	if (distance_to_edge > maximum_band) {
		return;
	}
	vec2 neighbor_cell = neighbor_for_edge(cell, side);
	vec4 neighbor = sample_world_or_air(neighbor_cell);
	float neighbor_kind = terrain_kind(neighbor);
	if (abs(neighbor_kind - current_kind) < 0.5) {
		return;
	}
	if (is_upward_moving_free_surface(cell, terrain, neighbor_cell, neighbor)
			|| is_upward_moving_free_surface(neighbor_cell, neighbor, cell, terrain)) {
		return;
	}
	float neighbor_density = terrain_block_density(neighbor_kind);
	has_boundary = true;
	if (has_render_priority(current_kind, neighbor_kind)) {
		owner_kind = neighbor_kind;
		owner_distance = jitter - distance_to_edge;
		if (owner_distance >= 0.0) {
			resolved_cell = neighbor_cell;
			resolved_terrain = neighbor;
		}
	} else {
		owner_kind = current_kind;
		owner_distance = distance_to_edge + jitter;
		if (owner_distance < 0.0) {
			resolved_cell = neighbor_cell;
			resolved_terrain = neighbor;
		}
	}
}

vec4 apply_resolved_outline(vec4 color, float resolved_kind, float owner_kind, float owner_distance, bool has_boundary) {
	if (!has_boundary || color.a <= 0.001 || owner_distance < 0.0 || abs(resolved_kind - owner_kind) > 0.5) {
		return color;
	}
	vec2 style_uv = vec2((owner_kind + 0.5) / 256.0, 0.5);
	vec4 edge_style = texture(edge_style_data, style_uv);
	float edge_width = edge_style.a * edge_width_normalization;
	if (edge_width <= 0.0) {
		return color;
	}
	float antialias_width = max(fwidth(owner_distance), 0.35);
	float edge_alpha = 1.0 - smoothstep(max(0.0, edge_width - antialias_width), edge_width + antialias_width, owner_distance);
	return mix(color, vec4(edge_style.rgb, 1.0), edge_alpha);
}

float light_brightness(float light_level) {
	if (light_level <= light_black_threshold) {
		return 0.0;
	}
	if (light_level >= light_full_brightness_threshold) {
		return 1.0;
	}
	return (light_level - light_black_threshold) / max(1.0, light_full_brightness_threshold - light_black_threshold);
}

float inverse_light_distance_weight(vec2 center) {
	vec2 delta = world_pos - center;
	return 1.0 / max(1.0, dot(delta, delta));
}

float hex_smoothed_light(vec2 cell, vec2 local, float current_light) {
	int first_side;
	int second_side;
	float first_distance;
	float second_distance;
	nearest_two_edges(local, first_side, first_distance, second_side, second_distance);
	vec2 first_cell = neighbor_for_edge(cell, first_side);
	vec2 second_cell = neighbor_for_edge(cell, second_side);
	float first_light = in_world(first_cell) ? sample_world_cell(first_cell).b * 255.0 : current_light;
	float second_light = in_world(second_cell) ? sample_world_cell(second_cell).b * 255.0 : current_light;
	float current_weight = inverse_light_distance_weight(center_for_offset(cell));
	float first_weight = inverse_light_distance_weight(center_for_offset(first_cell));
	float second_weight = inverse_light_distance_weight(center_for_offset(second_cell));
	return (current_light * current_weight + first_light * first_weight + second_light * second_weight)
		/ (current_weight + first_weight + second_weight);
}

void fragment() {
	vec4 out_color = vec4(0.0);
	float cell_light = 0.0;
	vec2 cell = world_to_offset(world_pos);
	if (in_world(cell)) {
		vec4 terrain = sample_world_cell(cell);
		cell_light = terrain.b * 255.0;
		float cell_kind = terrain_kind(terrain);
		vec2 local = world_pos - center_for_offset(cell);
		if (inside_hex(local)) {
			if (cell_kind <= 0.5) {
				out_color = render_even_phase_liquid_trail(cell, local);
			} else {
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
						bool above_source = has_same_source(cell, cell_kind, 4) || has_even_phase_vertical_source(cell, cell_kind);
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
				}
			}
			vec2 resolved_cell;
			vec4 resolved_terrain;
			float owner_kind;
			float owner_distance;
			bool has_boundary;
			resolve_jittered_boundary(cell, terrain, local, resolved_cell, resolved_terrain, owner_kind, owner_distance, has_boundary);
			float resolved_kind = terrain_kind(resolved_terrain);
			if (abs(resolved_kind - cell_kind) > 0.5 || distance(resolved_cell, cell) > 0.1) {
				if (resolved_kind <= 0.5 || resolved_terrain.g <= 0.0) {
					out_color = vec4(0.0);
				} else {
					out_color = render_boundary_material(resolved_cell, resolved_terrain);
				}
			}
			out_color = apply_resolved_outline(out_color, resolved_kind, owner_kind, owner_distance, has_boundary);
		}
	}
	float brightness = light_brightness(hex_smoothed_light(cell, world_pos - center_for_offset(cell), cell_light));
	out_color.rgb *= brightness;
	out_color.a = mix(1.0, out_color.a, brightness);
	COLOR = out_color;
}
