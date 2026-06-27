## Provides deterministic seed helpers shared by generation and tests.
class_name SeedUtils
extends RefCounted


const _FNV_OFFSET: int = 0x811C9DC5
const _FNV_PRIME: int = 0x01000193


static func seed_from_text(value: String) -> int:
	var bytes := value.to_utf8_buffer()
	return _fnv1a_32(bytes)


static func derive_seed(base_seed: int, salt: String) -> int:
	return _fnv1a_32((str(base_seed) + ":" + salt).to_utf8_buffer())


static func create_rng(run_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	return rng


static func _fnv1a_32(bytes: PackedByteArray) -> int:
	var content_hash := _FNV_OFFSET
	for byte in bytes:
		content_hash = content_hash ^ byte
		content_hash = int((content_hash * _FNV_PRIME) & 0xFFFFFFFF)
	return content_hash
