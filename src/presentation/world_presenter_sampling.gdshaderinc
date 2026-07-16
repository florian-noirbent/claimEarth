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
	return mod(floor(terrain.r * 255.0 + 0.5), 16.0);
}

float rendered_quantity(vec4 terrain) {
	return min(terrain.g * 255.0, 127.0) / 127.0;
}

float terrain_motion(float cell_kind) {
	vec2 style_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
	vec4 properties = texture(terrain_properties, style_uv);
	return floor(properties.r * 255.0 + 0.5);
}

float terrain_block_density(float cell_kind) {
	vec2 properties_uv = vec2((cell_kind + 0.5) / 256.0, 0.5);
	return floor(texture(terrain_properties, properties_uv).g * 255.0 + 0.5);
}

vec4 sample_world_or_air(vec2 cell) {
	if (!in_world(cell)) {
		return vec4(0.0);
	}
	return sample_world_cell(cell);
}

bool has_exposed_liquid_surface(vec2 cell, float current_kind) {
	vec2 above_cell = neighbor_for_edge(cell, EDGE_UP);
	if (!in_world(above_cell)) {
		return true;
	}
	vec4 above = sample_world_cell(above_cell);
	float above_kind = terrain_kind(above);
	return abs(above_kind - current_kind) > 0.5;
}
