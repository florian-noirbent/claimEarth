shader_type canvas_item;
render_mode unshaded;

uniform sampler2D source_world : filter_nearest, repeat_disable;
uniform sampler2D rule_texture : filter_nearest, repeat_disable;
uniform sampler2D standard_light_sources : filter_nearest, repeat_disable;
uniform vec2 world_size = vec2(1.0, 1.0);
uniform int pass_kind = 0;
uniform ivec2 high_frequency_light_offset = ivec2(-1, -1);
uniform int high_frequency_light_level = 0;
uniform int high_frequency_light_update_radius = 0;

#include "../shader/hex_grid.gdshaderinc"

const int PASS_VERTICAL_EVEN = 0;
const int PASS_RIGHT_DOWN_EVEN = 1;
const int PASS_LEFT_DOWN_EVEN = 2;
const int PASS_VERTICAL_ODD = 3;
const int PASS_RIGHT_DOWN_ODD = 4;
const int PASS_LEFT_DOWN_ODD = 5;
const int MOTION_STABLE = 0;
const int MOTION_LIQUID = 2;
const int AIR_FILL = 0;
const int FULL_FILL = 255;
const int HALF_FILL = 128;

int byte_from_float(float value) {
	return int(floor(clamp(value, 0.0, 1.0) * 255.0 + 0.5));
}

vec4 color_from_bytes(int terrain_id, int fill, int light, int flags) {
	return vec4(
		float(clamp(terrain_id, 0, 255)) / 255.0,
		float(clamp(fill, 0, 255)) / 255.0,
		float(clamp(light, 0, 255)) / 255.0,
		float(clamp(flags, 0, 255)) / 255.0
	);
}

vec4 read_cell(ivec2 coord) {
	return texture(source_world, (vec2(coord) + vec2(0.5)) / world_size);
}

vec4 read_rule(int terrain_id, int row) {
	return texture(rule_texture, (vec2(float(terrain_id), float(row)) + vec2(0.5)) / vec2(256.0, 4.0));
}

int rule_byte(int terrain_id, int row, int channel) {
	vec4 rule = read_rule(terrain_id, row);
	if (channel == 0) {
		return byte_from_float(rule.r);
	}
	if (channel == 1) {
		return byte_from_float(rule.g);
	}
	if (channel == 2) {
		return byte_from_float(rule.b);
	}
	return byte_from_float(rule.a);
}

int terrain_id(vec4 cell) {
	return byte_from_float(cell.r);
}

int fill_amount(vec4 cell) {
	return byte_from_float(cell.g);
}

int motion(int id) {
	return rule_byte(id, 0, 0);
}

bool can_fall(int id) {
	return rule_byte(id, 0, 1) != 0;
}

bool can_side_down(int id) {
	return rule_byte(id, 0, 2) != 0;
}

bool can_side_up(int id) {
	return rule_byte(id, 0, 3) != 0;
}

int density(int id) {
	return rule_byte(id, 1, 0);
}

int fall_rate(int id) {
	return rule_byte(id, 1, 1);
}

int side_down_rate(int id) {
	return rule_byte(id, 1, 2);
}

int side_up_rate(int id) {
	return rule_byte(id, 1, 3);
}

int min_fill_difference(int id) {
	return rule_byte(id, 2, 0);
}

int side_flow_offset(int id) {
	return rule_byte(id, 2, 1);
}

bool is_passable(int id) {
	return rule_byte(id, 2, 3) != 0;
}

int air_id() {
	return rule_byte(0, 3, 0);
}

int stone_id() {
	return rule_byte(0, 3, 1);
}

int light_diffusion(int id) {
	return rule_byte(id, 3, 2);
}

int emitted_light(int id) {
	return rule_byte(id, 3, 3);
}

int standard_light(ivec2 coord) {
	return byte_from_float(texture(standard_light_sources, (vec2(coord) + vec2(0.5)) / world_size).r);
}

vec4 make_cell(int cell_id, int fill) {
	int resolved_fill = cell_id == air_id() ? 0 : clamp(fill, 0, 255);
	return color_from_bytes(cell_id, resolved_fill, 0, 255);
}

