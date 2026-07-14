## Renderer-enabled regression check for the asynchronous simulation viewport pipeline.
extends SceneTree


const PASS_COUNT := 6
const MAX_WAIT_FRAMES := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := TerrainRegistry.new()
	if not registry.try_configure(load("res://config/terrain/catalog.tres") as TerrainCatalog):
		_fail("Could not configure the terrain registry.")
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
