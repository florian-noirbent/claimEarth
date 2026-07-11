#include "../shader/hex_grid.gdshaderinc"

// Edge indices follow the clockwise polygon order used by edge_distance().
// Convert them here so all grid-neighbor directions use the canonical HexCoord order.
const int EDGE_DOWN_RIGHT = 0;
const int EDGE_DOWN = 1;
const int EDGE_DOWN_LEFT = 2;
const int EDGE_UP_LEFT = 3;
const int EDGE_UP = 4;
const int EDGE_UP_RIGHT = 5;

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

float edge_distance(vec2 local, int side) {
	float half_height = hex_radius * 1.7320508 * 0.5;
	float diagonal_limit = hex_radius * 1.7320508;
	if (side == EDGE_DOWN_RIGHT) {
		return (diagonal_limit - (1.7320508 * local.x + local.y)) * 0.5;
	}
	if (side == EDGE_DOWN) {
		return half_height - local.y;
	}
	if (side == EDGE_DOWN_LEFT) {
		return (diagonal_limit - (-1.7320508 * local.x + local.y)) * 0.5;
	}
	if (side == EDGE_UP_LEFT) {
		return (diagonal_limit - (-1.7320508 * local.x - local.y)) * 0.5;
	}
	if (side == EDGE_UP) {
		return local.y + half_height;
	}
	return (diagonal_limit - (1.7320508 * local.x - local.y)) * 0.5;
}

int nearest_edge(vec2 local, out float distance_to_edge) {
	int nearest = EDGE_DOWN_RIGHT;
	distance_to_edge = edge_distance(local, nearest);
	for (int side = EDGE_DOWN; side <= EDGE_UP_RIGHT; side++) {
		float candidate = edge_distance(local, side);
		if (candidate < distance_to_edge) {
			distance_to_edge = candidate;
			nearest = side;
		}
	}
	return nearest;
}

void nearest_two_edges(vec2 local, out int nearest, out float nearest_distance, out int second, out float second_distance) {
	nearest = EDGE_DOWN_RIGHT;
	second = EDGE_DOWN;
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
	for (int side = EDGE_DOWN_LEFT; side <= EDGE_UP_RIGHT; side++) {
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
	if (corner == 0) return vec2(hex_radius, 0.0);
	if (corner == 1) return vec2(hex_radius * 0.5, half_height);
	if (corner == 2) return vec2(-hex_radius * 0.5, half_height);
	if (corner == 3) return vec2(-hex_radius, 0.0);
	if (corner == 4) return vec2(-hex_radius * 0.5, -half_height);
	return vec2(hex_radius * 0.5, -half_height);
}

void corner_sides(int corner, out int first_side, out int second_side) {
	if (corner == 0) {
		first_side = EDGE_UP_RIGHT;
		second_side = EDGE_DOWN_RIGHT;
		return;
	}
	first_side = corner - 1;
	second_side = corner;
}

int nearest_corner(vec2 local, out vec2 vertex) {
	int nearest = 0;
	vertex = corner_position(0);
	vec2 nearest_delta = local - vertex;
	float nearest_distance_squared = dot(nearest_delta, nearest_delta);
	for (int corner = 1; corner < 6; corner++) {
		vec2 candidate_vertex = corner_position(corner);
		vec2 candidate_delta = local - candidate_vertex;
		float candidate_distance_squared = dot(candidate_delta, candidate_delta);
		if (candidate_distance_squared < nearest_distance_squared) {
			nearest = corner;
			vertex = candidate_vertex;
			nearest_distance_squared = candidate_distance_squared;
		}
	}
	return nearest;
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

int direction_for_edge(int edge) {
	if (edge == EDGE_DOWN_RIGHT) return HEX_DIRECTION_DOWN_RIGHT;
	if (edge == EDGE_DOWN) return HEX_DIRECTION_DOWN;
	if (edge == EDGE_DOWN_LEFT) return HEX_DIRECTION_DOWN_LEFT;
	if (edge == EDGE_UP_LEFT) return HEX_DIRECTION_UP_LEFT;
	if (edge == EDGE_UP) return HEX_DIRECTION_UP;
	return HEX_DIRECTION_UP_RIGHT;
}

vec2 neighbor_for_edge(vec2 cell, int edge) {
	return hex_neighbor(cell, direction_for_edge(edge));
}