bool is_moving(int id) {
	return motion(id) != MOTION_STABLE;
}

bool is_vertical_pass() {
	return pass_kind == PASS_VERTICAL_EVEN || pass_kind == PASS_VERTICAL_ODD;
}

int pass_parity() {
	if (pass_kind == PASS_VERTICAL_EVEN || pass_kind == PASS_RIGHT_DOWN_EVEN || pass_kind == PASS_LEFT_DOWN_EVEN) {
		return 0;
	}
	return 1;
}

ivec2 pair_neighbor(ivec2 owner) {
	if (pass_kind == PASS_VERTICAL_EVEN || pass_kind == PASS_VERTICAL_ODD) {
		return hex_neighbor(owner, HEX_DIRECTION_DOWN);
	}
	if (pass_kind == PASS_RIGHT_DOWN_EVEN || pass_kind == PASS_RIGHT_DOWN_ODD) {
		return hex_neighbor(owner, HEX_DIRECTION_DOWN_RIGHT);
	}
	if (pass_kind == PASS_LEFT_DOWN_EVEN || pass_kind == PASS_LEFT_DOWN_ODD) {
		return hex_neighbor(owner, HEX_DIRECTION_DOWN_LEFT);
	}
	return owner;
}

ivec2 pair_owner_for(ivec2 coord) {
	int parity = pass_parity();
	if (pass_kind == PASS_VERTICAL_EVEN || pass_kind == PASS_VERTICAL_ODD) {
		if ((coord.y & 1) == parity) {
			return coord;
		}
		return ivec2(coord.x, coord.y - 1);
	}
	if (pass_kind == PASS_RIGHT_DOWN_EVEN || pass_kind == PASS_RIGHT_DOWN_ODD) {
		if ((coord.x & 1) == parity) {
			return coord;
		}
		int owner_x = coord.x - 1;
		return ivec2(owner_x, coord.y - (owner_x & 1));
	}
	if ((coord.x & 1) == parity) {
		return coord;
	}
	int owner_x = coord.x + 1;
	return ivec2(owner_x, coord.y - (owner_x & 1));
}

bool in_bounds(ivec2 coord) {
	return coord.x >= 0 && coord.y >= 0 && coord.x < int(world_size.x) && coord.y < int(world_size.y);
}

bool updates_high_frequency_light(ivec2 coord) {
	return high_frequency_light_offset.x >= 0 && high_frequency_light_offset.y >= 0
		&& hex_distance(coord, high_frequency_light_offset) <= high_frequency_light_update_radius;
}

int resolved_light(ivec2 coord, vec4 current, vec4 terrain_result) {
	if (pass_kind != PASS_LEFT_DOWN_ODD && !updates_high_frequency_light(coord)) {
		return byte_from_float(current.b);
	}
	int cell_id = terrain_id(terrain_result);
	int source_light = max(
		emitted_light(cell_id) * fill_amount(terrain_result) / 255,
		standard_light(coord)
	);
	if (coord == high_frequency_light_offset) {
		source_light = max(source_light, high_frequency_light_level);
	}
	int persistent_light = byte_from_float(current.b) >= 130 ? byte_from_float(current.b) : 0;
	int propagated_light = 0;
	for (int direction = 0; direction < 6; direction++) {
		ivec2 neighbor = hex_neighbor(coord, direction);
		if (in_bounds(neighbor)) {
			vec4 neighbor_cell = read_cell(neighbor);
			int neighbor_light = byte_from_float(neighbor_cell.b);
			propagated_light = max(propagated_light, neighbor_light * light_diffusion(terrain_id(neighbor_cell)) / 255);
		}
	}
	return max(source_light, max(persistent_light, propagated_light));
}

int fall_amount(vec4 upper, vec4 lower) {
	int upper_id = terrain_id(upper);
	int lower_id = terrain_id(lower);
	int upper_fill = fill_amount(upper);
	int lower_fill = fill_amount(lower);
	if (upper_fill <= 0 || !can_fall(upper_id)) {
		return 0;
	}
	if (lower_id != upper_id && lower_fill > 0) {
		if (!is_moving(lower_id) || !is_passable(lower_id)) {
			return 0;
		}
		return density(upper_id) > density(lower_id) ? upper_fill : 0;
	}
	if (lower_id != upper_id && lower_id != air_id()) {
		return 0;
	}
	int capacity = FULL_FILL - lower_fill;
	return min(upper_fill, min(fall_rate(upper_id), capacity));
}

