@tool
## Resource-driven tuning shared by every world-space explosive.
class_name ExplosionDefinition
extends Resource


@export_range(0, 64, 1) var blast_radius := 0
@export_range(0, 64, 1) var vaporize_radius := 0
@export_range(0, 64, 1) var player_kill_radius := 0
## Deprecated authoring field retained for old scenes/tests.  New resources must
## use vaporize_radius and player_kill_radius.
@export_range(0, 64, 1) var lethal_radius := 0
@export var effect_color := Color(0.95, 0.56, 0.22, 1.0)
@export var large_feedback := false
@export_range(0.0, 10.0, 0.01) var chain_fuse_seconds := 0.3
@export_range(0.0, 4000.0, 1.0) var blast_impulse := 0.0
## Optional cloud added only when the matching perk enables it for the source item.
@export var perk_terrain_emission: TerrainEmissionDefinition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if blast_radius <= 0:
		errors.append("explosion blast_radius must be positive")
	if vaporize_radius < 0 or vaporize_radius > blast_radius:
		errors.append("explosion vaporize_radius must be between zero and blast_radius")
	if player_kill_radius < 0 or player_kill_radius > blast_radius:
		errors.append("explosion player_kill_radius must be between zero and blast_radius")
	if lethal_radius < 0 or lethal_radius > blast_radius:
		errors.append("explosion lethal_radius must be between zero and blast_radius")
	if chain_fuse_seconds < 0.0:
		errors.append("explosion chain_fuse_seconds must be non-negative")
	if blast_impulse < 0.0:
		errors.append("explosion blast_impulse must be non-negative")
	if perk_terrain_emission != null:
		for error in perk_terrain_emission.validate():
			errors.append("explosion perk emission: %s" % error)
	return errors


func effective_vaporize_radius() -> int:
	return vaporize_radius if vaporize_radius > 0 or lethal_radius <= 0 else lethal_radius


func effective_player_kill_radius() -> int:
	return player_kill_radius if player_kill_radius > 0 or lethal_radius <= 0 else lethal_radius
