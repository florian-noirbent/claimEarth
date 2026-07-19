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
	if not await _verify_fixed_seed_initial_settlement(registry):
		return
	if not await _verify_bottom_edge_is_solid(registry):
		return
	if not await _verify_even_phase_sand_trail(registry):
		return
	if not await _verify_partial_brightness_preserves_stream_mask(registry):
		return
	if not await _verify_partial_fill_uses_liquid_or_gas_above(registry):
		return
	if not await _verify_partial_sand_air_edge_is_polished(registry):
		return
	if not await _verify_partial_liquid_air_edge_is_polished(registry):
		return
	if not await _verify_air_pressure_equalizes_across_a_hex_edge(registry):
		return
	if not await _verify_non_burning_secondary_air_can_drain(registry):
		return
	if not await _verify_static_sulfur_burn_persists(registry):
		return
	if not await _verify_sulfur_converts_water_one_to_one_before_depleting(registry):
		return
	if not await _verify_sand_displaces_water_without_destroying_it(registry):
		return
	if not await _verify_trapped_secondary_creates_pairwise_pressure(registry):
		return
	if not await _verify_overpressure_propagates_to_nearby_full_cells(registry):
		return
	if not await _verify_saturated_pressure_stays_buffered(registry):
		return
	if not await _verify_third_material_waits_for_a_free_component_slot(registry):
		return
	if not await _verify_single_hex_fluid_quantity_conservation(registry):
		return
	if not await _verify_secondary_material_is_not_rendered(registry):
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