bool liquid_contact(vec4 a, vec4 b) {
	int a_id = terrain_id(a);
	int b_id = terrain_id(b);
	if (a_id == b_id || fill_amount(a) <= 0 || fill_amount(b) <= 0) {
		return false;
	}
	return motion(a_id) == MOTION_LIQUID && motion(b_id) == MOTION_LIQUID;
}

vec4 resolve_fall_for_side(vec4 upper, vec4 lower, bool output_upper) {
	int upper_id = terrain_id(upper);
	int lower_id = terrain_id(lower);
	int upper_fill = fill_amount(upper);
	int lower_fill = fill_amount(lower);
	if (upper_fill <= 0 || !can_fall(upper_id)) {
		return output_upper ? upper : lower;
	}
	if (lower_id != upper_id && lower_fill > 0) {
		if (!is_moving(lower_id) || !is_passable(lower_id)) {
			return output_upper ? upper : lower;
		}
		if (density(upper_id) <= density(lower_id)) {
			return output_upper ? upper : lower;
		}
		return output_upper ? lower : upper;
	}
	if (lower_id != upper_id && lower_id != air_id()) {
		return output_upper ? upper : lower;
	}
	int amount = min(upper_fill, min(fall_rate(upper_id), FULL_FILL - lower_fill));
	if (amount <= 0) {
		return output_upper ? upper : lower;
	}
	int next_upper_fill = upper_fill - amount;
	int next_lower_fill = lower_fill + amount;
	vec4 next_upper = make_cell(next_upper_fill > 0 ? upper_id : air_id(), next_upper_fill);
	vec4 next_lower = make_cell(upper_id, next_lower_fill);
	return output_upper ? next_upper : next_lower;
}

int side_transfer_capacity(int source_id, int source_fill, int target_fill) {
	int raw_capacity = FULL_FILL - target_fill;
	if (raw_capacity <= 0) {
		return 0;
	}
	int min_difference = min_fill_difference(source_id);
	if (min_difference > 0 && source_fill - target_fill < min_difference) {
		return 0;
	}
	int equilibrium_distance = source_fill - target_fill + side_flow_offset(source_id);
	if (equilibrium_distance <= 0) {
		return 0;
	}
	return min(source_fill, min(raw_capacity, equilibrium_distance / 2));
}

int side_up_transfer_capacity(int source_id, int source_fill, int target_fill) {
	int target_capacity = HALF_FILL - target_fill;
	if (target_capacity <= 0) {
		return 0;
	}
	int excess = source_fill - side_flow_offset(source_id) - target_fill;
	if (excess <= 0) {
		return 0;
	}
	return min(source_fill, min(target_capacity, excess / 2));
}

bool can_receive_side_cell(int source_id, vec4 target_cell, int capacity_limit) {
	int target_id = terrain_id(target_cell);
	int target_fill = fill_amount(target_cell);
	if (target_fill >= capacity_limit) {
		return false;
	}
	if (target_id == source_id) {
		return true;
	}
	if (target_id == air_id() && target_fill <= 0) {
		return true;
	}
	return density(target_id) < density(source_id);
}

int side_down_transfer_amount(vec4 source_cell, vec4 target_cell) {
	int source_id = terrain_id(source_cell);
	int source_fill = fill_amount(source_cell);
	if (source_fill <= 0 || !can_side_down(source_id)) {
		return 0;
	}
	if (!can_receive_side_cell(source_id, target_cell, FULL_FILL)) {
		return 0;
	}
	int target_fill = fill_amount(target_cell);
	return min(side_down_rate(source_id), side_transfer_capacity(source_id, source_fill, target_fill));
}

