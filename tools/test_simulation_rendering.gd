## Renderer-enabled regression check for the asynchronous simulation viewport pipeline.
extends SceneTree


const PASS_COUNT := 6
const MAX_WAIT_FRAMES := 4
const FakeLeaderboardServiceScript = preload("res://src/leaderboard/fake_leaderboard_service.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := TerrainRegistry.new()
	if not registry.try_configure(load("res://config/terrain/catalog.tres") as TerrainCatalog):
		_fail("Could not configure the terrain registry.")
		return
	if not await _verify_even_phase_sand_trail(registry):
		return
	if not await _verify_partial_brightness_preserves_stream_mask(registry):
		return
	if not await _verify_live_run_player_light():
		return
	if not await _verify_player_light_source(registry):
		return
	if not await _verify_moving_standard_light_does_not_starve_simulation(registry):
		return
	if not await _verify_stalled_render_request_recovers(registry):
		return
	if not await _verify_standard_light_source(registry):
		return
	var single_world := _world_fixture(registry)
	var single_backend := _backend(single_world, registry)
	single_backend.attach_to(root)
	await process_frame
	if not await _complete_tick(single_backend, 1, 1):
		single_backend.shutdown()
		return
	var first_commit := single_backend.commit_if_ready()
	if not _expect(first_commit.did_commit and first_commit.revision == 1, "The first six completed passes must publish revision 1."):
		single_backend.shutdown()
		return
	var single_final_bytes := _texture_bytes(single_backend.presentation_texture())
	var single_even_bytes := _texture_bytes(single_backend.presentation_even_texture())
	if not _expect(single_final_bytes == single_world.cell_bytes, "The CPU snapshot must exactly match the sixth-pass texture."):
		single_backend.shutdown()
		return
	single_backend.shutdown()
	await process_frame

	var batch_world := _world_fixture(registry)
	var backend := _backend(batch_world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return
	var batch_commit := backend.commit_if_ready()
	if not _expect(batch_commit.did_commit and batch_commit.revision == 1, "A six-pass batch must publish revision 1."):
		backend.shutdown()
		return
	if not _expect(_texture_bytes(backend.presentation_texture()) == single_final_bytes, "Batched and one-pass-per-frame final textures must match exactly."):
		backend.shutdown()
		return
	if not _expect(_texture_bytes(backend.presentation_even_texture()) == single_even_bytes, "Batched and one-pass-per-frame even textures must match exactly."):
		backend.shutdown()
		return
	var first_bank_final := backend.presentation_texture()
	if not await _complete_tick(backend, 2, PASS_COUNT):
		backend.shutdown()
		return
	var second_commit := backend.commit_if_ready()
	if not _expect(second_commit.did_commit and second_commit.revision == 2, "A settled second batch must publish revision 2."):
		backend.shutdown()
		return
	if not _expect(backend.presentation_texture() != first_bank_final, "Consecutive ticks must alternate render-target banks."):
		backend.shutdown()
		return

	var completed_passes := backend.passes_performed()
	var cancelled_progress := backend.advance(4)
	if not _expect(cancelled_progress.passes_scheduled == 4, "The cancellation fixture must schedule a multi-pass batch."):
		backend.shutdown()
		return
	if not _expect(backend.is_render_pass_in_flight(), "A scheduled pass must be in flight before the normal render phase."):
		backend.shutdown()
		return
	backend.queue_change(null)
	await process_frame
	await process_frame
	if not _expect(not backend.is_render_pass_in_flight(), "Cancellation must clear the in-flight render request."):
		backend.shutdown()
		return
	if not _expect(backend.passes_performed() == completed_passes, "A stale post-draw callback must not complete a cancelled pass."):
		backend.shutdown()
		return
	if not _expect(not backend.has_commit_ready(), "A cancelled pass must not publish a commit."):
		backend.shutdown()
		return

	backend.shutdown()
	await process_frame
	for fps in [30, 60, 90, 120, 240]:
		if not await _verify_fixed_rate(registry, fps):
			return
	print("SIMULATION_RENDERING_TEST_PASSED")
	quit()


func _verify_even_phase_sand_trail(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var sand := _terrain_id(registry, "Sand")
	var dimensions := WorldDimensions.new(3, 4)
	var final_world := WorldGrid.new(dimensions, air)
	var even_world := WorldGrid.new(dimensions, air)
	var trail_cell := Vector2i(1, 1)
	var below_cell := Vector2i(1, 2)
	final_world.set_committed_by_offset(below_cell.x, below_cell.y, sand, 255)
	even_world.set_committed_by_offset(trail_cell.x, trail_cell.y, sand, 128)
	final_world.upload_cpu_snapshot_to_texture()
	even_world.upload_cpu_snapshot_to_texture()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var presenter := WorldPresenter.new()
	presenter.position = Vector2(24.0, 24.0)
	var presentation_config := load("res://config/presentation/default_world_presentation.tres") as WorldPresentationConfig
	presenter.presentation_config = presentation_config.duplicate(true)
	presenter.set_force_full_brightness(true)
	viewport.add_child(presenter)
	presenter.configure(final_world, registry)
	presenter.use_simulation_textures(final_world.texture(), even_world.texture())
	await process_frame
	await process_frame
	var sample_position := Vector2i(
		presenter.position
		+ HexMetrics.center_for_offset(trail_cell.x, trail_cell.y, presenter.hex_radius)
	)
	var rendered := viewport.get_texture().get_image().get_pixelv(sample_position)
	viewport.free()
	await process_frame
	return _expect(rendered.a > 0.5, "A final-air cell must render retained even-phase sand as a continuous vertical trail.")


func _verify_partial_brightness_preserves_stream_mask(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var water := _terrain_id(registry, "Water")
	var world := WorldGrid.new(WorldDimensions.new(3, 4), air)
	var stream_cell := Vector2i(1, 1)
	world.set_committed_by_offset(stream_cell.x, stream_cell.y - 1, water, 128)
	world.set_committed_by_offset(stream_cell.x, stream_cell.y, water, 128)
	for row in range(world.dimensions.depth):
		for col in range(world.dimensions.width):
			world.set_committed_light_by_offset(col, row, 95)
	world.upload_cpu_snapshot_to_texture()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var presenter := WorldPresenter.new()
	presenter.position = Vector2(24.0, 24.0)
	var presentation_config := load("res://config/presentation/default_world_presentation.tres") as WorldPresentationConfig
	presenter.presentation_config = presentation_config.duplicate(true)
	presenter.presentation_config.exposed_edge_jitter_strength = 0.0
	viewport.add_child(presenter)
	presenter.configure(world, registry)
	await process_frame
	await process_frame
	var rendered := viewport.get_texture().get_image()
	var center := Vector2i(
		presenter.position
		+ HexMetrics.center_for_offset(stream_cell.x, stream_cell.y, presenter.hex_radius)
	)
	var inside_stream := rendered.get_pixelv(center)
	var outside_stream := rendered.get_pixelv(center + Vector2i(12, 0))
	viewport.free()
	await process_frame
	if not _expect(
		maxf(inside_stream.r, maxf(inside_stream.g, inside_stream.b)) > 0.02,
		"Partial brightness must retain visible liquid inside the stream mask."
	):
		return false
	if not _expect(outside_stream.a > 0.1, "Partial brightness must retain opaque cave darkness outside the stream mask."):
		return false
	return _expect(
		maxf(outside_stream.r, maxf(outside_stream.g, outside_stream.b)) < 0.01,
		"Partial brightness must not leak terrain RGB outside the stream mask."
	)


func _verify_live_run_player_light() -> bool:
	var app := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app.set_menu_preview_enabled(false)
	app.configure_save_path_for_test("user://simulation_rendering_player_light.json")
	app.configure_settings_path_for_test("user://simulation_rendering_player_light_settings.json")
	app.configure_leaderboard_service_for_test(FakeLeaderboardServiceScript.new())
	root.add_child(app)
	await process_frame
	app.ui.menu_start_button.pressed.emit()
	var ready_frames := 0
	while (app.get_run_state() != RunPhase.PLAYING or app.get_player() == null) and ready_frames < 240:
		await process_frame
		ready_frames += 1
	if not _expect(app.get_run_state() == RunPhase.PLAYING and app.get_player() != null, "The live run must reach PLAYING with a real player."):
		app.free()
		return false
	var player := app.get_player()
	var world := app.world_controller.current_world()
	var backend := app.simulation_backend() as RenderTextureSimulationBackend
	var player_cell := Vector2i(world.dimensions.width / 2, mini(40, world.dimensions.depth - 3))
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.global_position = HexMetrics.center_for_offset(
		player_cell.x,
		player_cell.y,
		app.world_presenter.hex_radius
	)
	var initial_ticks: int = backend.ticks_completed()
	var light_frames := 0
	while backend.ticks_completed() < initial_ticks + 2 and light_frames < 120:
		await process_frame
		light_frames += 1
	await process_frame
	var expected_level := player.world_light_source.definition.light_level
	var committed_level := world.get_committed_light_by_offset(player_cell.x, player_cell.y)
	if not _expect(committed_level >= expected_level, "The live player must produce committed light at its current map cell (expected at least %d, got %d)." % [expected_level, committed_level]):
		app.free()
		return false
	app.free()
	await process_frame
	return true


func _verify_player_light_source(registry: TerrainRegistry) -> bool:
	var world := _world_fixture(registry)
	var backend := _backend(world, registry)
	var player_cell := Vector2i(4, 8)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position = HexMetrics.center_for_offset(player_cell.x, player_cell.y, 16.0)
	backend.attach_to(root)
	player.world_light_source.configure(backend, 16.0, &"render_test_player")
	await process_frame
	if not _expect(player.world_light_source.registered_offset() == player_cell, "The real player scene must register its light at the player's map cell."):
		player.free()
		backend.shutdown()
		return false
	if not await _complete_tick(backend, 1, PASS_COUNT):
		player.free()
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var expected_level := player.world_light_source.definition.light_level
	if not _expect(world.get_committed_light_by_offset(player_cell.x, player_cell.y) == expected_level, "The real player scene must produce committed world light at its map cell."):
		player.free()
		backend.shutdown()
		return false
	var brightest_neighbor := 0
	var player_coord := HexCoord.from_offset_odd_q(player_cell.x, player_cell.y)
	for direction in range(6):
		var neighbor := player_coord.neighbor(direction).to_offset_odd_q()
		brightest_neighbor = maxi(brightest_neighbor, world.get_committed_light_by_offset(neighbor.x, neighbor.y))
	if not _expect(brightest_neighbor > 30, "The real player light must visibly propagate beyond the cell hidden under the player."):
		player.free()
		backend.shutdown()
		return false
	player.free()
	backend.shutdown()
	await process_frame
	return true


func _verify_standard_light_source(registry: TerrainRegistry) -> bool:
	var world := _world_fixture(registry)
	var backend := _backend(world, registry)
	var source_offset := Vector2i(4, 8)
	backend.attach_to(root)
	await process_frame
	if not _expect(backend.set_standard_light_source(&"test_chest", source_offset, 90), "A valid standard light source must be accepted."):
		backend.shutdown()
		return false
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	if not _expect(world.get_committed_light_by_offset(source_offset.x, source_offset.y) == 90, "A standard source must inject its configured light into the terrain simulation."):
		backend.shutdown()
		return false
	if not _expect(backend.remove_standard_light_source(&"test_chest"), "The standard source must be removable."):
		backend.shutdown()
		return false
	if not await _complete_tick(backend, 2, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	if not _expect(world.get_committed_light_by_offset(source_offset.x, source_offset.y) < 90, "Sub-threshold standard light must fade after its source is removed."):
		backend.shutdown()
		return false
	if not _expect(backend.set_high_frequency_light_source(&"test_player", source_offset, 190, 18), "A valid high-frequency light source must be accepted."):
		backend.shutdown()
		return false
	if not await _complete_tick(backend, 3, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	if not _expect(world.get_committed_light_by_offset(source_offset.x, source_offset.y) == 190, "A high-frequency source must inject its configured light into the terrain simulation."):
		backend.shutdown()
		return false
	if not _expect(backend.remove_high_frequency_light_source(&"test_player"), "The high-frequency source must be removable."):
		backend.shutdown()
		return false
	backend.shutdown()
	await process_frame
	return true


func _verify_moving_standard_light_does_not_starve_simulation(registry: TerrainRegistry) -> bool:
	var world := _world_fixture(registry)
	var backend := _backend(world, registry)
	var host := Node2D.new()
	var source := WorldLightSource2D.new()
	source.definition = load("res://config/lighting/chest_light.tres") as WorldLightSourceDefinition
	host.add_child(source)
	root.add_child(host)
	host.global_position = HexMetrics.center_for_offset(3, 8, 16.0)
	backend.attach_to(root)
	source.configure(backend, 16.0, &"moving_standard_light")
	await process_frame
	for frame in range(12):
		backend.commit_if_ready()
		backend.advance(PASS_COUNT)
		var next_col := 3 + (frame + 1) % 2
		host.global_position = HexMetrics.center_for_offset(next_col, 8, 16.0)
		source.sync_now()
		await process_frame
	var completed_ticks := backend.ticks_completed()
	var completed_passes := backend.passes_performed()
	host.free()
	backend.shutdown()
	await process_frame
	return _expect(
		completed_ticks > 0 and completed_passes >= PASS_COUNT,
		"Moving standard lights must not cancel every in-flight simulation pass."
	)


func _verify_stalled_render_request_recovers(registry: TerrainRegistry) -> bool:
	var world := _world_fixture(registry)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	backend._render_request_in_flight = true
	backend._render_request_wait_advances = RenderTextureSimulationBackend.MAX_RENDER_REQUEST_WAIT_ADVANCES - 1
	var retry_progress := backend.advance(PASS_COUNT)
	if not _expect(retry_progress.passes_scheduled == PASS_COUNT, "A stalled render request must be invalidated and retried automatically."):
		backend.shutdown()
		return false
	var completed_before := backend.passes_performed()
	var waited := 0
	while backend.passes_performed() == completed_before and waited < MAX_WAIT_FRAMES:
		await process_frame
		waited += 1
	var recovered := backend.passes_performed() == completed_before + PASS_COUNT and backend.ticks_completed() == 1
	backend.shutdown()
	await process_frame
	return _expect(recovered, "The retried render request must complete a simulation tick without restarting the game.")


func _complete_tick(backend: RenderTextureSimulationBackend, expected_revision: int, max_passes: int) -> bool:
	while backend.ticks_completed() < expected_revision:
		var completed_before := backend.passes_performed()
		var progress := backend.advance(max_passes)
		if not _expect(progress.passes_scheduled > 0 and progress.passes_scheduled <= max_passes, "Revision %d did not schedule its next pass batch." % expected_revision):
			return false
		if not _expect(backend.is_render_pass_in_flight(), "Revision %d was not in flight after scheduling." % expected_revision):
			return false
		if not _expect(backend.passes_performed() == completed_before, "A simulation pass completed synchronously before Godot rendered the frame."):
			return false
		var waited := 0
		while backend.passes_performed() == completed_before and waited < MAX_WAIT_FRAMES:
			await process_frame
			waited += 1
		if not _expect(backend.passes_performed() == completed_before + progress.passes_scheduled, "Revision %d did not complete its scheduled batch after the normal render phase." % expected_revision):
			return false
	if not _expect(backend.ticks_completed() == expected_revision, "Six completed passes must finish exactly one tick."):
		return false
	return _expect(backend.has_commit_ready(), "A completed tick must expose a pending commit.")


func _world_fixture(registry: TerrainRegistry) -> WorldGrid:
	var world := WorldGrid.new(WorldDimensions.new(12, 24), _terrain_id(registry, "Air"))
	for col in range(world.dimensions.width):
		world.set_committed_by_offset(col, world.dimensions.depth - 2, _terrain_id(registry, "Stone"))
		world.set_committed_by_offset(col, world.dimensions.depth - 1, _terrain_id(registry, "Stone"))
	world.set_committed_by_offset(5, 3, _terrain_id(registry, "Sand"))
	return world


func _backend(world: WorldGrid, registry: TerrainRegistry) -> RenderTextureSimulationBackend:
	var backend := RenderTextureSimulationBackend.new()
	backend.set_simulation_shader(load("res://src/simulation/render_texture_simulation.gdshader") as Shader)
	backend.initialize(world, registry, 12345)
	return backend


func _texture_bytes(texture: Texture2D) -> PackedByteArray:
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_data()


func _verify_fixed_rate(registry: TerrainRegistry, fps: int) -> bool:
	var world := _world_fixture(registry)
	var backend := _backend(world, registry)
	var clock := FixedSimulationPassClock.new()
	backend.attach_to(root)
	await process_frame
	for _frame in range(fps):
		backend.commit_if_ready()
		clock.add_time(1.0 / float(fps))
		var due := clock.available_passes(PASS_COUNT)
		var completed_before := backend.passes_performed()
		var progress := backend.advance(due)
		clock.consume(progress.passes_scheduled)
		if progress.passes_scheduled > 0:
			var waited := 0
			while backend.passes_performed() == completed_before and waited < MAX_WAIT_FRAMES:
				await process_frame
				waited += 1
			if not _expect(backend.passes_performed() == completed_before + progress.passes_scheduled, "%d FPS did not complete its scheduled pass batch." % fps):
				backend.shutdown()
				return false
		else:
			await process_frame
	backend.commit_if_ready()
	if not _expect(backend.passes_performed() == 60, "%d FPS must complete exactly 60 passes per synthetic second." % fps):
		backend.shutdown()
		return false
	if not _expect(backend.ticks_completed() == 10, "%d FPS must complete exactly 10 ticks per synthetic second." % fps):
		backend.shutdown()
		return false
	backend.shutdown()
	await process_frame
	return true


func _terrain_id(registry: TerrainRegistry, display_name: String) -> int:
	for definition in registry.all_definitions():
		if definition.display_name == display_name:
			return definition.stable_id
	return -1


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
