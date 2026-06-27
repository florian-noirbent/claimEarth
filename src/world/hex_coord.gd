## Represents axial hex coordinates and neighbor/distance operations.
class_name HexCoord
extends RefCounted


const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


var q: int
var r: int


func _init(q_value: int = 0, r_value: int = 0) -> void:
	q = q_value
	r = r_value


func s() -> int:
	return -q - r


func equals(other: HexCoord) -> bool:
	return q == other.q and r == other.r


func add(other: HexCoord) -> HexCoord:
	return HexCoord.new(q + other.q, r + other.r)


func neighbor(direction: int) -> HexCoord:
	var offset := NEIGHBOR_OFFSETS[wrapi(direction, 0, NEIGHBOR_OFFSETS.size())]
	return HexCoord.new(q + offset.x, r + offset.y)


func neighbors() -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	for offset in NEIGHBOR_OFFSETS:
		result.append(HexCoord.new(q + offset.x, r + offset.y))
	return result


func distance_to(other: HexCoord) -> int:
	return int((abs(q - other.q) + abs(r - other.r) + abs(s() - other.s())) / 2)


func to_offset_odd_q() -> Vector2i:
	var col := q
	var row := r + int((q - (q & 1)) / 2)
	return Vector2i(col, row)


func to_world_position(hex_size: float = 1.0) -> Vector2:
	var x := hex_size * 1.5 * float(q)
	var y := hex_size * sqrt(3.0) * (float(r) + float(q) / 2.0)
	return Vector2(x, y)


func as_string() -> String:
	return "(%d,%d)" % [q, r]


static func from_offset_odd_q(col: int, row: int) -> HexCoord:
	var q_value := col
	var r_value := row - int((col - (col & 1)) / 2)
	return HexCoord.new(q_value, r_value)
