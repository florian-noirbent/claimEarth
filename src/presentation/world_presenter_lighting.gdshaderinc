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
