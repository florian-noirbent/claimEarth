extends GutTest
## Covers the death sequence resources: the shipped library, the keyed lookup with its
## fallback and terrain variants, and validation.


const LIBRARY_PATH := "res://config/player/death/death_sequences.tres"
const EFFECTS_PATH := "res://config/presentation/gameplay_effects.tres"
const CAUSES: Array[StringName] = [
	DeathCause.COOKED, DeathCause.SUFFOCATION, DeathCause.ACID, DeathCause.POISON,
	DeathCause.BOMB, DeathCause.IMPACT,
]


func test_shipped_library_is_valid_and_gives_every_cause_its_own_sequence() -> void:
	var library := load(LIBRARY_PATH) as DeathSequenceLibrary

	assert_not_null(library)
	assert_eq(library.validate(), PackedStringArray())
	var seen: Array[DeathSequence] = [library.default_sequence]
	for cause in CAUSES:
		var sequence := library.sequence_for(cause)
		assert_not_null(sequence, "%s has a sequence" % cause)
		assert_false(seen.has(sequence), "%s has a sequence of its own" % cause)
		seen.append(sequence)


func test_causes_without_an_entry_play_the_default() -> void:
	var library := load(LIBRARY_PATH) as DeathSequenceLibrary

	# Nothing reports a bounds death any more; it and any future cause fall back.
	assert_false(library.sequences.has(DeathCause.BOUNDS))
	assert_same(library.sequence_for(DeathCause.BOUNDS), library.default_sequence)
	assert_same(library.sequence_for(&"a_cause_added_later"), library.default_sequence)
	assert_same(library.sequence_for(&"a_cause_added_later", PackedStringArray(["steam"])), library.default_sequence)


func test_a_terrain_tag_at_the_body_selects_the_variant() -> void:
	var library := load(LIBRARY_PATH) as DeathSequenceLibrary
	var cooked := library.sequences[DeathCause.COOKED]
	var steam_variant := cooked.variant_by_terrain_tag[&"steam"]

	assert_not_null(steam_variant)
	assert_same(library.sequence_for(DeathCause.COOKED, PackedStringArray(["steam", "gas", "heat"])), steam_variant)
	assert_same(library.sequence_for(DeathCause.COOKED, PackedStringArray(["lava", "liquid", "heat"])), cooked)
	assert_same(library.sequence_for(DeathCause.COOKED), cooked)
	assert_same(library.sequence_for(DeathCause.ACID, PackedStringArray(["steam"])), library.sequences[DeathCause.ACID], "Other causes have no steam variant")


func test_every_requested_effect_part_and_pose_exists() -> void:
	var library := load(LIBRARY_PATH) as DeathSequenceLibrary
	var effects := load(EFFECTS_PATH) as GameplayEffectLibrary
	var rig := (load("res://scenes/player/player_rig.tscn") as PackedScene).instantiate() as PlayerRig
	add_child_autofree(rig)
	var parts: Array[StringName] = []
	for part in rig.part_count():
		parts.append(rig.part_name(part))
	assert_eq(parts.size(), 16)

	assert_gt(library.effect_keys().size(), 0)
	for key in library.effect_keys():
		assert_not_null(effects.death_cue_by_key.get(key), "Effect %s is in the effect library" % key)
	for key: StringName in effects.death_cue_by_key:
		assert_true(library.effect_keys().has(key), "Effect %s is used by a sequence" % key)
	var sequences: Array[DeathSequence] = [library.default_sequence]
	for sequence: DeathSequence in library.sequences.values():
		sequences.append(sequence)
		sequences.append_array(sequence.variant_by_terrain_tag.values())
	for sequence in sequences:
		for part in sequence.featured_parts:
			assert_true(parts.has(part), "Featured part %s is a rig part" % part)
		if sequence.pose != &"":
			assert_true(PlayerAnimationState.ALL.has(sequence.pose), "Pose %s is an animation state" % sequence.pose)
		assert_lte(sequence.burst_at + sequence.detach_stagger, 0.75, "Every sequence leaves time to settle")


func test_validation_reports_broken_sequences() -> void:
	var library := DeathSequenceLibrary.new()
	assert_string_contains(_joined(library.validate()), "default_sequence is required")

	library.default_sequence = DeathSequence.new()
	assert_eq(library.validate(), PackedStringArray(), "An empty sequence is a valid instant burst")

	var broken := DeathSequence.new()
	broken.burst_at = 0.8
	broken.detach_stagger = 0.5
	broken.radial_speed_min = 100.0
	broken.spin_degrees_min = 10.0
	broken.spin_degrees_max = 5.0
	var keyless := DeathCue.new()
	var late := DeathCue.new()
	late.effect_key = &"late"
	late.at = 0.9
	late.plays = 5
	late.interval = 0.1
	broken.cues = [keyless, late, null]
	var variant := DeathSequence.new()
	variant.lift_speed_min = 10.0
	variant.lift_speed_max = -10.0
	broken.variant_by_terrain_tag = {&"steam": variant, &"lava": null}
	library.sequences = {DeathCause.ACID: broken, DeathCause.NONE: DeathSequence.new(), DeathCause.BOMB: null}
	var errors := _joined(library.validate())

	for expected: String in [
		"sequences[acid]: burst_at plus detach_stagger",
		"radial_speed_max must be >= radial_speed_min",
		"spin_degrees_max must be >= spin_degrees_min",
		"cues[0]: cue effect_key is required",
		"cues[1]: cue late ends after the beat",
		"cues[2] is missing",
		"variant_by_terrain_tag[steam]: lift_speed_max",
		"variant_by_terrain_tag[lava] is missing",
		"entry without a death cause",
		"sequences[bomb] is missing",
	]:
		assert_string_contains(errors, expected)


func test_curves_are_sampled_over_the_beat_with_a_rest_value() -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(0.5, 1.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)

	assert_eq(DeathSequence.sample(null, 0.3, 0.25), 0.25)
	assert_eq(DeathSequence.sample(Curve.new(), 0.3, 1.0), 1.0)
	assert_almost_eq(DeathSequence.sample(curve, 0.25, 0.0), 0.5, 0.05)
	assert_almost_eq(DeathSequence.sample(curve, 4.0, 0.0), 1.0, 0.01, "Time is clamped to the beat")


func test_death_context_points_away_from_what_killed() -> void:
	var blast := DeathContext.from_source(Vector2(100.0, 0.0))
	assert_eq(blast.push_direction(Vector2(40.0, 0.0)), Vector2.LEFT)
	assert_eq(blast.push_direction(Vector2(100.0, 0.0)), Vector2.UP, "A blast exactly on the body throws it up")

	var impact := DeathContext.new()
	impact.surface_normal = Vector2(0.0, -2.0)
	assert_eq(impact.push_direction(Vector2.ZERO), Vector2.UP)

	assert_eq(DeathContext.new().push_direction(Vector2.ZERO), Vector2.ZERO, "Other deaths have no direction")


func _joined(errors: PackedStringArray) -> String:
	return "\n".join(errors)
