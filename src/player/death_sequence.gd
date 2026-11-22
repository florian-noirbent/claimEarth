## How the body comes apart for one death cause: the anticipation while it is still whole,
## the burst that frees its parts, how the loose parts fly and look over time, and which
## world effects the sequence asks for. Times are shares of the death beat, so a sequence
## fits whatever beat it is played in. Curves run over the beat (x from 0 to 1); an empty
## curve leaves its channel at rest.
class_name DeathSequence
extends Resource


enum DetachOrder {
	RANDOM,
	## The highest parts come off first.
	TOP_DOWN,
	## The lowest parts come off first, so the body collapses onto itself.
	BOTTOM_UP,
}


@export_group("Timing")
## When the first part comes off, as a share of the beat. 0 bursts at once.
@export_range(0.0, 1.0, 0.001) var burst_at := 0.0
## Time over which the remaining parts follow, as a share of the beat.
@export_range(0.0, 1.0, 0.001) var detach_stagger := 0.0
@export var detach_order := DetachOrder.RANDOM
## Delay of the last part's look curves behind the first one's, in detach order.
@export_range(0.0, 1.0, 0.001) var look_stagger := 0.0

@export_group("Anticipation")
## Animation state the whole body holds until it bursts; empty keeps its last pose.
@export var pose: StringName = &""
## Lets the limbs hang limp while the body is still whole.
@export var limp := false
## Body length along the push direction (or its height without one); 1 is unsquashed.
@export var squash: Curve
## Random body offset in world px.
@export var shake: Curve

@export_group("Burst")
## Share of the body's velocity every part keeps.
@export_range(0.0, 2.0, 0.01) var inherit_velocity := 1.0
## Share of the speed into the surface a lethal impact hit that the parts bounce back with.
@export_range(0.0, 1.0, 0.01) var surface_bounce := 0.3
## Speed away from the body's center, in px/s.
@export_range(0.0, 3000.0, 1.0) var radial_speed_min := 0.0
@export_range(0.0, 3000.0, 1.0) var radial_speed_max := 0.0
## Speed along the push direction: away from a blast or off the surface a fall hit.
@export_range(0.0, 3000.0, 1.0) var push_speed_min := 0.0
@export_range(0.0, 3000.0, 1.0) var push_speed_max := 0.0
@export_range(0.0, 180.0, 0.1) var push_spread_degrees := 30.0
## Largest speed to either side along the surface a lethal impact hit.
@export_range(0.0, 3000.0, 1.0) var surface_scatter_speed := 0.0
## Extra upward speed.
@export_range(-3000.0, 3000.0, 1.0) var lift_speed_min := 0.0
@export_range(-3000.0, 3000.0, 1.0) var lift_speed_max := 0.0
## Spin in degrees per second; each part picks a direction.
@export_range(0.0, 3600.0, 1.0) var spin_degrees_min := 0.0
@export_range(0.0, 3600.0, 1.0) var spin_degrees_max := 0.0
## Size of a loose part relative to the part on the body.
@export_range(0.25, 4.0, 0.01) var gib_scale := 1.0

@export_group("Featured parts")
## Rig parts that stand out, such as the head with its helmet and the boots.
@export var featured_parts: Array[StringName] = []
@export_range(0.0, 4.0, 0.01) var featured_speed_scale := 1.0
@export_range(0.0, 1.0, 0.01) var featured_restitution := 0.6
## Featured parts ignore the dissolve and melt curves and stay behind.
@export var featured_stay_solid := false
## Share of the tint curve featured parts take, so they can keep their own colors.
@export_range(0.0, 1.0, 0.01) var featured_tint_scale := 1.0

@export_group("Physics")
@export_range(0.0, 4000.0, 1.0) var gravity := 1400.0
@export_range(0.0, 20.0, 0.01) var air_drag := 0.4
@export_range(0.0, 20.0, 0.01) var spin_drag := 0.6
@export_range(0.0, 1.0, 0.01) var restitution := 0.4
@export_range(0.0, 2.0, 0.01) var friction := 0.3
## Multiplies the viscosity of the liquid a part is in.
@export_range(0.0, 8.0, 0.01) var liquid_drag_scale := 1.0
## Share of gravity a liquid cancels; 1 floats.
@export_range(0.0, 2.0, 0.01) var buoyancy := 0.0

