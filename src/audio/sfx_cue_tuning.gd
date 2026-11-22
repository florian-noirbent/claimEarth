## Mix tuning for one sound of the synthesized set: where it plays, how loud, how much
## it varies between plays, and how it competes for a voice.
class_name SfxCueTuning
extends Resource


## The SfxRecipes sound id this entry tunes.
@export var id: StringName
@export var bus: StringName = &"SFX"
@export_range(-60.0, 6.0, 0.1) var volume_db := -10.0
## Each play shifts its volume by a random amount within plus or minus this many dB.
@export_range(0.0, 6.0, 0.1) var volume_variation_db := 0.0
## Each play shifts its pitch by a random amount within plus or minus this many semitones.
@export_range(0.0, 6.0, 0.05) var pitch_variation_semitones := 0.0
## Plays of this sound closer together than this are dropped.
@export_range(0.0, 10.0, 0.01) var min_interval_seconds := 0.0
## A busy voice pool lets a sound steal a voice of equal or lower priority only.
@export_range(0, 10, 1) var priority := 5


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("sound cue requires an id")
	if bus == &"":
		errors.append("sound cue %s requires a bus" % id)
	if volume_db > 6.0:
		errors.append("sound cue %s volume must not exceed +6 dB" % id)
	if volume_variation_db < 0.0 or pitch_variation_semitones < 0.0:
		errors.append("sound cue %s variation must not be negative" % id)
	if min_interval_seconds < 0.0:
		errors.append("sound cue %s interval must not be negative" % id)
	return errors
