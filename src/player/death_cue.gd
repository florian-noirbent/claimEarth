## One timed request of a death sequence for a world effect, such as a blood burst or a
## puff of smoke. The key names the effect; GameplayFeedback decides what it looks like.
class_name DeathCue
extends Resource


enum Anchor {
	## The body's position at death plus offset.
	BODY,
	## Every body part, wherever it is now.
	EACH_PART,
	## The sequence's featured parts only.
	FEATURED_PARTS,
	## One part picked at random for every play.
	RANDOM_PART,
}

enum Aim {
	## Straight up.
	UP,
	## Along the direction the killing force pushed the body; up when it has none.
	PUSH,
	## Away from the body's center through the anchor.
	OUTWARD,
	## Along the anchored part's velocity; up for a part at rest.
	MOTION,
}


## Key of the effect in GameplayEffectLibrary.death_cue_by_key.
@export var effect_key: StringName = &""
## When the cue first plays, as a share of the death beat.
@export_range(0.0, 1.0, 0.001) var at := 0.0
## How often it plays in total.
@export_range(1, 64, 1) var plays := 1
## Time between two plays, as a share of the death beat.
@export_range(0.0, 1.0, 0.001) var interval := 0.05
@export var anchor := Anchor.BODY
@export var aim := Aim.UP
## Added to a BODY anchor, in world px from the body position.
@export var offset := Vector2.ZERO
## Strength the effect is played at; 1 is its authored look.
@export_range(0.0, 4.0, 0.01) var strength := 1.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if effect_key == &"":
		errors.append("cue effect_key is required")
	if plays > 1 and interval <= 0.0:
		errors.append("cue %s repeats and needs a positive interval" % effect_key)
	if at + interval * (plays - 1) > 1.0:
		errors.append("cue %s ends after the beat" % effect_key)
	return errors