@export_group("Look")
## Mix toward flash_color.
@export var flash: Curve
@export var flash_color := Color.WHITE
## Mix toward the part's brightness colored with tint_color.
@export var tint: Curve
@export var tint_color := Color.WHITE
## Burn from the painted colors to scorch_color.
@export var scorch: Curve
@export var scorch_color := Color(0.06, 0.045, 0.04)
## Glowing specks of ember_color.
@export var ember: Curve
@export var ember_color := Color(1.0, 0.55, 0.12)
## Share of the part eaten away, behind a rim of dissolve_edge_color.
@export var dissolve: Curve
@export var dissolve_edge_color := Color(1.0, 0.6, 0.15)
@export_range(0.0, 0.5, 0.005) var dissolve_edge_width := 0.12
## 0 eats the part away in patches, 1 from its top down.
@export_range(0.0, 1.0, 0.01) var dissolve_top_down := 0.0
## How far the part runs down in drips, as a share of its texture.
@export var melt: Curve
## Mix of the dark silhouette outline toward outline_glow_color, which keeps charred
## parts readable in a dark cave.
@export var outline_glow: Curve
@export var outline_glow_color := Color(1.0, 0.45, 0.1)
## Size of every part; 1 is its normal size.
@export var swell: Curve
## Extra size that pulses at swell_wobble_hz while swell is above 1.
@export_range(0.0, 1.0, 0.01) var swell_wobble := 0.0
@export_range(0.0, 30.0, 0.1) var swell_wobble_hz := 8.0

@export_group("Effects")
@export var cues: Array[DeathCue] = []
## Effect a flying part leaves behind, every trail_interval_seconds while it is faster
## than trail_min_speed and the beat has not passed trail_until.
@export var trail_effect_key: StringName = &""
@export_range(0.005, 1.0, 0.001) var trail_interval_seconds := 0.05
@export_range(0.0, 2000.0, 1.0) var trail_min_speed := 120.0
@export_range(0.0, 1.0, 0.01) var trail_until := 0.6
## Effect where a part hits terrain faster than splat_min_speed.
@export var splat_effect_key: StringName = &""
@export_range(0.0, 2000.0, 1.0) var splat_min_speed := 140.0
## Shortest time between two splats of one part.
@export_range(0.0, 2.0, 0.01) var splat_cooldown_seconds := 0.15

@export_group("Variants")
## Sequence played instead when the body touched terrain with this perk tag, such as
## "steam". Variants of a variant are ignored.
@export var variant_by_terrain_tag: Dictionary[StringName, DeathSequence] = {}


## Value of a curve at a share of the beat, or at_rest for an empty curve.
static func sample(curve: Curve, time: float, at_rest: float) -> float:
	if curve == null or curve.point_count == 0:
		return at_rest
	return curve.sample_baked(clampf(time, 0.0, 1.0))


func is_featured(part: StringName) -> bool:
	return featured_parts.has(part)


func validate() -> PackedStringArray:
	var errors := _validate_own()
	for tag: StringName in variant_by_terrain_tag:
		var variant := variant_by_terrain_tag[tag]
		if variant == null:
			errors.append("variant_by_terrain_tag[%s] is missing" % tag)
			continue
		for error in variant._validate_own():
			errors.append("variant_by_terrain_tag[%s]: %s" % [tag, error])
	return errors


## Every effect key this sequence and its variants can ask for.
func effect_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	var all: Array[DeathSequence] = [self]
	all.append_array(variant_by_terrain_tag.values())
	for sequence in all:
		if sequence == null:
			continue
		var own: Array[StringName] = [sequence.trail_effect_key, sequence.splat_effect_key]
		for cue in sequence.cues:
			if cue != null:
				own.append(cue.effect_key)
		for key in own:
			if key != &"" and not keys.has(key):
				keys.append(key)
	return keys


func _validate_own() -> PackedStringArray:
	var errors := PackedStringArray()
	if burst_at + detach_stagger > 1.0:
		errors.append("burst_at plus detach_stagger must stay inside the beat")
	for range_name: String in ["radial_speed", "push_speed", "lift_speed", "spin_degrees"]:
		if float(get("%s_max" % range_name)) < float(get("%s_min" % range_name)):
			errors.append("%s_max must be >= %s_min" % [range_name, range_name])
	if gib_scale <= 0.0:
		errors.append("gib_scale must be positive")
	if trail_effect_key != &"" and trail_interval_seconds <= 0.0:
		errors.append("trail_interval_seconds must be positive")
	for index in cues.size():
		if cues[index] == null:
			errors.append("cues[%d] is missing" % index)
			continue
		for error in cues[index].validate():
			errors.append("cues[%d]: %s" % [index, error])
	return errors
