extends GutTest


const LIBRARY_PATH := "res://config/presentation/gameplay_effects.tres"
const STEP := 1.0 / 60.0


func test_effect_library_is_complete_and_valid() -> void:
	var library := load(LIBRARY_PATH) as GameplayEffectLibrary

	assert_not_null(library)
	assert_eq(library.validate(), PackedStringArray())


func test_library_validation_reports_missing_recipes_and_broken_emitters() -> void:
	var library := GameplayEffectLibrary.new()
	var broken := EffectRecipe.new()
	broken.emitters = [EffectEmitter.new()]
	library.explosion = broken

	var errors := library.validate()

	assert_true(errors.has("jump_dust is missing"))
	assert_true(errors.has("explosion: emitter[0]: emitter colors gradient is required"))
	assert_true(errors.has("flag_marker_texture is required"))


func test_playing_a_recipe_spawns_particles_without_adding_nodes() -> void:
	var effects := _effects()
	var nodes_before := effects.get_child_count()

	effects.play(_library().explosion, Vector2(40.0, 80.0), 80.0, Color.ORANGE)

	assert_gt(effects.live_particle_count(), 20)
	assert_eq(effects.get_child_count(), nodes_before, "Particles live in the two shared layers")
	assert_eq(nodes_before, 2)


func test_effects_end_on_their_own() -> void:
	var effects := _effects()
	effects.play(_library().explosion_large, Vector2.ZERO, 160.0)
	effects.play(_library().explosion, Vector2.ZERO, 160.0)

	for _frame in 60 * 4:
		effects.advance(STEP)

	assert_eq(effects.live_particle_count(), 0)
	for layer: EffectBatch in effects.get_children():
		assert_false(layer.is_processing(), "An empty layer stops processing")


func test_lifetime_does_not_depend_on_the_frame_rate() -> void:
	var slow := _effects()
	var fast := _effects()
	slow.play(_library().jump_dust, Vector2.ZERO)
	fast.play(_library().jump_dust, Vector2.ZERO)

	for _frame in 6:
		slow.advance(0.1)
	for _frame in 60:
		fast.advance(0.01)

	assert_eq(slow.live_particle_count(), 0)
	assert_eq(fast.live_particle_count(), 0)


func test_a_chain_of_explosions_stays_inside_the_budget_and_thins_out() -> void:
	var effects := _effects()
	effects.play(_library().explosion, Vector2.ZERO, 160.0)
	var first_cost := effects.live_particle_count()
	var nodes_before := effects.get_child_count()
	var last_cost := first_cost

	for _index in 40:
		var before := effects.live_particle_count()
		effects.play(_library().explosion_large, Vector2.ZERO, 160.0)
		effects.play(_library().explosion, Vector2.ZERO, 160.0)
		last_cost = effects.live_particle_count() - before
		effects.advance(STEP)

	assert_lte(effects.live_particle_count(), effects.particle_capacity())
	assert_eq(effects.get_child_count(), nodes_before)
	assert_lt(last_cost, first_cost, "A full layer gives each new effect fewer particles")
	for layer: EffectBatch in effects.get_children():
		assert_lte(layer.used_count(), layer.capacity())


func test_budget_scale_falls_from_full_to_the_floor() -> void:
	var effects := _effects()
	var layer := effects.get_child(0) as EffectBatch
	var emitter := _library().explosion.emitters[0]

	assert_eq(effects.budget_scale(layer), 1.0)
	layer.emit(emitter, layer.capacity(), Vector2.ZERO, 1.0, Color.WHITE, 0.0, 1.0, 1.0)

	assert_almost_eq(effects.budget_scale(layer), effects.pressure_floor, 0.0001)


func test_a_full_layer_replaces_its_oldest_particles() -> void:
	var layer := EffectBatch.new(8, false)
	add_child_autofree(layer)
	var emitter := _library().explosion.emitters[0]

	assert_eq(layer.emit(emitter, 20, Vector2.ZERO, 1.0, Color.WHITE, 0.0, 1.0, 1.0), 20)

	assert_eq(layer.used_count(), 8)


func test_same_seed_spawns_the_same_particles() -> void:
	var first := _effects()
	var second := _effects()
	first.play(_library().explosion, Vector2.ZERO, 80.0)
	second.play(_library().explosion, Vector2.ZERO, 80.0)
	for _frame in 10:
		first.advance(STEP)
		second.advance(STEP)

	var first_layer := first.get_child(0) as EffectBatch
	var second_layer := second.get_child(0) as EffectBatch
	assert_eq(first_layer._position, second_layer._position)


func test_duration_stretches_timed_emitters() -> void:
	var effects := _effects()
	effects.play(_library().knockout_stars, Vector2.ZERO, 1.0, Color.WHITE, Vector2.RIGHT, 1.0, 2.0)

	for _frame in 90:
		effects.advance(STEP)
	assert_gt(effects.live_particle_count(), 0, "Stars last as long as the knockout")
	for _frame in 40:
		effects.advance(STEP)
	assert_eq(effects.live_particle_count(), 0)


func test_freeing_the_node_mid_effect_is_safe() -> void:
	var effects := WorldEffects.new()
	effects.library = _library()
	add_child(effects)
	effects.play(_library().victory, Vector2.ZERO)
	effects.advance(STEP)

	effects.free()

	assert_false(is_instance_valid(effects))


func _library() -> GameplayEffectLibrary:
	return load(LIBRARY_PATH) as GameplayEffectLibrary


func _effects() -> WorldEffects:
	var effects := WorldEffects.new()
	effects.library = _library()
	add_child_autofree(effects)
	effects.set_seed(11)
	return effects
