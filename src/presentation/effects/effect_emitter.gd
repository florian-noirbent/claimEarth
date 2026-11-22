## One layer of a transient world effect: how many particles it spawns and how each one
## moves, grows, and changes color over its life. Lengths and speeds are world px and are
## multiplied by the scale an effect is played at, so one recipe serves every blast radius.
class_name EffectEmitter
extends Resource


enum Shape {
	## Filled circle with a hard edge.
	DISC,
	## Soft radial glow.
	GLOW,
	## Circle outline, or an arc of it when arc_degrees is below 360.
	RING,
	## Line trailing behind the particle along its velocity.
	STREAK,
	## Spinning rectangle.
	CHUNK,
	## Spinning triangle.
	SHARD,
	## Spinning five-pointed star.
	STAR,
}

enum Blend {
	## Covers what is behind it; reads on bright and dark backgrounds.
	NORMAL,
	## Adds light; reads as emissive on dark backgrounds.
	ADD,
}

enum Motion {
	## Flies along its velocity under gravity and drag.
	BALLISTIC,
	## Circles its spawn point on a flattened orbit.
	ORBIT,
}


@export var shape := Shape.DISC
@export var blend := Blend.NORMAL
@export var motion := Motion.BALLISTIC

@export_group("Emission")
@export_range(0, 128, 1) var count := 1
## Multiplies count by the played intensity; one particle always remains.
@export var count_scales_with_intensity := false
@export_range(0.0, 10.0, 0.01) var delay_min := 0.0
@export_range(0.0, 10.0, 0.01) var delay_max := 0.0
## Extra delay added per particle index, for evenly spaced pulses.
@export_range(0.0, 10.0, 0.01) var delay_step := 0.0
@export_range(0.01, 30.0, 0.01) var lifetime_min := 0.3
@export_range(0.01, 30.0, 0.01) var lifetime_max := 0.3
## Multiplies delays and lifetimes by the played duration instead of using seconds.
@export var time_scales_with_duration := false
## Keeps the particle relative to the followed node instead of the world.
@export var anchored := false

@export_group("Placement")
@export var spawn_offset := Vector2.ZERO
@export_range(0.0, 512.0, 0.01) var spawn_radius := 0.0
## Rotates spawn_offset and direction_degrees by the played direction.
@export var relative_to_direction := false

@export_group("Motion")
## 0 points right and -90 points up.
@export_range(-360.0, 360.0, 0.1) var direction_degrees := -90.0
@export_range(0.0, 360.0, 0.1) var spread_degrees := 360.0
@export_range(0.0, 4000.0, 0.01) var speed_min := 0.0
@export_range(0.0, 4000.0, 0.01) var speed_max := 0.0
## Multiplies speed by the played intensity.
@export var speed_scales_with_intensity := false
## World px/s² downward; not scaled.
@export_range(-4000.0, 4000.0, 1.0) var gravity := 0.0
@export_range(0.0, 30.0, 0.01) var drag := 0.0
@export_range(-1440.0, 1440.0, 1.0) var spin_degrees_min := 0.0
@export_range(-1440.0, 1440.0, 1.0) var spin_degrees_max := 0.0
@export var random_rotation := false
@export_range(0.0, 512.0, 0.01) var orbit_radius := 0.0
@export_range(-1440.0, 1440.0, 1.0) var orbit_degrees_per_second := 0.0
@export_range(0.05, 1.0, 0.01) var orbit_flatten := 0.4

@export_group("Look")
## Radius (disc, glow, ring, star) or half extent (chunk, shard); minimum length of a streak.
@export_range(0.0, 2048.0, 0.01) var size_start := 4.0
@export_range(0.0, 2048.0, 0.01) var size_end := 4.0
## Below 1 the size changes fast first, above 1 it changes late.
@export_range(0.05, 8.0, 0.01) var size_ease := 1.0
## Random share of the size removed per particle.
@export_range(0.0, 1.0, 0.01) var size_jitter := 0.0
## Line width of a ring or streak.
@export_range(0.0, 512.0, 0.01) var thickness_start := 2.0
@export_range(0.0, 512.0, 0.01) var thickness_end := 2.0
## Width to height ratio of a chunk.
@export_range(0.1, 10.0, 0.01) var aspect := 1.0
## Seconds of travel a streak stretches over.
@export_range(0.0, 1.0, 0.001) var streak_seconds := 0.04
@export_range(1.0, 360.0, 1.0) var arc_degrees := 360.0
## Color over the particle's life, including its fade.
@export var colors: Gradient
## How strongly the played tint multiplies the gradient color.
@export_range(0.0, 1.0, 0.01) var tint_amount := 0.0
## When set, each particle picks one of these as its tint instead of the played tint.
@export var tint_palette := PackedColorArray()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if count <= 0:
		errors.append("emitter count must be positive")
	if colors == null:
		errors.append("emitter colors gradient is required")
	if lifetime_max < lifetime_min:
		errors.append("emitter lifetime_max must be >= lifetime_min")
	if delay_max < delay_min:
		errors.append("emitter delay_max must be >= delay_min")
	if speed_max < speed_min:
		errors.append("emitter speed_max must be >= speed_min")
	if spin_degrees_max < spin_degrees_min:
		errors.append("emitter spin_degrees_max must be >= spin_degrees_min")
	if size_start <= 0.0 and size_end <= 0.0:
		errors.append("emitter needs a positive size")
	return errors
