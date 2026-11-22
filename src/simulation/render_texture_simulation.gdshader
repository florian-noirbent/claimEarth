shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D source_world : filter_nearest, repeat_disable;
uniform sampler2D rule_texture : filter_nearest, repeat_disable;
uniform sampler2D reaction_texture : filter_nearest, repeat_disable;
uniform sampler2D standard_light_sources : filter_nearest, repeat_disable;
uniform vec2 world_size = vec2(1.0, 1.0);
uniform int pass_kind = 0;
uniform int simulation_tick = 0;
uniform int simulation_ticks_per_second = 10;
uniform int simulation_seed = 0;
uniform ivec2 player_light_offset = ivec2(-1, -1);
uniform int player_light_level = 0;
uniform int player_light_update_radius = 0;
uniform ivec2 flare_light_offset = ivec2(-1, -1);
uniform int flare_light_level = 0;
uniform int flare_light_update_radius = 0;

#include "../shader/hex_grid.gdshaderinc"

const int PASS_VERTICAL_EVEN = 0;
const int PASS_RIGHT_DOWN_EVEN = 1;
const int PASS_LEFT_DOWN_EVEN = 2;
const int PASS_VERTICAL_ODD = 3;
const int PASS_RIGHT_DOWN_ODD = 4;
const int PASS_LEFT_DOWN_ODD = 5;
const int MOTION_STABLE = 0;
const int MOTION_GAS = 3;
const int MOTION_DENSE_GAS = 4;
const int MOTION_LIGHT_GAS = 5;
const int REACTION_CATALYTIC_LIQUID_CONVERSION = 1;
const int REACTION_PERSISTENT_IGNITION = 2;
const int REACTION_EROSION = 3;
const int REACTION_GAS_ABSORPTION = 4;
const int REACTION_MUTUAL_REPLACEMENT = 5;
const int REACTION_BOILING = 6;
const int REACTION_CONDENSATION = 7;
const int CHANCE_SCALE = 65535;
const int FULL_QUANTITY = 127;
const int MAX_STORED_QUANTITY = 255;
const int NO_BURN_PRODUCT_ID = 255;

int byte_from_float(float value) {
	return int(floor(clamp(value, 0.0, 1.0) * 255.0 + 0.5));
}

vec4 color_from_bytes(int packed_ids, int primary_quantity, int light, int secondary_quantity) {
	return vec4(
		float(clamp(packed_ids, 0, 255)) / 255.0,
		float(clamp(primary_quantity, 0, 255)) / 255.0,
		float(clamp(light, 0, 255)) / 255.0,
		float(clamp(secondary_quantity, 0, 255)) / 255.0
	);
}

vec4 read_cell(ivec2 coord) {
	return texture(source_world, (vec2(coord) + vec2(0.5)) / world_size);
}

vec4 read_rule(int terrain_id, int row) {
	return texture(rule_texture, (vec2(float(terrain_id), float(row)) + vec2(0.5)) / vec2(256.0, 7.0));
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
	return byte_from_float(cell.r) & 15;
}

int secondary_terrain_id(vec4 cell) {
	return (byte_from_float(cell.r) >> 4) & 15;
}

int fill_amount(vec4 cell) {
	return byte_from_float(cell.g);
}

