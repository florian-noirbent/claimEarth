shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D source_world : filter_nearest, repeat_disable;
uniform sampler2D rule_texture : filter_nearest, repeat_disable;
uniform sampler2D reaction_texture : filter_nearest, repeat_disable;
uniform sampler2D standard_light_sources : filter_nearest, repeat_disable;
uniform vec2 world_size = vec2(1.0, 1.0);
uniform int pass_kind = 0;
uniform int simulation_tick = 0;
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
const int MOTION_LIQUID = 2;
const int MOTION_GAS = 3;
const int MOTION_DENSE_GAS = 4;
const int AIR_QUANTITY = 64;
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
	return texture(rule_texture, (vec2(float(terrain_id), float(row)) + vec2(0.5)) / vec2(256.0, 5.0));
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

vec4 read_reaction(int a, int b) {
	return texture(reaction_texture, (vec2(float(b & 15), float(a & 15)) + vec2(0.5)) / vec2(16.0));
}

int reaction_byte(vec4 reaction, int channel) {
	if (channel == 0) return byte_from_float(reaction.r);
	if (channel == 1) return byte_from_float(reaction.g);
	if (channel == 2) return byte_from_float(reaction.b);
	return byte_from_float(reaction.a);
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

vec4 air_cell() {
	return make_cell(air_id(), AIR_QUANTITY);
}

vec4 vacuum_cell() {
	return make_cell(air_id(), 0);
}

bool is_moving(int id) {
	return motion(id) != MOTION_STABLE;
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

bool component_is_liquid(int component_id, int component_quantity) {
	return component_quantity > 0 && motion(component_id) == MOTION_LIQUID;
}

bool liquid_contact(vec4 a, vec4 b) {
	int a_primary = terrain_id(a);
	int a_secondary = secondary_terrain_id(a);
	int b_primary = terrain_id(b);
	int b_secondary = secondary_terrain_id(b);
	int a_primary_quantity = fill_amount(a);
	int a_secondary_quantity = secondary_fill_amount(a);
	int b_primary_quantity = fill_amount(b);
	int b_secondary_quantity = secondary_fill_amount(b);
	if (component_is_liquid(a_primary, a_primary_quantity)) {
		if (component_is_liquid(b_primary, b_primary_quantity) && a_primary != b_primary) return true;
		if (component_is_liquid(b_secondary, b_secondary_quantity) && a_primary != b_secondary) return true;
	}
	if (component_is_liquid(a_secondary, a_secondary_quantity)) {
		if (component_is_liquid(b_primary, b_primary_quantity) && a_secondary != b_primary) return true;
		if (component_is_liquid(b_secondary, b_secondary_quantity) && a_secondary != b_secondary) return true;
	}
	bool a_internal_contact = component_is_liquid(a_primary, a_primary_quantity)
		&& component_is_liquid(a_secondary, a_secondary_quantity)
		&& a_primary != a_secondary;
	bool b_internal_contact = component_is_liquid(b_primary, b_primary_quantity)
		&& component_is_liquid(b_secondary, b_secondary_quantity)
		&& b_primary != b_secondary;
	return a_internal_contact || b_internal_contact;
}

int directional_rate(int component_id, bool vertical, bool moves_down) {
	if (motion(component_id) == MOTION_GAS) {
		return MAX_STORED_QUANTITY;
	}
	if (vertical) {
		return fall_rate(component_id);
	}
	return moves_down ? side_down_rate(component_id) : side_up_rate(component_id);
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
	if (target_secondary_quantity <= 0 && (is_moving(target_primary_id) || is_passable(target_primary_id))) {
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

bool resolve_same_primary_pressure(vec4 a, vec4 b, out vec4 next_a, out vec4 next_b) {
	next_a = a;
	next_b = b;
	int component_id = terrain_id(a);
	if (component_id != terrain_id(b) || fill_amount(a) <= 0 || fill_amount(b) <= 0) {
		return false;
	}
	int a_quantity = fill_amount(a);
	int b_quantity = fill_amount(b);
	if (motion(component_id) != MOTION_GAS && motion(component_id) != MOTION_DENSE_GAS && a_quantity <= FULL_QUANTITY && b_quantity <= FULL_QUANTITY) {
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

bool resolve_authored_contact(vec4 a, vec4 b, out vec4 next_a, out vec4 next_b) {
	next_a = a;
	next_b = b;
	vec4 reaction = read_reaction(terrain_id(a), terrain_id(b));
	int kind = reaction_byte(reaction, 0);
	if (kind == 0) return false;
	if (kind == 5) {
		next_a = air_cell();
		next_b = make_cell(stone_id(), maximum_quantity(stone_id()));
		return true;
	}
	if (kind == 2) {
		int gas = reaction_byte(reaction, 3);
		int a_burn_product = persistent_burn_product(terrain_id(a));
		if (a_burn_product != NO_BURN_PRODUCT_ID && a_burn_product == gas) next_a = add_component(a, gas, 1, storage_capacity(gas));
		else next_b = add_component(b, gas, 1, storage_capacity(gas));
		return true;
	}
	if (kind == 1 && is_vertical_pass()) {
		int acid = reaction_byte(reaction, 2);
		if (persistent_burn_product(terrain_id(a)) != NO_BURN_PRODUCT_ID) {
			next_a = remove_primary_component(a, min(1, fill_amount(a)));
			next_b = make_cell(acid, fill_amount(b));
		} else {
			next_b = remove_primary_component(b, min(1, fill_amount(b)));
			next_a = make_cell(acid, fill_amount(a));
		}
		return true;
	}
	if (kind == 3) {
		int water = reaction_byte(reaction, 1);
		int consumed = min(fill_amount(a), max(1, fill_amount(b) / 2));
		if (consumed <= 0) return false;
		next_a = make_cell(water, consumed);
		next_b = fill_amount(b) <= consumed * 2 ? air_cell() : remove_primary_component(b, consumed * 2);
		return true;
	}
	if (kind == 4) {
		int gas_side = motion(terrain_id(a)) == MOTION_DENSE_GAS ? 0 : 1;
		int gas_fill = gas_side == 0 ? fill_amount(a) : fill_amount(b);
		if (gas_fill < 3) return false;
		int acid = reaction_byte(reaction, 2);
		int consumed = min(gas_fill, normal_quantity(terrain_id(gas_side == 0 ? a : b)));
		int acid_fill = max(1, consumed * normal_quantity(acid) / (normal_quantity(terrain_id(gas_side == 0 ? a : b)) * 3));
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
		int extra = (simulation_tick * 27 + fill_amount(a)) % 100 < 27 ? 1 : 0;
		int consumed = min(fill_amount(a), 1 + extra);
		int gas = a_burn_product;
		int produced = consumed * 7 + extra;
		next_a = remove_primary_component(a, consumed);
		if (fill_amount(next_a) > 0) next_a = add_component(next_a, gas, produced, storage_capacity(gas));
		else next_a = make_cell(gas, min(storage_capacity(gas), secondary_fill_amount(a) + produced));
	}
	if (burns_b) {
		int extra = (simulation_tick * 27 + fill_amount(b)) % 100 < 27 ? 1 : 0;
		int consumed = min(fill_amount(b), 1 + extra);
		int gas = b_burn_product;
		int produced = consumed * 7 + extra;
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

void resolve_pair(
	ivec2 a_coord,
	ivec2 b_coord,
	vec4 a,
	vec4 b,
	out vec4 next_a,
	out vec4 next_b
) {
	next_a = a;
	next_b = b;
	if (resolve_authored_contact(a, b, next_a, next_b)) {
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
	if (is_vertical_pass()) {
		int amount = fall_transfer_amount(a, b);
		if (amount > 0) {
			transfer_primary(a, b, amount, next_a, next_b);
		}
		return;
	}
	if (direct_bottom_blocked(a_coord, a)) {
		int amount = side_down_transfer_amount(a, b);
		if (amount > 0) {
			transfer_primary(a, b, amount, next_a, next_b);
			return;
		}
	}
	if (direct_bottom_blocked(b_coord, b) && bottom_side_blocked(b_coord, b)) {
		int amount = side_up_transfer_amount(b, a);
		if (amount > 0) {
			transfer_primary(b, a, amount, next_b, next_a);
		}
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
	}
	result.b = float(resolved_light(coord, current, result)) / 255.0;
	COLOR = result;
}