int side_up_transfer_amount(vec4 source_cell, vec4 target_cell) {
	int source_id = terrain_id(source_cell);
	int source_fill = fill_amount(source_cell);
	if (source_fill <= 0 || !can_side_up(source_id)) {
		return 0;
	}
	if (!can_receive_side_cell(source_id, target_cell, HALF_FILL)) {
		return 0;
	}
	int target_fill = fill_amount(target_cell);
	return min(side_up_rate(source_id), side_up_transfer_capacity(source_id, source_fill, target_fill));
}

bool direct_bottom_blocked(ivec2 coord, vec4 source_cell) {
	ivec2 below_coord = hex_neighbor(coord, HEX_DIRECTION_DOWN);
	return !in_bounds(below_coord) || fall_amount(source_cell, read_cell(below_coord)) <= 0;
}

bool bottom_side_blocked(ivec2 coord, vec4 source_cell) {
	ivec2 bottom_side_coord = pair_neighbor(coord);
	return !in_bounds(bottom_side_coord) || side_down_transfer_amount(source_cell, read_cell(bottom_side_coord)) <= 0;
}

vec4 resolve_side_for_output(vec4 source_cell, vec4 target_cell, bool output_source, int amount) {
	int source_id = terrain_id(source_cell);
	int source_fill = fill_amount(source_cell);
	int target_fill = fill_amount(target_cell);
	if (amount <= 0) {
		return output_source ? source_cell : target_cell;
	}
	int next_source_fill = source_fill - amount;
	int next_target_fill = target_fill + amount;
	vec4 next_source = make_cell(next_source_fill > 0 ? source_id : air_id(), next_source_fill);
	vec4 next_target = make_cell(source_id, next_target_fill);
	return output_source ? next_source : next_target;
}

vec4 resolve_side_up_for_output(vec4 source_cell, vec4 target_cell, bool output_source, int amount) {
	int source_id = terrain_id(source_cell);
	int source_fill = fill_amount(source_cell);
	int target_fill = fill_amount(target_cell);
	if (amount <= 0) {
		return output_source ? source_cell : target_cell;
	}
	int next_source_fill = source_fill - amount;
	int next_target_fill = target_fill + amount;
	vec4 next_source = make_cell(next_source_fill > 0 ? source_id : air_id(), next_source_fill);
	vec4 next_target = make_cell(source_id, next_target_fill);
	return output_source ? next_source : next_target;
}

vec4 resolve_diagonal_for_side(ivec2 a_coord, ivec2 b_coord, vec4 a, vec4 b, bool output_a) {
	int side_down_amount = 0;
	if (direct_bottom_blocked(a_coord, a)) {
		side_down_amount = side_down_transfer_amount(a, b);
	}
	if (side_down_amount > 0) {
		return resolve_side_for_output(a, b, output_a, side_down_amount);
	}
	int side_up_amount = 0;
	if (direct_bottom_blocked(b_coord, b) && bottom_side_blocked(b_coord, b)) {
		side_up_amount = side_up_transfer_amount(b, a);
	}
	if (side_up_amount > 0) {
		return resolve_side_up_for_output(b, a, !output_a, side_up_amount);
	}
	return output_a ? a : b;
}

void fragment() {
	ivec2 coord = ivec2(floor(UV * world_size));
	vec4 current = read_cell(coord);
	ivec2 owner = pair_owner_for(coord);
	vec4 result = current;
	ivec2 neighbor = pair_neighbor(owner);
	if (in_bounds(owner) && in_bounds(neighbor)) {
		bool output_a = coord.x == owner.x && coord.y == owner.y;
		vec4 a = read_cell(owner);
		vec4 b = read_cell(neighbor);
		if (liquid_contact(a, b)) {
			result = output_a ? make_cell(air_id(), AIR_FILL) : make_cell(stone_id(), FULL_FILL);
		} else if (fill_amount(a) <= 0 && fill_amount(b) <= 0) {
			result = output_a ? a : b;
		} else if (is_vertical_pass()) {
			result = resolve_fall_for_side(a, b, output_a);
		} else {
			result = resolve_diagonal_for_side(owner, neighbor, a, b, output_a);
		}
	}
	result.b = float(resolved_light(coord, current, result)) / 255.0;
	result.a = current.a;
	COLOR = result;
}
