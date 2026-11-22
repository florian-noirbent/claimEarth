## An effect that stays on a moving body, such as the fuse spark of a flying bomb: its
## recipe is played again at the attach point for as long as the body exists.
class_name AttachedEffect
extends Resource


enum Aim {
	## The recipe keeps its own directions.
	FIXED,
	## The recipe points from the body's center through the attach point.
	OUTWARD,
	## The recipe points along the body's velocity.
	MOTION,
}


@export var recipe: EffectRecipe
## Seconds between two plays of the recipe.
@export_range(0.005, 5.0, 0.001) var interval_seconds := 0.05
## Attach point in texture px from the sprite's center. It follows the sprite's scale,
## rotation, and mirroring.
@export var attach_offset := Vector2.ZERO
## Direction handed to the recipe's emitters that follow one.
@export var aim := Aim.FIXED
## Scale the recipe is played at.
@export_range(0.05, 8.0, 0.01) var effect_scale := 1.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if recipe == null:
		errors.append("attached effect recipe is missing")
		return errors
	if interval_seconds <= 0.0:
		errors.append("attached effect interval_seconds must be positive")
	errors.append_array(recipe.validate())
	return errors
