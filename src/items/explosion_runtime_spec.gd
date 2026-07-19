## Per-detonation explosion values.  Perk/item owners resolve this from the shared
## definition instead of modifying an authored resource.
class_name ExplosionRuntimeSpec
extends RefCounted


var definition: ExplosionDefinition
var blast_radius := 0
var vaporize_radius := 0
var player_kill_radius := 0
var blast_impulse := 0.0
var perk_terrain_emissions: Array[TerrainEmissionDefinition] = []

## Optional terrain-specific extension point. The callable receives a
## TerrainDefinition and returns extra vaporize hexes for that terrain. This is
## deliberately separate from the destructive radius so perks can affect only
## fluids without silently increasing solid destruction.
var fluid_vaporize_radius_bonus := Callable()

## Optional chance (0..1) for a blast-reaction cell to vaporize instead of using
## its normal replacement. The callable receives the source TerrainDefinition
## and the offset cell, which keeps the decision resource-owned and deterministic.
var blast_vaporize_chance := Callable()


static func from_definition(source: ExplosionDefinition) -> ExplosionRuntimeSpec:
	var result := ExplosionRuntimeSpec.new()
	result.definition = source
	if source == null:
		return result
	result.blast_radius = source.blast_radius
	result.vaporize_radius = source.effective_vaporize_radius()
	result.player_kill_radius = source.effective_player_kill_radius()
	result.blast_impulse = source.blast_impulse
	return result


func vaporize_radius_for(definition_value: TerrainDefinition) -> int:
	var bonus := 0
	if fluid_vaporize_radius_bonus.is_valid():
		bonus = maxi(0, int(fluid_vaporize_radius_bonus.call(definition_value)))
	return vaporize_radius + bonus


func blast_vaporize_chance_for(definition_value: TerrainDefinition, cell: Vector2i) -> float:
	if not blast_vaporize_chance.is_valid():
		return 0.0
	return clampf(float(blast_vaporize_chance.call(definition_value, cell)), 0.0, 1.0)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if blast_radius <= 0:
		errors.append("explosion blast_radius must be positive")
	if vaporize_radius < 0 or vaporize_radius > blast_radius:
		errors.append("explosion vaporize_radius must be between zero and blast_radius")
	if player_kill_radius < 0 or player_kill_radius > blast_radius:
		errors.append("explosion player_kill_radius must be between zero and blast_radius")
	if blast_impulse < 0.0:
		errors.append("explosion blast_impulse must be non-negative")
	return errors
