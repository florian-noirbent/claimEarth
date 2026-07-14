@tool
## Resource-driven tuning shared by every world-space explosive.
class_name ExplosionDefinition
extends Resource


@export_range(0, 64, 1) var blast_radius := 0
@export_range(0, 64, 1) var lethal_radius := 0
@export var effect_color := Color(0.95, 0.56, 0.22, 1.0)
@export var large_feedback := false
@export_range(0.0, 10.0, 0.01) var chain_fuse_seconds := 0.3
@export_range(0.0, 4000.0, 1.0) var blast_impulse := 0.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if blast_radius <= 0:
		errors.append("explosion blast_radius must be positive")
	if lethal_radius < 0 or lethal_radius > blast_radius:
		errors.append("explosion lethal_radius must be between zero and blast_radius")
	if chain_fuse_seconds < 0.0:
		errors.append("explosion chain_fuse_seconds must be non-negative")
	if blast_impulse < 0.0:
		errors.append("explosion blast_impulse must be non-negative")
	return errors