func _verify_bottom_edge_is_solid(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var lava := _terrain_id(registry, "Lava")
	var world := WorldGrid.new(WorldDimensions.new(7, 5), air)
	var bottom_row := world.dimensions.depth - 1
	var source_col := 4
	world.set_committed_by_offset(source_col, bottom_row, lava, 255)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var total_lava_fill := 0
	var lava_above_floor := false
	for row in range(world.dimensions.depth):
		for col in range(world.dimensions.width):
			if world.get_committed_by_offset(col, row) != lava:
				continue
			var fill: int = world.get_committed_quantity_by_offset(col, row)
			total_lava_fill += fill
			lava_above_floor = lava_above_floor || (row < bottom_row && fill > 0)
	var source_fill: int = world.get_committed_quantity_by_offset(source_col, bottom_row)
	var neighboring_fill: int = (
		world.get_committed_quantity_by_offset(source_col - 1, bottom_row)
		+ world.get_committed_quantity_by_offset(source_col + 1, bottom_row)
	)
	backend.shutdown()
	await process_frame
	if not _expect(total_lava_fill == 255, "The solid bottom edge must conserve all lava fill."):
		return false
	if not _expect(not lava_above_floor, "Lava resting on the bottom edge must not be displaced upward."):
		return false
	return _expect(
		source_fill < 255 && neighboring_fill > 0,
		"Bottom-edge lava must spread along in-bounds floor cells instead of leaking below the map."
	)


func _verify_even_phase_sand_trail(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var sand := _terrain_id(registry, "Sand")
	var dimensions := WorldDimensions.new(3, 4)
	var final_world := WorldGrid.new(dimensions, air)
	var even_world := WorldGrid.new(dimensions, air)
	var trail_cell := Vector2i(1, 1)
	var below_cell := Vector2i(1, 2)
	final_world.set_committed_by_offset(below_cell.x, below_cell.y, sand, 127)
	even_world.set_committed_by_offset(trail_cell.x, trail_cell.y, sand, 64)
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
	var stone := _terrain_id(registry, "Stone")
	var water := _terrain_id(registry, "Water")
	var world := WorldGrid.new(WorldDimensions.new(3, 4), air)
	var stream_cell := Vector2i(1, 1)
	world.set_committed_by_offset(stream_cell.x, stream_cell.y - 1, stone, 127)
	world.set_committed_by_offset(stream_cell.x, stream_cell.y, water, 64)
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


func _verify_partial_fill_uses_liquid_or_gas_above(registry: TerrainRegistry) -> bool:
	var sand := _terrain_id(registry, "Sand")
	var water := _terrain_id(registry, "Water")
	var sulfur_dioxide := _terrain_id(registry, "Sulfur Dioxide")
	var stone := _terrain_id(registry, "Stone")
	var liquid_samples := await _render_partial_fill_samples(registry, sand, water)
	var liquid_overlay := liquid_samples.center as Color
	if not _expect(
		liquid_overlay.a > 0.2 and liquid_overlay.b > liquid_overlay.r,
		"The empty portion of partial Sand must render Water from the cell above."
	):
		return false
	var liquid_surface := liquid_samples.surface as Color
	var liquid_top := liquid_samples.top as Color
	if not _expect(
		_brightness(liquid_surface) > _brightness(liquid_top) + 0.05,
		"The overlaid Water surface line must follow the partial fill boundary instead of the top hex edge."
	):
		return false
	var liquid_edge := liquid_samples.edge as Color
	if not _expect(
		liquid_edge.b > liquid_edge.r,
		"The empty portion must not receive the hidden partial terrain's edge outline."
	):
		return false
	var gas_samples := await _render_partial_fill_samples(registry, water, sulfur_dioxide)
	var gas_overlay := gas_samples.center as Color
	if not _expect(
		gas_overlay.a > 0.1 and gas_overlay.g > gas_overlay.b,
		"The empty portion of partial Water must render gas from the cell above."
	):
		return false
	var solid_samples := await _render_partial_fill_samples(registry, sand, stone)
	var solid_above := solid_samples.center as Color
	return _expect(
		solid_above.a < 0.01,
		"Solid terrain above a partial fill must not fill its empty portion."
	)


func _verify_partial_sand_air_edge_is_polished(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var sand := _terrain_id(registry, "Sand")
	var samples := await _render_partial_fill_samples(registry, sand, air, 123)
	var center := samples.center as Color
	var upper_edge := samples.upper_edge as Color
	return _expect(
		_brightness(upper_edge) < _brightness(center) - 0.15,
		"A partial Sand-Air boundary must retain Sand's polished edge outline."
	)


func _verify_partial_liquid_air_edge_is_polished(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var water := _terrain_id(registry, "Water")
	var samples := await _render_partial_fill_samples(registry, water, air, 123, 0.0)
	var center := samples.center as Color
	var upper_edge := samples.upper_edge as Color
	return _expect(
		_brightness(upper_edge) < _brightness(center) - 0.03
		and upper_edge.a > center.a + 0.2,
		"A partial Water-Air boundary must retain Water's polished edge outline (center %s, edge %s)." % [center, upper_edge]
	)


func _render_partial_fill_samples(
	registry: TerrainRegistry,
	partial_id: int,
	above_id: int,
	partial_quantity: int = 32,
	surface_glow_strength: float = 1.0
) -> Dictionary:
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	var world := WorldGrid.new(WorldDimensions.new(3, 4), air)
	var partial_cell := Vector2i(1, 1)
	world.set_committed_by_offset(partial_cell.x, partial_cell.y - 1, above_id, 127)
	world.set_committed_by_offset(partial_cell.x, partial_cell.y, partial_id, partial_quantity)
	world.set_committed_by_offset(partial_cell.x, partial_cell.y + 1, stone, 127)
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
	presenter.presentation_config.fluid_caustic_strength = 0.0
	presenter.presentation_config.fluid_shimmer_strength = 0.0
	presenter.presentation_config.fluid_hot_glow_strength = 0.0
	presenter.presentation_config.fluid_surface_glow_strength = surface_glow_strength
	presenter.set_force_full_brightness(true)
	viewport.add_child(presenter)
	presenter.configure(world, registry)
	await process_frame
	await process_frame
	var center := Vector2i(
		presenter.position
		+ HexMetrics.center_for_offset(partial_cell.x, partial_cell.y, presenter.hex_radius)
	)
	var image := viewport.get_texture().get_image()
	var rendered := {
		"center": image.get_pixelv(center),
		"surface": image.get_pixelv(center + Vector2i(0, 5)),
		"top": image.get_pixelv(center + Vector2i(0, -10)),
		"edge": image.get_pixelv(center + Vector2i(15, 0)),
		"upper_edge": image.get_pixelv(center + Vector2i(0, -12)),
	}
	viewport.free()
	await process_frame
	return rendered


func _brightness(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))


func _verify_air_pressure_equalizes_across_a_hex_edge(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	# SubViewport render targets have a two-pixel minimum width. Keep the second
	# column inert so the first column remains the isolated vertical Air pair.
	var world := WorldGrid.new(WorldDimensions.new(2, 2), stone)
	world.set_committed_by_offset(0, 0, air, 128)
	world.set_committed_by_offset(0, 1, air, 64)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var top_quantity := world.get_committed_quantity_by_offset(0, 0)
	var bottom_quantity := world.get_committed_quantity_by_offset(0, 1)
	backend.shutdown()
	await process_frame
	return _expect(
		top_quantity == 96 and bottom_quantity == 96,
		"Air pressure must equalize across a matching adjacent Air pair while conserving quantity (top %d, bottom %d)." % [top_quantity, bottom_quantity]
	)


func _verify_non_burning_secondary_air_can_drain(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	var water := _terrain_id(registry, "Water")
	var world := WorldGrid.new(WorldDimensions.new(2, 2), stone)
	world.set_committed_components_by_offset(0, 0, water, 127, air, 1)
	world.set_committed_by_offset(0, 1, air, 0)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	var completed_before := backend.passes_performed()
	var progress := backend.advance(1)
	if not _expect(progress.passes_scheduled == 1, "The secondary-Air fixture must schedule exactly one vertical pass."):
		backend.shutdown()
		return false
	var waited := 0
	while backend.passes_performed() == completed_before and waited < MAX_WAIT_FRAMES:
		await process_frame
		waited += 1
	if not _expect(backend.passes_performed() == completed_before + 1, "The secondary-Air fixture did not complete its vertical pass."):
		backend.shutdown()
		return false
	var bytes := _texture_bytes(backend._active_texture)
	var source_offset := world.dimensions.offset_to_index(0, 0) * WorldGrid.BYTES_PER_CELL
	var target_offset := world.dimensions.offset_to_index(0, 1) * WorldGrid.BYTES_PER_CELL
	var source_secondary_quantity := int(bytes[source_offset + WorldGrid.CELL_SECONDARY_QUANTITY])
	var target_id := int(bytes[target_offset + WorldGrid.CELL_HEX_IDS]) & WorldGrid.PRIMARY_HEX_ID_MASK
	var target_quantity := int(bytes[target_offset + WorldGrid.CELL_QUANTITY])
	backend.shutdown()
	await process_frame
	return _expect(
		source_secondary_quantity == 0 && target_id == air && target_quantity == 1,
		"A non-burning Water cell must release its final secondary Air unit (source secondary %d, target %d:%d)." % [source_secondary_quantity, target_id, target_quantity]
	)


func _verify_static_sulfur_burn_persists(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	var lava := _terrain_id(registry, "Lava")
	var sulfur := _terrain_id(registry, "Sulfur")
	var sulfur_dioxide := _terrain_id(registry, "Sulfur Dioxide")
	var world := WorldGrid.new(WorldDimensions.new(4, 4), air)
	for col in range(world.dimensions.width):
		world.set_committed_by_offset(col, world.dimensions.depth - 1, stone)
	var sulfur_cell := Vector2i(1, 1)
	var lava_cell := Vector2i(1, 2)
	world.set_committed_by_offset(sulfur_cell.x, sulfur_cell.y, sulfur, 127)
	world.set_committed_by_offset(lava_cell.x, lava_cell.y, lava, 127)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	if not _expect(
		world.get_committed_by_offset(sulfur_cell.x, sulfur_cell.y) == sulfur
		and world.get_committed_secondary_by_offset(sulfur_cell.x, sulfur_cell.y) == sulfur_dioxide
		and world.get_committed_secondary_quantity_by_offset(sulfur_cell.x, sulfur_cell.y) >= 1,
		"Lava contact must ignite static Sulfur with a retained Sulfur Dioxide product."
	):
		backend.shutdown()
		return false
	var quantity_after_ignition := world.get_committed_quantity_by_offset(sulfur_cell.x, sulfur_cell.y)
	var lava_change := world.set_committed_by_offset(lava_cell.x, lava_cell.y, air, WorldGrid.AIR_QUANTITY)
	backend.queue_change(lava_change)
	if not await _complete_tick(backend, 2, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var quantity_after_first_burn := world.get_committed_quantity_by_offset(sulfur_cell.x, sulfur_cell.y)
	if not await _complete_tick(backend, 3, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var quantity_after_second_burn := world.get_committed_quantity_by_offset(sulfur_cell.x, sulfur_cell.y)
	var marker_retained := (
		world.get_committed_by_offset(sulfur_cell.x, sulfur_cell.y) == sulfur
		and world.get_committed_secondary_by_offset(sulfur_cell.x, sulfur_cell.y) == sulfur_dioxide
		and world.get_committed_secondary_quantity_by_offset(sulfur_cell.x, sulfur_cell.y) >= 1
	)
	backend.shutdown()
	await process_frame
	return _expect(
		quantity_after_first_burn < quantity_after_ignition
		and quantity_after_second_burn < quantity_after_first_burn
		and marker_retained,
		"Static Sulfur must keep burning after Lava leaves (quantities %d -> %d -> %d, marker retained %s)." % [quantity_after_ignition, quantity_after_first_burn, quantity_after_second_burn, marker_retained]
	)


func _verify_sulfur_converts_water_one_to_one_before_depleting(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	var sulfur := _terrain_id(registry, "Sulfur")
	var water := _terrain_id(registry, "Water")
	var acid := _terrain_id(registry, "Sulfuric Acid")
	var world := WorldGrid.new(WorldDimensions.new(4, 4), air)
	for col in range(world.dimensions.width):
		world.set_committed_by_offset(col, world.dimensions.depth - 1, stone)
	var sulfur_cell := Vector2i(1, 1)
	var water_cell := Vector2i(1, 2)
	world.set_committed_by_offset(sulfur_cell.x, sulfur_cell.y, sulfur, 127)
	world.set_committed_by_offset(water_cell.x, water_cell.y, water, 127)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var sulfur_quantity := world.get_committed_quantity_by_offset(sulfur_cell.x, sulfur_cell.y)
	var acid_quantity := world.get_committed_quantity_by_offset(water_cell.x, water_cell.y)
	backend.shutdown()
	await process_frame
	return _expect(
		world.get_committed_by_offset(sulfur_cell.x, sulfur_cell.y) == sulfur
		and sulfur_quantity < 127
		and world.get_committed_by_offset(water_cell.x, water_cell.y) == acid
		and acid_quantity == (127 - sulfur_quantity) * 10,
		"Sulfur must convert Water to equal-quantity Acid while consuming one tenth of the Water quantity (sulfur %d, acid %d)." % [sulfur_quantity, acid_quantity]
	)


func _verify_single_hex_fluid_quantity_conservation(registry: TerrainRegistry) -> bool:
	# Two isolated edge-to-floor chambers exercise vertical falls, diagonal spread,
	# side-up overflow, full-cell capacity, and both horizontal map boundaries. Each
	# fluid begins as exactly one full hex, so any quantity increase is unambiguous.
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	var water := _terrain_id(registry, "Water")
	var lava := _terrain_id(registry, "Lava")
	var world := WorldGrid.new(WorldDimensions.new(16, 16), stone)
	for row in range(1, 15):
		for col in range(0, 7):
			world.set_committed_by_offset(col, row, air)
		for col in range(9, 16):
			world.set_committed_by_offset(col, row, air)
	world.set_committed_by_offset(0, 1, water, 127)
	world.set_committed_by_offset(15, 1, lava, 127)

	var expected_water := _terrain_quantity_total(world, water)
	var expected_lava := _terrain_quantity_total(world, lava)
	var expected_air := _terrain_quantity_total(world, air)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	for tick in range(1, 25):
		if not await _complete_tick(backend, tick, PASS_COUNT):
			backend.shutdown()
			return false
		backend.commit_if_ready()
		if not _expect(
			_terrain_quantity_total(world, water) == expected_water,
			"Water quantity changed after tick %d (expected %d, got %d)." % [tick, expected_water, _terrain_quantity_total(world, water)]
		):
			backend.shutdown()
			return false
		if not _expect(
			_terrain_quantity_total(world, lava) == expected_lava,
			"Lava quantity changed after tick %d (expected %d, got %d)." % [tick, expected_lava, _terrain_quantity_total(world, lava)]
		):
			backend.shutdown()
			return false
		if not _expect(
			_terrain_quantity_total(world, air) == expected_air,
			"Air quantity changed after tick %d (expected %d, got %d)." % [tick, expected_air, _terrain_quantity_total(world, air)]
		):
			backend.shutdown()
			return false
		if not _expect(_terrain_quantities_respect_storage(world, water), "Water exceeded packed storage after tick %d." % tick):
			backend.shutdown()
			return false
		if not _expect(_terrain_quantities_respect_storage(world, lava), "Lava exceeded packed storage after tick %d." % tick):
			backend.shutdown()
			return false
	if not _expect(_occupied_terrain_cells(world, water) > 1, "A single Water hex must spread into multiple cells without creating quantity. Cells: %s" % [_terrain_cells(world, water)]):
		backend.shutdown()
		return false
	if not _expect(_occupied_terrain_cells(world, lava) > 1, "A single Lava hex must spread into multiple cells without creating quantity."):
		backend.shutdown()
		return false
	backend.shutdown()
	await process_frame
	return true


func _verify_sand_displaces_water_without_destroying_it(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var stone := _terrain_id(registry, "Stone")
	var sand := _terrain_id(registry, "Sand")
	var water := _terrain_id(registry, "Water")
	var world := WorldGrid.new(WorldDimensions.new(4, 5), stone)
	world.set_committed_by_offset(1, 0, air)
	world.set_committed_by_offset(1, 1, sand, 127)
	world.set_committed_by_offset(1, 2, water, 127)
	world.set_committed_by_offset(0, 2, air)
	world.set_committed_by_offset(2, 2, air)
	var expected_sand := _terrain_quantity_total(world, sand)
	var expected_water := _terrain_quantity_total(world, water)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var conserved := (
		_terrain_quantity_total(world, sand) == expected_sand
		and _terrain_quantity_total(world, water) == expected_water
	)
	var sand_moved_below_source := false
	for index in range(world.dimensions.cell_count()):
		if (
			(world.get_committed_by_index(index) == sand or world.get_committed_secondary_by_index(index) == sand)
			and world.dimensions.index_to_offset(index).y >= 2
		):
			sand_moved_below_source = true
			break
	backend.shutdown()
	await process_frame
	return _expect(conserved and sand_moved_below_source, "Sand must displace Water conservatively instead of deleting it.")


func _verify_trapped_secondary_creates_pairwise_pressure(registry: TerrainRegistry) -> bool:
	var stone := _terrain_id(registry, "Stone")
	var water := _terrain_id(registry, "Water")
	var world := WorldGrid.new(WorldDimensions.new(2, 2), stone)
	world.set_committed_components_by_offset(0, 0, stone, 127, water, 64)
	world.set_committed_by_offset(0, 1, water, 127)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var buffered := world.get_committed_secondary_quantity_by_offset(0, 0)
	var pressured := world.get_committed_quantity_by_offset(0, 1)
	var total := _terrain_quantity_total(world, water)
	backend.shutdown()
	await process_frame
	return _expect(
		buffered == 32 and pressured == 159 and total == 191,
		"Trapped secondary Water must split its pressure difference with a full Water neighbor (buffer %d, neighbor %d, total %d)." % [buffered, pressured, total]
	)


func _verify_saturated_pressure_stays_buffered(registry: TerrainRegistry) -> bool:
	var stone := _terrain_id(registry, "Stone")
	var water := _terrain_id(registry, "Water")
	var world := WorldGrid.new(WorldDimensions.new(2, 2), stone)
	world.set_committed_components_by_offset(0, 0, stone, 127, water, 64)
	world.set_committed_by_offset(0, 1, water, 255)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var buffered := world.get_committed_secondary_quantity_by_offset(0, 0)
	var pressured := world.get_committed_quantity_by_offset(0, 1)
	backend.shutdown()
	await process_frame
	return _expect(
		buffered == 64 and pressured == 255,
		"A saturated pressure neighbor must leave excess secondary quantity buffered (buffer %d, neighbor %d)." % [buffered, pressured]
	)


func _verify_overpressure_propagates_to_nearby_full_cells(registry: TerrainRegistry) -> bool:
	var stone := _terrain_id(registry, "Stone")
	var water := _terrain_id(registry, "Water")
	var world := WorldGrid.new(WorldDimensions.new(2, 3), stone)
	world.set_committed_components_by_offset(0, 0, stone, 127, water, 64)
	world.set_committed_by_offset(0, 1, water, 127)
	world.set_committed_by_offset(0, 2, water, 127)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var buffered := world.get_committed_secondary_quantity_by_offset(0, 0)
	var middle := world.get_committed_quantity_by_offset(0, 1)
	var far := world.get_committed_quantity_by_offset(0, 2)
	var total := _terrain_quantity_total(world, water)
	backend.shutdown()
	await process_frame
	return _expect(
		buffered == 32 and middle == 143 and far == 143 and total == 318,
		"Overpressure must propagate through later pair passes (buffer %d, middle %d, far %d, total %d)." % [buffered, middle, far, total]
	)


func _verify_third_material_waits_for_a_free_component_slot(registry: TerrainRegistry) -> bool:
	var stone := _terrain_id(registry, "Stone")
	var sand := _terrain_id(registry, "Sand")
	var water := _terrain_id(registry, "Water")
	var air := _terrain_id(registry, "Air")
	var world := WorldGrid.new(WorldDimensions.new(2, 2), stone)
	world.set_committed_by_offset(0, 0, sand, 127)
	world.set_committed_components_by_offset(0, 1, water, 64, air, 64)
	var expected_sand := _terrain_quantity_total(world, sand)
	var expected_water := _terrain_quantity_total(world, water)
	var expected_air := _terrain_quantity_total(world, air)
	var backend := _backend(world, registry)
	backend.attach_to(root)
	await process_frame
	if not await _complete_tick(backend, 1, PASS_COUNT):
		backend.shutdown()
		return false
	backend.commit_if_ready()
	var unchanged := (
		world.get_committed_by_offset(0, 0) == sand
		and world.get_committed_quantity_by_offset(0, 0) == 127
		and _terrain_quantity_total(world, sand) == expected_sand
		and _terrain_quantity_total(world, water) == expected_water
		and _terrain_quantity_total(world, air) == expected_air
	)
	backend.shutdown()
	await process_frame
	return _expect(unchanged, "A third material must wait instead of overwriting either occupied target component.")


func _verify_secondary_material_is_not_rendered(registry: TerrainRegistry) -> bool:
	var air := _terrain_id(registry, "Air")
	var lava := _terrain_id(registry, "Lava")
	var world := WorldGrid.new(WorldDimensions.new(3, 3), air)
	world.set_committed_components_by_offset(1, 1, air, 64, lava, 127)
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
	presenter.set_force_full_brightness(true)
	viewport.add_child(presenter)
	presenter.configure(world, registry)
	await process_frame
	await process_frame
	var center := Vector2i(presenter.position + HexMetrics.center_for_offset(1, 1, presenter.hex_radius))
	var rendered := viewport.get_texture().get_image().get_pixelv(center)
	viewport.free()
	await process_frame
	return _expect(rendered.a < 0.01, "Secondary Lava must remain invisible while Air is the primary component.")


func _terrain_quantity_total(world: WorldGrid, terrain_id: int) -> int:
	var total := 0
	for index in range(world.dimensions.cell_count()):
		if world.get_committed_by_index(index) == terrain_id:
			total += world.get_committed_quantity_by_index(index)
		if world.get_committed_secondary_by_index(index) == terrain_id:
			total += world.get_committed_secondary_quantity_by_index(index)
	return total


func _terrain_quantities_respect_storage(world: WorldGrid, terrain_id: int) -> bool:
	for index in range(world.dimensions.cell_count()):
		if world.get_committed_by_index(index) == terrain_id and world.get_committed_quantity_by_index(index) > 255:
			return false
		if world.get_committed_secondary_by_index(index) == terrain_id and world.get_committed_secondary_quantity_by_index(index) > 255:
			return false
	return true


func _occupied_terrain_cells(world: WorldGrid, terrain_id: int) -> int:
	var occupied := 0
	for index in range(world.dimensions.cell_count()):
		if world.get_committed_by_index(index) == terrain_id and world.get_committed_quantity_by_index(index) > 0:
			occupied += 1
		elif world.get_committed_secondary_by_index(index) == terrain_id and world.get_committed_secondary_quantity_by_index(index) > 0:
			occupied += 1
	return occupied


func _terrain_cells(world: WorldGrid, terrain_id: int) -> Array:
	var cells: Array = []
	for index in range(world.dimensions.cell_count()):
		if world.get_committed_by_index(index) == terrain_id or world.get_committed_secondary_by_index(index) == terrain_id:
			cells.append({
				"offset": world.dimensions.index_to_offset(index),
				"primary": world.get_committed_by_index(index),
				"quantity": world.get_committed_quantity_by_index(index),
				"secondary": world.get_committed_secondary_by_index(index),
				"secondary_quantity": world.get_committed_secondary_quantity_by_index(index),
			})
	return cells


func _verify_live_run_player_light() -> bool:
	var app := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
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
	var expected_settle_ticks := maxi(0, app.generation_profile.initial_settle_ticks)
	var live_backend := app.simulation_backend() as RenderTextureSimulationBackend
	if not _expect(
		live_backend != null and live_backend.ticks_completed() >= expected_settle_ticks,
		"The live run must commit all configured settlement ticks before PLAYING."
	):
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


func _verify_fixed_seed_initial_settlement(registry: TerrainRegistry) -> bool:
	var profile := load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile
	profile.width = 32
	profile.depth = 96
	var run_seed := SeedUtils.seed_from_text("renderer-settlement-determinism")
	var generator := WorldGenerator.new()
	var first_result := generator.generate(profile, registry, run_seed)
	var second_result := generator.generate(profile, registry, run_seed)
	if not _expect(first_result != null and second_result != null, "Fixed-seed settlement fixtures must generate successfully."):
		return false
	var settled_snapshots: Array[PackedByteArray] = []
	for result in [first_result, second_result]:
		var backend := _backend(result.world, registry)
		backend.attach_to(root)
		await process_frame
		for revision in range(1, maxi(0, profile.initial_settle_ticks) + 1):
			if not await _complete_tick(backend, revision, PASS_COUNT):
				backend.shutdown()
				return false
			backend.commit_if_ready()
		settled_snapshots.append(result.world.copy_rgba_bytes())
		backend.shutdown()
		await process_frame
	return _expect(
		settled_snapshots[0] == settled_snapshots[1],
		"The same seed must produce identical packed terrain after initial settlement."
	)


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
