extends GutTest


func test_lethal_overlap_arms_once_and_detonates_after_configured_delay() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	var explosive := WorldExplosive2D.new()
	host.add_child(explosive)
	var definition := load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition
	explosive.configure(definition, PackedVector2Array(), host)
	watch_signals(explosive)
	var own_cell := HexMetrics.offset_for_world(explosive.global_position, 16.0)

	assert_true(explosive.try_arm_from_lethal_cells([own_cell], 16.0))
	assert_false(explosive.try_arm_from_lethal_cells([own_cell], 16.0))
	assert_signal_emit_count(explosive, "chain_armed", 1)
	explosive._physics_process(0.29)
	assert_signal_not_emitted(explosive, "detonation_requested")
	explosive._physics_process(0.02)
	assert_signal_emit_count(explosive, "detonation_requested", 1)
	assert_false(explosive.request_immediate_detonation())


func test_only_cells_intersecting_the_configured_footprint_arm() -> void:
	var explosive := WorldExplosive2D.new()
	add_child_autofree(explosive)
	var definition := load("res://config/items/explosions/chest_explosion.tres") as ExplosionDefinition
	explosive.configure(definition, PackedVector2Array([
		Vector2(-26.0, -16.0), Vector2(26.0, -16.0),
		Vector2(26.0, 16.0), Vector2(-26.0, 16.0),
	]))
	var far_cell := HexMetrics.offset_for_world(Vector2(160.0, 0.0), 16.0)

	assert_false(explosive.try_arm_from_lethal_cells([far_cell], 16.0))
	assert_true(explosive.try_arm_from_lethal_cells([Vector2i.ZERO], 16.0))


func test_pausing_freezes_chain_fuse_and_definition_validation_rejects_bad_radii() -> void:
	var explosive := WorldExplosive2D.new()
	add_child_autofree(explosive)
	var definition := load("res://config/items/explosions/small_bomb_explosion.tres").duplicate(true) as ExplosionDefinition
	explosive.configure(definition)
	assert_true(explosive.try_arm_from_lethal_cells([Vector2i.ZERO], 16.0))
	explosive.set_active(false)
	explosive._physics_process(1.0)
	assert_almost_eq(explosive.chain_fuse_remaining(), 0.3, 0.001)

	definition.lethal_radius = definition.blast_radius + 1
	assert_false(definition.validate().is_empty())
