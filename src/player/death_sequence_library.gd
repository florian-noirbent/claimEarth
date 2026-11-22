## The death sequence of every death cause, plus the one played for causes without an entry.
class_name DeathSequenceLibrary
extends Resource


## Sequence by DeathCause value.
@export var sequences: Dictionary[StringName, DeathSequence] = {}
## Played for a cause without an entry, so a new cause never dies without an animation.
@export var default_sequence: DeathSequence
## Seconds the rope takes to fall back once the dead hand lets go of it.
@export_range(0.01, 2.0, 0.01) var rope_release_seconds := 0.35
## Share of the beat from which loose parts bounce less and less; by the end of the beat
## they no longer bounce, so the result panel opens on parts that have come to rest.
@export_range(0.0, 1.0, 0.01) var settle_from := 0.6
## Sideways drag added over the same stretch.
@export_range(0.0, 20.0, 0.1) var settle_drag := 2.5
## Seconds the parts may keep moving after the beat before they are frozen where they are.
@export_range(0.0, 10.0, 0.1) var settle_grace_seconds := 3.0


## The sequence for a death: the cause's entry or the default, replaced by its variant
## for the first terrain tag the body touched that has one.
func sequence_for(cause: StringName, terrain_tags: PackedStringArray = PackedStringArray()) -> DeathSequence:
	var sequence: DeathSequence = sequences.get(cause)
	if sequence == null:
		sequence = default_sequence
	if sequence == null:
		return null
	for tag in terrain_tags:
		var variant: DeathSequence = sequence.variant_by_terrain_tag.get(StringName(tag))
		if variant != null:
			return variant
	return sequence


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if default_sequence == null:
		errors.append("default_sequence is required")
	else:
		for error in default_sequence.validate():
			errors.append("default_sequence: %s" % error)
	for cause: StringName in sequences:
		if cause == &"" or cause == DeathCause.NONE:
			errors.append("sequences has an entry without a death cause")
		var sequence := sequences[cause]
		if sequence == null:
			errors.append("sequences[%s] is missing" % cause)
			continue
		for error in sequence.validate():
			errors.append("sequences[%s]: %s" % [cause, error])
	return errors


## Every effect key any sequence or variant can ask for.
func effect_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	var all: Array[DeathSequence] = []
	if default_sequence != null:
		all.append(default_sequence)
	all.append_array(sequences.values())
	for sequence in all:
		if sequence == null:
			continue
		for key in sequence.effect_keys():
			if not keys.has(key):
				keys.append(key)
	return keys
