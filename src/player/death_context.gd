## Facts about how the player died that the death animation may use. Gameplay fills in
## what it knows and decides nothing about the look; every field may stay at its default.
class_name DeathContext
extends RefCounted


## Body velocity just before the death, in px/s. A lethal impact reports the speed it hit
## with, not the speed the collision left.
var velocity := Vector2.ZERO
## World position the killing force came from, such as a blast center. Only meaningful
## while has_source is set.
var source_position := Vector2.ZERO
var has_source := false
## Unit normal of the surface a lethal impact hit, pointing away from it; zero otherwise.
var surface_normal := Vector2.ZERO
## Perk tags of the terrain the body touched when it died, such as "lava" or "steam".
var terrain_tags := PackedStringArray()


## Context of a death caused from a world position, such as an explosion.
static func from_source(world_position: Vector2) -> DeathContext:
	var context := DeathContext.new()
	context.source_position = world_position
	context.has_source = true
	return context


## Unit direction the killing force pushed a body at body_position: off the surface it
## hit, or away from the source. Zero when the death has neither.
func push_direction(body_position: Vector2) -> Vector2:
	if surface_normal.length_squared() > 0.0001:
		return surface_normal.normalized()
	if has_source:
		var away := body_position - source_position
		return away.normalized() if away.length_squared() > 0.0001 else Vector2.UP
	return Vector2.ZERO
