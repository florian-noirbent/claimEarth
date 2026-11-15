@tool
## Resource-driven generation contract for one kind of generated world item.
class_name GeneratedItemPlacementDefinition
extends Resource


func validate() -> PackedStringArray:
	return PackedStringArray()


func required_edge_clearance() -> int:
	return 0


## Lets a kind skip an unsuitable candidate anchor; the pass then probes the next candidate
## in its deterministic order. Must only read the context.
func accepts_anchor(_context: GenerationContext, _anchor: Vector2i) -> bool:
	return true


func prepare_terrain(_context: GenerationContext, _anchor: Vector2i) -> bool:
	return true


func record_spawn(_context: GenerationContext, _anchor: Vector2i, _spawn_seed: int) -> bool:
	push_error("Generated item placement definition must implement record_spawn().")
	return false