int secondary_fill_amount(vec4 cell) {
	return byte_from_float(cell.a);
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

int maximum_quantity(int id) {
	return rule_byte(id, 2, 2);
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

int normal_quantity(int id) {
	return rule_byte(id, 4, 0);
}

int storage_capacity(int id) {
	return rule_byte(id, 4, 1);
}

int persistent_burn_product(int id) {
	return rule_byte(id, 4, 2);
}

int persistent_burn_ignition_quantity(int id) {
	return rule_byte(id, 4, 3);
}

int persistent_burn_base_consumption(int id) {
	return rule_byte(id, 5, 0);
}

int persistent_burn_bonus_consumption(int id) {
	return rule_byte(id, 5, 1);
}

int persistent_burn_bonus_frequency_numerator(int id) {
	return rule_byte(id, 5, 2);
}

int persistent_burn_bonus_frequency_period(int id) {
	return rule_byte(id, 5, 3);
}

int persistent_burn_product_per_consumed(int id) {
	return rule_byte(id, 6, 0);
}

int persistent_burn_bonus_product(int id) {
	return rule_byte(id, 6, 1);
}

bool can_boil(int id) {
	return rule_byte(id, 6, 2) != 0;
}

vec4 read_reaction_header(int a, int b) {
	return texture(reaction_texture, (vec2(float(b & 15), float(a & 15)) + vec2(0.5)) / vec2(16.0, 32.0));
}

vec4 read_reaction_parameters(int a, int b) {
	return texture(reaction_texture, (vec2(float(b & 15), float((a & 15) + 16)) + vec2(0.5)) / vec2(16.0, 32.0));
}

int reaction_byte(vec4 reaction, int channel) {
	if (channel == 0) return byte_from_float(reaction.r);
	if (channel == 1) return byte_from_float(reaction.g);
	if (channel == 2) return byte_from_float(reaction.b);
	return byte_from_float(reaction.a);
}

uint hash_bits(uint value) {
	value ^= value >> 16u;
	value *= 0x7feb352du;
	value ^= value >> 15u;
	value *= 0x846ca68bu;
	value ^= value >> 16u;
	return value;
}

// A shader has no random source, so a chance is a hash of the cell, the tick, the run
// seed, and a salt separating the rolls one cell makes in a tick. Integer arithmetic
// keeps the roll identical on every GPU and for every fragment resolving the same pair.
bool chance_roll(ivec2 coord, int salt, vec4 parameters) {
	int chance = reaction_byte(parameters, 2) + reaction_byte(parameters, 3) * 256;
	uint hashed = hash_bits(uint(simulation_seed) + uint(salt));
	hashed = hash_bits(hashed + uint(simulation_tick));
	hashed = hash_bits(hashed + uint(coord.y));
	hashed = hash_bits(hashed + uint(coord.x));
	return int(hashed % uint(CHANCE_SCALE)) < chance;
}

int standard_light(ivec2 coord) {
	return byte_from_float(texture(standard_light_sources, (vec2(coord) + vec2(0.5)) / world_size).r);
}

vec4 make_components(int primary_id, int primary_quantity, int secondary_id, int secondary_quantity) {
	int resolved_primary_id = primary_id & 15;
	int resolved_secondary_id = secondary_id & 15;
	int resolved_primary_quantity = clamp(primary_quantity, 0, MAX_STORED_QUANTITY);
	int resolved_secondary_quantity = clamp(secondary_quantity, 0, MAX_STORED_QUANTITY);

	if (resolved_primary_quantity <= 0) {
		if (resolved_secondary_quantity > 0) {
			resolved_primary_id = resolved_secondary_id;
			resolved_primary_quantity = resolved_secondary_quantity;
			resolved_secondary_id = 0;
			resolved_secondary_quantity = 0;
		} else {
			resolved_primary_id = air_id();
			resolved_primary_quantity = 0;
			resolved_secondary_id = 0;
		}
	}
	if (resolved_secondary_quantity <= 0) {
		resolved_secondary_id = 0;
		resolved_secondary_quantity = 0;
	} else if (resolved_primary_id == resolved_secondary_id) {
		int combined = resolved_primary_quantity + resolved_secondary_quantity;
		resolved_primary_quantity = min(combined, MAX_STORED_QUANTITY);
		resolved_secondary_quantity = min(combined - resolved_primary_quantity, MAX_STORED_QUANTITY);
		if (resolved_secondary_quantity <= 0) {
			resolved_secondary_id = 0;
		}
	}
	if (resolved_secondary_quantity > 0 && density(resolved_secondary_id) > density(resolved_primary_id)) {
		int swapped_id = resolved_primary_id;
		int swapped_quantity = resolved_primary_quantity;
		resolved_primary_id = resolved_secondary_id;
		resolved_primary_quantity = resolved_secondary_quantity;
		resolved_secondary_id = swapped_id;
		resolved_secondary_quantity = swapped_quantity;
	}
	int packed_ids = resolved_primary_id | (resolved_secondary_id << 4);
	return color_from_bytes(packed_ids, resolved_primary_quantity, 0, resolved_secondary_quantity);
}

vec4 make_cell(int cell_id, int quantity) {
	return make_components(cell_id, quantity, 0, 0);
}

bool is_moving(int id) {
	return motion(id) != MOTION_STABLE;
}

bool is_light_gas(int id) {
	return motion(id) == MOTION_LIGHT_GAS;
}

bool has_secondary(vec4 cell) {
	return secondary_fill_amount(cell) > 0;
}

int component_capacity(vec4 cell, int component_id, int primary_limit) {
	int primary_id = terrain_id(cell);
	int primary_quantity = fill_amount(cell);
	int secondary_id = secondary_terrain_id(cell);
	int secondary_quantity = secondary_fill_amount(cell);
	int capacity = 0;
	if (primary_id == component_id) {
		capacity += max(0, primary_limit - primary_quantity);
	}
	if (secondary_quantity > 0 && secondary_id == component_id) {
		capacity += max(0, MAX_STORED_QUANTITY - secondary_quantity);
	} else if (secondary_quantity <= 0 && primary_id != component_id) {
		capacity += MAX_STORED_QUANTITY;
	}
	return capacity;
}

vec4 add_component(vec4 cell, int component_id, int quantity, int primary_limit) {
	int primary_id = terrain_id(cell);
	int primary_quantity = fill_amount(cell);
	int secondary_id = secondary_terrain_id(cell);
	int secondary_quantity = secondary_fill_amount(cell);
	int remaining = max(0, quantity);
	if (primary_id == component_id && remaining > 0) {
		int accepted = min(remaining, max(0, primary_limit - primary_quantity));
		primary_quantity += accepted;
		remaining -= accepted;
	}
	if (secondary_quantity > 0 && secondary_id == component_id && remaining > 0) {
		int accepted = min(remaining, MAX_STORED_QUANTITY - secondary_quantity);
		secondary_quantity += accepted;
		remaining -= accepted;
	} else if (secondary_quantity <= 0 && primary_id != component_id && remaining > 0) {
		secondary_id = component_id;
		secondary_quantity = min(remaining, MAX_STORED_QUANTITY);
	}
	return make_components(primary_id, primary_quantity, secondary_id, secondary_quantity);
}

vec4 remove_primary_component(vec4 cell, int quantity) {
	return make_components(
		terrain_id(cell),
		fill_amount(cell) - quantity,
		secondary_terrain_id(cell),
		secondary_fill_amount(cell)
	);
}

vec4 remove_secondary_component(vec4 cell, int quantity) {
	return make_components(
		terrain_id(cell),
		fill_amount(cell),
		secondary_terrain_id(cell),
		secondary_fill_amount(cell) - quantity
	);
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

int pair_direction() {
	if (is_vertical_pass()) {
		return HEX_DIRECTION_DOWN;
	}
	if (pass_kind == PASS_RIGHT_DOWN_EVEN || pass_kind == PASS_RIGHT_DOWN_ODD) {
		return HEX_DIRECTION_DOWN_RIGHT;
	}
	return HEX_DIRECTION_DOWN_LEFT;
}

ivec2 pair_neighbor(ivec2 owner) {
	return hex_neighbor(owner, pair_direction());
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

bool is_below_world(ivec2 coord) {
	return coord.y >= int(world_size.y);
}

vec4 read_cell_with_solid_floor(ivec2 coord) {
	if (is_below_world(coord)) {
		return make_cell(stone_id(), FULL_QUANTITY);
	}
	return read_cell(coord);
}

bool updates_high_frequency_light(ivec2 coord) {
	return (player_light_offset.x >= 0 && player_light_offset.y >= 0
		&& hex_distance(coord, player_light_offset) <= player_light_update_radius)
		|| (flare_light_offset.x >= 0 && flare_light_offset.y >= 0
		&& hex_distance(coord, flare_light_offset) <= flare_light_update_radius);
}

int resolved_light(ivec2 coord, vec4 current, vec4 terrain_result) {
	if (pass_kind != PASS_LEFT_DOWN_ODD && !updates_high_frequency_light(coord)) {
		return byte_from_float(current.b);
	}
	int cell_id = terrain_id(terrain_result);
	int source_light = max(
		emitted_light(cell_id) * min(fill_amount(terrain_result), maximum_quantity(cell_id)) / maximum_quantity(cell_id),
		standard_light(coord)
	);
	if (coord == player_light_offset) source_light = max(source_light, player_light_level);
	if (coord == flare_light_offset) source_light = max(source_light, flare_light_level);
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

int directional_rate(int component_id, bool vertical, bool moves_down) {
	if (motion(component_id) == MOTION_GAS) {
		return MAX_STORED_QUANTITY;
	}
	if (is_light_gas(component_id) && moves_down) {
		return 0;
	}
	if (vertical) {
		return fall_rate(component_id);
	}
	return moves_down ? side_down_rate(component_id) : side_up_rate(component_id);
}

// A displaced gas crosses another medium only against that medium's own travel: it
// sinks through a rising light gas and bubbles up through everything else. Crossing
// both ways would let it shuttle between the same cells forever and stall them.
bool can_cross(int component_id, int medium_id, bool moves_down) {
	return motion(component_id) != MOTION_GAS || moves_down == is_light_gas(medium_id);
}

int secondary_transfer_amount(vec4 source, vec4 target, bool vertical, bool moves_down) {
	int component_id = secondary_terrain_id(source);
	int source_quantity = secondary_fill_amount(source);
	if (source_quantity <= 0) {
		return 0;
	}
	int rate = directional_rate(component_id, vertical, moves_down);
	if (rate <= 0) {
		return 0;
	}
	int target_primary_id = terrain_id(target);
	int target_primary_quantity = fill_amount(target);
	int target_secondary_id = secondary_terrain_id(target);
	int target_secondary_quantity = secondary_fill_amount(target);
	if (target_primary_id == component_id) {
		if (target_primary_quantity < FULL_QUANTITY) {
			return min(source_quantity, min(rate, FULL_QUANTITY - target_primary_quantity));
		}
		int pressure_difference = FULL_QUANTITY + source_quantity - target_primary_quantity;
		if (pressure_difference <= 1) {
			return 0;
		}
		return min(
			source_quantity,
			min(rate, min(MAX_STORED_QUANTITY - target_primary_quantity, pressure_difference / 2))
		);
	}
	if (target_secondary_quantity > 0 && target_secondary_id == component_id) {
		return min(source_quantity, min(rate, MAX_STORED_QUANTITY - target_secondary_quantity));
	}
	if (target_secondary_quantity <= 0
			&& (is_moving(target_primary_id) || is_passable(target_primary_id))
			&& can_cross(component_id, target_primary_id, moves_down)) {
		return min(source_quantity, rate);
	}
	return 0;
}

bool resolve_secondary_pair(
	vec4 a,
	vec4 b,
	bool vertical,
	out vec4 next_a,
	out vec4 next_b
) {
	next_a = a;
	next_b = b;
	int amount = secondary_transfer_amount(a, b, vertical, true);
	int a_burn_product = persistent_burn_product(terrain_id(a));
	if (a_burn_product != NO_BURN_PRODUCT_ID && a_burn_product == secondary_terrain_id(a) && secondary_fill_amount(a) - amount < 1) {
		amount = max(0, secondary_fill_amount(a) - 1);
	}
	if (amount > 0) {
		int component_id = secondary_terrain_id(a);
		next_a = remove_secondary_component(a, amount);
		next_b = add_component(b, component_id, amount, MAX_STORED_QUANTITY);
		return true;
	}
	amount = secondary_transfer_amount(b, a, vertical, false);
	int b_burn_product = persistent_burn_product(terrain_id(b));
	if (b_burn_product != NO_BURN_PRODUCT_ID && b_burn_product == secondary_terrain_id(b) && secondary_fill_amount(b) - amount < 1) {
		amount = max(0, secondary_fill_amount(b) - 1);
	}
	if (amount > 0) {
		int component_id = secondary_terrain_id(b);
		next_b = remove_secondary_component(b, amount);
		next_a = add_component(a, component_id, amount, MAX_STORED_QUANTITY);
		return true;
	}
	return false;
}

int primary_target_capacity(vec4 source, vec4 target, int primary_limit) {
	int source_id = terrain_id(source);
	int target_id = terrain_id(target);
	int target_secondary_id = secondary_terrain_id(target);
	int target_secondary_quantity = secondary_fill_amount(target);
	if (target_id == source_id) {
		return max(0, primary_limit - fill_amount(target));
	}
	if (target_secondary_quantity > 0 && target_secondary_id != source_id) {
		return 0;
	}
	if (!is_moving(target_id) && !is_passable(target_id)) {
		return 0;
	}
	if (density(source_id) <= density(target_id)) {
		return 0;
	}
	return component_capacity(target, source_id, primary_limit);
}

int fall_transfer_amount(vec4 source, vec4 target) {
	int source_id = terrain_id(source);
	int source_quantity = fill_amount(source);
	if (source_quantity <= 0 || !can_fall(source_id)) {
		return 0;
	}
	return min(source_quantity, min(fall_rate(source_id), primary_target_capacity(source, target, FULL_QUANTITY)));
}

int side_down_transfer_amount(vec4 source, vec4 target) {
	int source_id = terrain_id(source);
	int source_quantity = fill_amount(source);
	if (source_quantity <= 0 || !can_side_down(source_id)) {
		return 0;
	}
	int capacity = primary_target_capacity(source, target, FULL_QUANTITY);
	if (capacity <= 0) {
		return 0;
	}
	if (terrain_id(target) != source_id) {
		int equilibrium_distance = source_quantity + side_flow_offset(source_id);
		return min(
			source_quantity,
			min(side_down_rate(source_id), min(capacity, equilibrium_distance / 2))
		);
	}
	int target_quantity = fill_amount(target);
	int minimum_difference = min_fill_difference(source_id);
	if (minimum_difference > 0 && source_quantity - target_quantity < minimum_difference) {
		return 0;
	}
	int equilibrium_distance = source_quantity - target_quantity + side_flow_offset(source_id);
	if (equilibrium_distance <= 0) {
		return 0;
	}
	return min(
		source_quantity,
		min(side_down_rate(source_id), min(capacity, equilibrium_distance / 2))
	);
}

int side_up_transfer_amount(vec4 source, vec4 target) {
	int source_id = terrain_id(source);
	int source_quantity = fill_amount(source);
	if (source_quantity <= 0 || !can_side_up(source_id)) {
		return 0;
	}
	int capacity = primary_target_capacity(source, target, FULL_QUANTITY);
	if (capacity <= 0) {
		return 0;
	}
	if (terrain_id(target) != source_id) {
		int excess = source_quantity - side_flow_offset(source_id);
		if (excess <= 0) {
			return 0;
		}
		return min(source_quantity, min(side_up_rate(source_id), min(capacity, excess / 2)));
	}
	int target_quantity = fill_amount(target);
	int excess = source_quantity - side_flow_offset(source_id) - target_quantity;
	if (excess <= 0) {
		return 0;
	}
	return min(source_quantity, min(side_up_rate(source_id), min(capacity, excess / 2)));
}

void transfer_primary(
	vec4 source,
	vec4 target,
	int amount,
	out vec4 next_source,
	out vec4 next_target
) {
	int component_id = terrain_id(source);
	next_source = remove_primary_component(source, amount);
	next_target = add_component(target, component_id, amount, FULL_QUANTITY);
}

// Quantity above which a cell is pressurized and equalizes with same-terrain neighbors.
int pressure_threshold(int component_id) {
	int component_motion = motion(component_id);
	if (component_motion == MOTION_GAS || component_motion == MOTION_DENSE_GAS) {
		return 0;
	}
	return component_motion == MOTION_LIGHT_GAS ? normal_quantity(component_id) : FULL_QUANTITY;
}

bool resolve_same_primary_pressure(vec4 a, vec4 b, out vec4 next_a, out vec4 next_b) {
	next_a = a;
	next_b = b;
	int component_id = terrain_id(a);
	if (component_id != terrain_id(b) || fill_amount(a) <= 0 || fill_amount(b) <= 0) {
		return false;
	}
	int a_quantity = fill_amount(a);
	int b_quantity = fill_amount(b);
	int threshold = pressure_threshold(component_id);
	if (a_quantity <= threshold && b_quantity <= threshold) {
		return false;
	}
	int difference = a_quantity - b_quantity;
	int amount = abs(difference) / 2;
	if (amount <= 0) {
		return false;
	}
	if (difference > 0) {
		amount = min(amount, MAX_STORED_QUANTITY - b_quantity);
		next_a = remove_primary_component(a, amount);
		next_b = add_component(b, component_id, amount, MAX_STORED_QUANTITY);
	} else {
		amount = min(amount, MAX_STORED_QUANTITY - a_quantity);
		next_b = remove_primary_component(b, amount);
		next_a = add_component(a, component_id, amount, MAX_STORED_QUANTITY);
	}
	return amount > 0;
}

int component_fill(vec4 cell, int component_id) {
	if (terrain_id(cell) == component_id) {
		return fill_amount(cell);
	}
	return secondary_terrain_id(cell) == component_id ? secondary_fill_amount(cell) : 0;
}

int boiling_steam_capacity(vec4 cell, int steam_id) {
	bool has_slot = terrain_id(cell) == steam_id
		|| !has_secondary(cell)
		|| secondary_terrain_id(cell) == steam_id;
	return has_slot ? max(0, storage_capacity(steam_id) - component_fill(cell, steam_id)) : 0;
}

// Liquid quantity the cell boils away this tick.
int boiled_quantity(vec4 cell, int steam_id, vec4 parameters) {
	int steam_per_water = max(1, reaction_byte(parameters, 0));
	int steam_per_second = max(1, reaction_byte(parameters, 1));
	int cadence_denominator = max(1, simulation_ticks_per_second * steam_per_water);
	// Keep the exact integer cadence periodic so an indefinitely running session
	// cannot overflow the shader's signed tick arithmetic.
	int cadence_tick = simulation_tick % cadence_denominator;
	int water_to_consume = (cadence_tick + 1) * steam_per_second / cadence_denominator
		- cadence_tick * steam_per_second / cadence_denominator;
	return min(
		water_to_consume,
		min(fill_amount(cell), boiling_steam_capacity(cell, steam_id) / steam_per_water)
	);
}

// Direction of the one neighbor that boils this liquid cell, or -1 without any.
int boiling_heat_direction(ivec2 coord, int liquid_id) {
	for (int direction = 0; direction < 6; direction++) {
		ivec2 neighbor_coord = hex_neighbor(coord, direction);
		if (!in_bounds(neighbor_coord)) {
			continue;
		}
		vec4 reaction = read_reaction_header(liquid_id, terrain_id(read_cell(neighbor_coord)));
		if (reaction_byte(reaction, 0) == REACTION_BOILING) {
			return direction;
		}
	}
	return -1;
}

vec4 resolve_boiling_at(ivec2 coord, vec4 cell) {
	int liquid_id = terrain_id(cell);
	if (fill_amount(cell) <= 0 || !can_boil(liquid_id)) {
		return cell;
	}
	int heat_direction = boiling_heat_direction(coord, liquid_id);
	if (heat_direction < 0) {
		return cell;
	}
	int heat_id = terrain_id(read_cell(hex_neighbor(coord, heat_direction)));
	int steam_id = reaction_byte(read_reaction_header(liquid_id, heat_id), 1);
	vec4 parameters = read_reaction_parameters(liquid_id, heat_id);
	int water_to_consume = boiled_quantity(cell, steam_id, parameters);
	if (water_to_consume <= 0) {
		return cell;
	}
	return add_component(
		remove_primary_component(cell, water_to_consume),
		steam_id,
		water_to_consume * max(1, reaction_byte(parameters, 0)),
		storage_capacity(steam_id)
	);
}

// The heat source that boils a liquid cell may solidify. The roll happens in the pass
// that pairs the two cells, and only for the one neighbor that boils the liquid, so a
// liquid cell causes at most one roll per tick.
bool resolve_heat_source_solidification(
	ivec2 a_coord,
	ivec2 b_coord,
	vec4 a,
	vec4 b,
	vec4 reaction,
	out vec4 next_a,
	out vec4 next_b
) {
	next_a = a;
	next_b = b;
	bool liquid_is_a = can_boil(terrain_id(a));
	vec4 liquid = liquid_is_a ? a : b;
	ivec2 liquid_coord = liquid_is_a ? a_coord : b_coord;
	ivec2 heat_coord = liquid_is_a ? b_coord : a_coord;
	int liquid_id = terrain_id(liquid);
	vec4 parameters = read_reaction_parameters(terrain_id(a), terrain_id(b));
	if (!can_boil(liquid_id) || boiled_quantity(liquid, reaction_byte(reaction, 1), parameters) <= 0) {
		return false;
	}
	if (!chance_roll(heat_coord, pass_kind, parameters)) {
		return false;
	}
	int heat_direction = liquid_is_a ? pair_direction() : hex_opposite_direction(pair_direction());
	if (boiling_heat_direction(liquid_coord, liquid_id) != heat_direction) {
		return false;
	}
	int solid_id = reaction_byte(reaction, 2);
	vec4 solidified = make_cell(solid_id, normal_quantity(solid_id));
	if (liquid_is_a) {
		next_b = solidified;
	} else {
		next_a = solidified;
	}
	return true;
}

// Gas resting directly under its authored ceiling condenses by chance: `ceiling` is
// the upper cell of a vertical pair and `gas` the lower one. A full gas unit leaves
// liquid behind; a smaller remainder only dissipates.
bool resolve_condensation(ivec2 gas_coord, vec4 gas, vec4 reaction, vec4 parameters, out vec4 next_gas) {
	next_gas = gas;
	int gas_per_condensation = max(1, reaction_byte(parameters, 0));
	int liquid_quantity = reaction_byte(parameters, 1);
	int liquid_id = reaction_byte(reaction, 2);
	int consumed = min(fill_amount(gas), gas_per_condensation);
	if (consumed <= 0) {
		return false;
	}
	vec4 remaining = remove_primary_component(gas, consumed);
	bool yields_liquid = consumed == gas_per_condensation;
	if (yields_liquid && component_capacity(remaining, liquid_id, FULL_QUANTITY) < liquid_quantity) {
		return false;
	}
	if (!chance_roll(gas_coord, pass_kind + 8 * REACTION_CONDENSATION, parameters)) {
		return false;
	}
	next_gas = yields_liquid ? add_component(remaining, liquid_id, liquid_quantity, FULL_QUANTITY) : remaining;
	return true;
}

// Light gases mirror the liquid rules upside down: they rise instead of falling, fill
// cells from the ceiling down to their normal pressure, and level out across the
// half-hex stagger between neighboring columns through the side-flow offset.
int light_gas_capacity(vec4 target, int gas_id) {
	int target_id = terrain_id(target);
	bool has_slot = target_id == gas_id
		|| (has_secondary(target)
			? secondary_terrain_id(target) == gas_id
			: is_moving(target_id) || is_passable(target_id));
	return has_slot ? max(0, normal_quantity(gas_id) - component_fill(target, gas_id)) : 0;
}

int light_gas_rise_amount(vec4 source, vec4 target) {
	int gas_id = terrain_id(source);
	return min(fill_amount(source), min(fall_rate(gas_id), light_gas_capacity(target, gas_id)));
}

int light_gas_side_up_amount(vec4 source, vec4 target) {
	int gas_id = terrain_id(source);
	if (!can_side_up(gas_id)) {
		return 0;
	}
	int equilibrium_distance = fill_amount(source) - component_fill(target, gas_id) + side_flow_offset(gas_id);
	return min(
		min(fill_amount(source), side_up_rate(gas_id)),
		min(light_gas_capacity(target, gas_id), equilibrium_distance / 2)
	);
}

bool light_gas_top_blocked(ivec2 coord, vec4 source) {
	// The row above the map is open sky, never a ceiling.
	ivec2 above_coord = hex_neighbor(coord, HEX_DIRECTION_UP);
	return in_bounds(above_coord) && light_gas_rise_amount(source, read_cell(above_coord)) <= 0;
}

bool light_gas_top_side_blocked(ivec2 coord, vec4 source) {
	ivec2 top_side_coord = hex_neighbor(coord, hex_opposite_direction(pair_direction()));
	return !in_bounds(top_side_coord) || light_gas_side_up_amount(source, read_cell(top_side_coord)) <= 0;
}

int light_gas_ascent_amount(ivec2 coord, vec4 source, vec4 target) {
	if (is_vertical_pass()) {
		return light_gas_rise_amount(source, target);
	}
	int amount = light_gas_side_up_amount(source, target);
	return amount > 0 && light_gas_top_blocked(coord, source) ? amount : 0;
}

// Gas only moves down once every higher exit is blocked and it holds more than the
// lower cell plus the height between them: a full cell vertically, the side-flow
// offset diagonally. It must stay primary there, because gas pushed into a denser
// medium would only bubble straight back.
int light_gas_descent_amount(ivec2 coord, vec4 source, vec4 target) {
	int gas_id = terrain_id(source);
	int target_id = terrain_id(target);
	bool vertical = is_vertical_pass();
	if ((!vertical && !can_side_down(gas_id)) || (target_id != gas_id && density(target_id) >= density(gas_id))) {
		return 0;
	}
	int height = vertical ? normal_quantity(gas_id) : side_flow_offset(gas_id);
	int rate = vertical ? fall_rate(gas_id) : side_down_rate(gas_id);
	int excess = fill_amount(source) - height - component_fill(target, gas_id);
	int amount = min(rate, min(light_gas_capacity(target, gas_id), excess / 2));
	if (amount <= 0 || !light_gas_top_blocked(coord, source)) {
		return 0;
	}
	return vertical || light_gas_top_side_blocked(coord, source) ? amount : 0;
}

// The top edge of the map is open sky: light gas in the top row keeps rising and
// leaves the world.
vec4 vent_light_gas(vec4 cell) {
	int primary_id = terrain_id(cell);
	if (is_light_gas(primary_id)) {
		return remove_primary_component(cell, min(fill_amount(cell), fall_rate(primary_id)));
	}
	int secondary_id = secondary_terrain_id(cell);
	if (has_secondary(cell) && is_light_gas(secondary_id)) {
		return remove_secondary_component(cell, min(secondary_fill_amount(cell), fall_rate(secondary_id)));
	}
	return cell;
}

bool resolve_authored_contact(ivec2 a_coord, ivec2 b_coord, vec4 a, vec4 b, out vec4 next_a, out vec4 next_b) {
	next_a = a;
	next_b = b;
	vec4 reaction = read_reaction_header(terrain_id(a), terrain_id(b));
	int opcode = reaction_byte(reaction, 0);
	if (opcode == 0) return false;
	if (opcode == REACTION_BOILING) {
		return resolve_heat_source_solidification(a_coord, b_coord, a, b, reaction, next_a, next_b);
	}
	if (opcode == REACTION_CONDENSATION) {
		return is_vertical_pass()
			&& resolve_condensation(b_coord, b, reaction, read_reaction_parameters(terrain_id(a), terrain_id(b)), next_b);
	}
	if (opcode == REACTION_MUTUAL_REPLACEMENT) {
		vec4 parameters = read_reaction_parameters(terrain_id(a), terrain_id(b));
		next_a = make_cell(reaction_byte(reaction, 1), reaction_byte(parameters, 0));
		next_b = make_cell(reaction_byte(reaction, 2), reaction_byte(parameters, 1));
		return true;
	}
	if (opcode == REACTION_PERSISTENT_IGNITION) {
		int a_burn_product = persistent_burn_product(terrain_id(a));
		if (a_burn_product != NO_BURN_PRODUCT_ID) {
			next_a = add_component(a, a_burn_product, persistent_burn_ignition_quantity(terrain_id(a)), storage_capacity(a_burn_product));
		} else {
			int gas = persistent_burn_product(terrain_id(b));
			next_b = add_component(b, gas, persistent_burn_ignition_quantity(terrain_id(b)), storage_capacity(gas));
		}
		return true;
	}
	if (opcode == REACTION_CATALYTIC_LIQUID_CONVERSION && is_vertical_pass()) {
		vec4 parameters = read_reaction_parameters(terrain_id(a), terrain_id(b));
		int acid = reaction_byte(reaction, 2);
		int sulfur_side = persistent_burn_product(terrain_id(a)) != NO_BURN_PRODUCT_ID ? 0 : 1;
		vec4 sulfur_cell = sulfur_side == 0 ? a : b;
		vec4 water_cell = sulfur_side == 0 ? b : a;
		int water_per_sulfur = max(1, reaction_byte(parameters, 0));
		int sulfur_fill = fill_amount(sulfur_cell);
		int water_fill = fill_amount(water_cell);
		int acid_fill = min(water_fill, sulfur_fill * water_per_sulfur);
		if (acid_fill <= 0) return false;
		int sulfur_consumed = int(ceil(float(acid_fill) / float(water_per_sulfur)));
		vec4 next_sulfur = remove_primary_component(sulfur_cell, sulfur_consumed);
		vec4 next_water = make_components(
			acid,
			acid_fill,
			terrain_id(water_cell),
			water_fill - acid_fill
		);
		if (sulfur_side == 0) {
			next_a = next_sulfur;
			next_b = next_water;
		} else {
			next_a = next_water;
			next_b = next_sulfur;
		}
		return true;
	}
	if (opcode == REACTION_EROSION) {
		vec4 parameters = read_reaction_parameters(terrain_id(a), terrain_id(b));
		int water = reaction_byte(reaction, 1);
		int solid_per_fluid = max(1, reaction_byte(parameters, 0));
		int minimum_consumed = max(1, reaction_byte(parameters, 1));
		int maximum_consumed = max(minimum_consumed, reaction_byte(parameters, 2));
		int consumed = min(fill_amount(a), min(maximum_consumed, max(minimum_consumed, fill_amount(b) / solid_per_fluid)));
		if (consumed <= 0) return false;
		next_a = add_component(remove_primary_component(a, consumed), water, consumed, storage_capacity(water));
		next_b = fill_amount(b) <= consumed * solid_per_fluid ? make_cell(reaction_byte(reaction, 2), normal_quantity(reaction_byte(reaction, 2))) : remove_primary_component(b, consumed * solid_per_fluid);
		return true;
	}
	if (opcode == REACTION_GAS_ABSORPTION) {
		vec4 parameters = read_reaction_parameters(terrain_id(a), terrain_id(b));
		int gas_side = motion(terrain_id(a)) == MOTION_DENSE_GAS ? 0 : 1;
		int gas_fill = gas_side == 0 ? fill_amount(a) : fill_amount(b);
		if (gas_fill < reaction_byte(parameters, 0)) return false;
		int acid = reaction_byte(reaction, 2);
		int consumed = min(gas_fill, reaction_byte(parameters, 1));
		int acid_fill = max(1, consumed * reaction_byte(parameters, 3) / max(1, reaction_byte(parameters, 2)));
		if (gas_side == 0) {
			next_a = remove_primary_component(a, consumed);
			next_b = make_cell(acid, min(fill_amount(b), acid_fill));
		} else {
			next_b = remove_primary_component(b, consumed);
			next_a = make_cell(acid, min(fill_amount(a), acid_fill));
		}
		return true;
	}
	return false;
}

bool resolve_persistent_burn(vec4 a, vec4 b, out vec4 next_a, out vec4 next_b) {
	next_a = a;
	next_b = b;
	// The even vertical pairing covers every in-bounds row exactly once per tick.
	if (pass_kind != PASS_VERTICAL_EVEN) return false;
	int a_burn_product = persistent_burn_product(terrain_id(a));
	int b_burn_product = persistent_burn_product(terrain_id(b));
	bool burns_a = a_burn_product != NO_BURN_PRODUCT_ID && a_burn_product == secondary_terrain_id(a) && secondary_fill_amount(a) > 0;
	bool burns_b = b_burn_product != NO_BURN_PRODUCT_ID && b_burn_product == secondary_terrain_id(b) && secondary_fill_amount(b) > 0;
	if (!burns_a && !burns_b) return false;
	if (burns_a) {
		int a_id = terrain_id(a);
		int numerator = persistent_burn_bonus_frequency_numerator(a_id);
		int period = max(1, persistent_burn_bonus_frequency_period(a_id));
		bool bonus_tick = (simulation_tick * numerator + fill_amount(a)) % period < numerator;
		int consumed = min(fill_amount(a), persistent_burn_base_consumption(a_id) + (bonus_tick ? persistent_burn_bonus_consumption(a_id) : 0));
		int gas = a_burn_product;
		int produced = consumed * persistent_burn_product_per_consumed(a_id) + (bonus_tick ? persistent_burn_bonus_product(a_id) : 0);
		next_a = remove_primary_component(a, consumed);
		if (fill_amount(next_a) > 0) next_a = add_component(next_a, gas, produced, storage_capacity(gas));
		else next_a = make_cell(gas, min(storage_capacity(gas), secondary_fill_amount(a) + produced));
	}
	if (burns_b) {
		int b_id = terrain_id(b);
		int numerator = persistent_burn_bonus_frequency_numerator(b_id);
		int period = max(1, persistent_burn_bonus_frequency_period(b_id));
		bool bonus_tick = (simulation_tick * numerator + fill_amount(b)) % period < numerator;
		int consumed = min(fill_amount(b), persistent_burn_base_consumption(b_id) + (bonus_tick ? persistent_burn_bonus_consumption(b_id) : 0));
		int gas = b_burn_product;
		int produced = consumed * persistent_burn_product_per_consumed(b_id) + (bonus_tick ? persistent_burn_bonus_product(b_id) : 0);
		next_b = remove_primary_component(b, consumed);
		if (fill_amount(next_b) > 0) next_b = add_component(next_b, gas, produced, storage_capacity(gas));
		else next_b = make_cell(gas, min(storage_capacity(gas), secondary_fill_amount(b) + produced));
	}
	return true;
}

bool direct_bottom_blocked(ivec2 coord, vec4 source) {
	ivec2 below_coord = hex_neighbor(coord, HEX_DIRECTION_DOWN);
	return is_below_world(below_coord) || !in_bounds(below_coord) || fall_transfer_amount(source, read_cell(below_coord)) <= 0;
}

bool bottom_side_blocked(ivec2 coord, vec4 source) {
	ivec2 bottom_side_coord = pair_neighbor(coord);
	return !in_bounds(bottom_side_coord) || side_down_transfer_amount(source, read_cell(bottom_side_coord)) <= 0;
}

int downward_transfer_amount(ivec2 coord, vec4 source, vec4 target) {
	if (is_light_gas(terrain_id(source))) {
		return light_gas_descent_amount(coord, source, target);
	}
	if (is_vertical_pass()) {
		return fall_transfer_amount(source, target);
	}
	int amount = side_down_transfer_amount(source, target);
	return amount > 0 && direct_bottom_blocked(coord, source) ? amount : 0;
}

int upward_transfer_amount(ivec2 coord, vec4 source, vec4 target) {
	if (is_light_gas(terrain_id(source))) {
		return light_gas_ascent_amount(coord, source, target);
	}
	if (is_vertical_pass()) {
		return 0;
	}
	int amount = side_up_transfer_amount(source, target);
	return amount > 0 && direct_bottom_blocked(coord, source) && bottom_side_blocked(coord, source) ? amount : 0;
}

void resolve_pair(
	ivec2 a_coord,
	ivec2 b_coord,
	vec4 a,
	vec4 b,
	out vec4 next_a,
	out vec4 next_b
) {
	// The even vertical pass covers every in-bounds cell exactly once per tick.
	if (pass_kind == PASS_VERTICAL_EVEN) {
		a = resolve_boiling_at(a_coord, a);
		if (in_bounds(b_coord)) {
			b = resolve_boiling_at(b_coord, b);
		}
	}
	next_a = a;
	next_b = b;
	if (resolve_authored_contact(a_coord, b_coord, a, b, next_a, next_b)) {
		return;
	}
	if (resolve_persistent_burn(a, b, next_a, next_b)) {
		return;
	}
	if (resolve_secondary_pair(a, b, is_vertical_pass(), next_a, next_b)) {
		return;
	}
	if (resolve_same_primary_pressure(a, b, next_a, next_b)) {
		return;
	}
	int sinking_amount = downward_transfer_amount(a_coord, a, b);
	if (sinking_amount > 0) {
		transfer_primary(a, b, sinking_amount, next_a, next_b);
		return;
	}
	int rising_amount = upward_transfer_amount(b_coord, b, a);
	if (rising_amount > 0) {
		transfer_primary(b, a, rising_amount, next_b, next_a);
	}
}

void fragment() {
	ivec2 coord = ivec2(floor(UV * world_size));
	vec4 current = read_cell(coord);
	ivec2 owner = pair_owner_for(coord);
	vec4 result = current;
	ivec2 neighbor = pair_neighbor(owner);
	if (in_bounds(owner) && (in_bounds(neighbor) || is_below_world(neighbor))) {
		bool output_a = coord.x == owner.x && coord.y == owner.y;
		vec4 a = read_cell(owner);
		vec4 b = read_cell_with_solid_floor(neighbor);
		vec4 next_a;
		vec4 next_b;
		resolve_pair(owner, neighbor, a, b, next_a, next_b);
		result = output_a ? next_a : next_b;
	} else if (is_vertical_pass() && owner.y < 0) {
		result = vent_light_gas(current);
	}
	result.b =float(resolved_light(coord, current, result)) / 255.0;
	COLOR = result;
}
