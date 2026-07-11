// Canonical axial directions. Keep these aligned with HexCoord.NEIGHBOR_OFFSETS.
// 0 down-right, 1 up-right, 2 up, 3 up-left, 4 down-left, 5 down.
const int HEX_DIRECTION_DOWN_RIGHT = 0;
const int HEX_DIRECTION_UP_RIGHT = 1;
const int HEX_DIRECTION_UP = 2;
const int HEX_DIRECTION_UP_LEFT = 3;
const int HEX_DIRECTION_DOWN_LEFT = 4;
const int HEX_DIRECTION_DOWN = 5;

ivec2 hex_neighbor(ivec2 cell, int direction) {
	int parity = cell.x & 1;
	if (direction == HEX_DIRECTION_DOWN_RIGHT) {
		return cell + ivec2(1, parity);
	}
	if (direction == HEX_DIRECTION_UP_RIGHT) {
		return cell + ivec2(1, parity - 1);
	}
	if (direction == HEX_DIRECTION_UP) {
		return cell + ivec2(0, -1);
	}
	if (direction == HEX_DIRECTION_UP_LEFT) {
		return cell + ivec2(-1, parity - 1);
	}
	if (direction == HEX_DIRECTION_DOWN_LEFT) {
		return cell + ivec2(-1, parity);
	}
	return cell + ivec2(0, 1);
}

vec2 hex_neighbor(vec2 cell, int direction) {
	float parity = mod(abs(cell.x), 2.0);
	if (direction == HEX_DIRECTION_DOWN_RIGHT) {
		return cell + vec2(1.0, parity);
	}
	if (direction == HEX_DIRECTION_UP_RIGHT) {
		return cell + vec2(1.0, parity - 1.0);
	}
	if (direction == HEX_DIRECTION_UP) {
		return cell + vec2(0.0, -1.0);
	}
	if (direction == HEX_DIRECTION_UP_LEFT) {
		return cell + vec2(-1.0, parity - 1.0);
	}
	if (direction == HEX_DIRECTION_DOWN_LEFT) {
		return cell + vec2(-1.0, parity);
	}
	return cell + vec2(0.0, 1.0);
}

int hex_distance(ivec2 a, ivec2 b) {
	int a_r = a.y - (a.x - (a.x & 1)) / 2;
	int b_r = b.y - (b.x - (b.x & 1)) / 2;
	int dq = a.x - b.x;
	int dr = a_r - b_r;
	int ds = -dq - dr;
	return (abs(dq) + abs(dr) + abs(ds)) / 2;
}
