extends GutTest


class RecordingSimulationBackend:
	extends TerrainSimulationBackend

	var sources: Dictionary = {}
	var high_frequency_sources: Dictionary = {}
	var standard_removals := 0

	func set_standard_light_source(source_id: StringName, offset: Vector2i, light_level: int) -> bool:
		sources[source_id] = {"offset": offset, "light_level": light_level}
		return true

	func remove_standard_light_source(source_id: StringName) -> bool:
		standard_removals += 1
		return sources.erase(source_id)

	func standard_light_source_count() -> int:
		return sources.size()

	func set_high_frequency_light_source(source_id: StringName, offset: Vector2i, light_level: int, update_radius: int) -> bool:
		high_frequency_sources[source_id] = {
			"offset": offset,
			"light_level": light_level,
			"update_radius": update_radius,
		}
		return true

	func remove_high_frequency_light_source(source_id: StringName) -> bool:
		return high_frequency_sources.erase(source_id)


func test_component_registers_tracks_parent_updates_and_unregisters() -> void:
	var backend := RecordingSimulationBackend.new()
	var parent := Node2D.new()
	add_child_autofree(parent)
	var source := WorldLightSource2D.new()
	source.definition = _definition(WorldLightSourceDefinition.UpdateMode.STANDARD, 90, 0)
	parent.add_child(source)
	parent.global_position = HexMetrics.center_for_offset(2, 3, 16.0)

	source.configure(backend, 16.0, &"moving_light")
	assert_true(source.is_registered())
	assert_eq(source.registered_offset(), Vector2i(2, 3))
	assert_eq(backend.sources[&"moving_light"].light_level, 90)

	parent.global_position = HexMetrics.center_for_offset(5, 7, 16.0)
	await wait_process_frames(1)
	assert_eq(source.registered_offset(), Vector2i(5, 7))
	assert_eq(backend.sources[&"moving_light"].offset, Vector2i(5, 7))
	assert_eq(backend.standard_removals, 0)

	source.set_light_level(120)
	assert_eq(backend.sources[&"moving_light"].light_level, 120)
	source.set_emitting(false)
	assert_false(source.is_registered())
	assert_eq(backend.standard_light_source_count(), 0)
	assert_eq(backend.standard_removals, 1)
	source.set_emitting(true)
	assert_true(source.is_registered())

	parent.remove_child(source)
	source.free()
	assert_eq(backend.standard_light_source_count(), 0)


func test_component_generates_an_id_and_deconfigure_is_safe() -> void:
	var backend := RecordingSimulationBackend.new()
	var source := WorldLightSource2D.new()
	source.definition = _definition(WorldLightSourceDefinition.UpdateMode.STANDARD, 90, 0)
	add_child_autofree(source)
	source.global_position = HexMetrics.center_for_offset(1, 1, 8.0)

	source.configure(backend, 8.0)
	assert_true(source.is_registered())
	assert_eq(backend.standard_light_source_count(), 1)
	source.deconfigure()
	assert_false(source.is_registered())
	assert_eq(backend.standard_light_source_count(), 0)


func test_high_frequency_mode_uses_the_local_update_path() -> void:
	var backend := RecordingSimulationBackend.new()
	var source := WorldLightSource2D.new()
	source.definition = _definition(WorldLightSourceDefinition.UpdateMode.HIGH_FREQUENCY, 190, 18)
	add_child_autofree(source)
	source.global_position = HexMetrics.center_for_offset(3, 4, 16.0)

	source.configure(backend, 16.0, &"player")
	assert_true(source.is_registered())
	assert_eq(backend.sources.size(), 0)
	assert_eq(backend.high_frequency_sources[&"player"].offset, Vector2i(3, 4))
	assert_eq(backend.high_frequency_sources[&"player"].light_level, 190)
	assert_eq(backend.high_frequency_sources[&"player"].update_radius, 18)
	source.set_emitting(false)
	assert_eq(backend.high_frequency_sources.size(), 0)


func test_definition_validates_high_frequency_radius() -> void:
	var definition := _definition(WorldLightSourceDefinition.UpdateMode.HIGH_FREQUENCY, 190, 0)
	assert_true("\n".join(definition.validate()).contains("update radius"))
	definition.update_radius = 18
	assert_true(definition.validate().is_empty())


func _definition(mode: int, light_level: int, update_radius: int) -> WorldLightSourceDefinition:
	var result := WorldLightSourceDefinition.new()
	result.update_mode = mode
	result.light_level = light_level
	result.update_radius = update_radius
	return result
