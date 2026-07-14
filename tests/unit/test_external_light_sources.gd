extends GutTest


func test_standard_light_sources_validate_overlap_move_and_removal() -> void:
	var registry := FixtureLoader.terrain_registry()
	var world := WorldGrid.new(WorldDimensions.new(8, 12), FixtureLoader.terrain_id("Air"))
	var backend := RenderTextureSimulationBackend.new()
	backend.set_simulation_shader(load("res://src/simulation/render_texture_simulation.gdshader") as Shader)
	backend.initialize(world, registry, 123)
	backend.attach_to(self)

	assert_false(backend.set_standard_light_source(StringName(), Vector2i(2, 3), 90))
	assert_false(backend.set_standard_light_source(&"outside", Vector2i(-1, 3), 90))
	assert_false(backend.set_standard_light_source(&"dark", Vector2i(2, 3), 0))
	assert_true(backend.set_standard_light_source(&"first", Vector2i(2, 3), 90))
	assert_true(backend.set_standard_light_source(&"stronger", Vector2i(2, 3), 120))
	assert_eq(backend.standard_light_source_count(), 2)
	assert_eq(backend.standard_light_level_at(Vector2i(2, 3)), 120)

	assert_true(backend.set_standard_light_source(&"stronger", Vector2i(5, 6), 80))
	assert_eq(backend.standard_light_level_at(Vector2i(2, 3)), 90)
	assert_eq(backend.standard_light_level_at(Vector2i(5, 6)), 80)
	assert_true(backend.remove_standard_light_source(&"first"))
	assert_false(backend.remove_standard_light_source(&"missing"))
	assert_eq(backend.standard_light_level_at(Vector2i(2, 3)), 0)

	backend.clear_standard_light_sources()
	assert_eq(backend.standard_light_source_count(), 0)
	assert_eq(backend.standard_light_level_at(Vector2i(5, 6)), 0)
	assert_true(backend.set_high_frequency_light_source(&"player", Vector2i(3, 4), 190, 18))
	assert_true(backend.set_high_frequency_light_source(&"player", Vector2i(4, 5), 190, 18))
	assert_false(backend.set_high_frequency_light_source(&"second", Vector2i(2, 2), 100, 8))
	assert_false(backend.remove_high_frequency_light_source(&"second"))
	assert_true(backend.remove_high_frequency_light_source(&"player"))
	backend.shutdown()
	await wait_process_frames(1)
