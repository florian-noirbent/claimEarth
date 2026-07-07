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

bool should_draw_edge(vec2 cell, float current_kind, int side) {
	vec2 neighbor_cell = neighbor_for_edge(cell, side);
	if (!in_world(neighbor_cell)) {
		return true;
	}
	vec4 neighbor = sample_world_cell(neighbor_cell);
	float neighbor_kind = floor(neighbor.r * 255.0 + 0.5);
	return abs(neighbor_kind - current_kind) > 0.5;
}

void fragment() {
	vec4 out_color = vec4(0.0);
	vec2 cell = world_to_offset(world_pos);
	if (in_world(cell)) {
		vec4 terrain = sample_world_cell(cell);
		float cell_kind = floor(terrain.r * 255.0 + 0.5);
		vec2 local = world_pos - center_for_offset(cell);
		if (cell_kind > 0.5 && inside_hex(local)) {
			vec2 style_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
			vec4 style = texture(style_data, style_uv);
			vec4 properties = texture(terrain_properties, style_uv);
			float motion = floor(properties.r * 255.0 + 0.5);
			float fill_amount = terrain.g;
			if (!(motion > 0.5 && fill_amount < 0.999 && local.y < fill_line_y(fill_amount))) {
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
					out_color = vec4(texel.rgb, style.a * texel.a);
				} else {
					out_color = style;
				}
			}
			vec4 edge_style = texture(edge_style_data, style_uv);
			float edge_width = edge_style.a * edge_width_normalization;
			if (edge_width > 0.0) {
				float distance_to_edge;
				int side = nearest_edge(local, distance_to_edge);
				if (distance_to_edge <= edge_width && should_draw_edge(cell, cell_kind, side)) {
					float edge_alpha = clamp((edge_width - distance_to_edge) / max(edge_width, 0.001), 0.0, 1.0);
					out_color = mix(out_color, vec4(edge_style.rgb, 1.0), edge_alpha);
				}
			}
		}
	}
	COLOR = out_color;
}
