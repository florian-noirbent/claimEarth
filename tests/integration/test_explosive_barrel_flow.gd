extends GutTest


const ROOM_LEFT := 40
const ROOM_RIGHT := 60
const ROOM_HEIGHT := 14
## Columns and rows around the room that must hold no generated container or barrel.
const ROOM_CLEARANCE := 6


func before_each() -> void:
	for suffix in ["spawn", "push", "hook", "terrain", "chain", "impact", "freeze", "teardown"]:
		var path := "user://gut_explosive_barrel_flow_%s.json" % suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func after_each() -> void:
	for action in [InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.HOOK, InputActions.ROPE_UP]:
		Input.action_release(action)


func test_generated_barrels_spawn_for_the_seed_as_hook_targets() -> void:
	# Before anchors required solid ground clear of lava, four barrels of this seed detonated unprompted.
	var app_root := await _start_app("spawn", "explosive-barrel-flow-terrain")
	var spawns := app_root.last_generation_result_for_test().explosive_barrel_spawns
	var barrels := _barrels(app_root)

	assert_gt(spawns.size(), 0, "The default profile places barrels for this seed")
	assert_eq(barrels.size(), spawns.size())
	for index in barrels.size():
		assert_same(barrels[index].spawn_data, spawns[index])
		assert_true(barrels[index].is_active())
	assert_eq(app_root.item_controller.explosive_barrel_count(), spawns.size())
	assert_eq(_session_targets(app_root).size(), spawns.size())
	assert_eq(app_root.active_projectile_count(), 0, "Generated barrels are not thrown items")
	assert_eq(app_root.item_chest_count_for_test(), 19, "Barrels leave the chest placement unchanged")

	# Regression: barrels generated beside lava detonated on their own as the run started.
	watch_signals(app_root.item_controller)
	await wait_seconds(2.0)
	assert_signal_emit_count(app_root.item_controller, "explosion_resolved", 0, "No barrel detonates without a trigger")
	assert_eq(app_root.item_controller.explosive_barrel_count(), spawns.size())
	for barrel in barrels:
		assert_true(is_instance_valid(barrel) and barrel.is_sleeping(), "Generated barrels start at rest and sleep")


func test_player_walks_through_a_barrel_and_pushes_it_along() -> void:
	var app_root := await _start_app("push")
	var top := _build_room(app_root)
	var barrel := _barrels(app_root)[0]
	_place_barrel(app_root, barrel, Vector2i(50, top + ROOM_HEIGHT - 2))
	var player := app_root.get_player()
	_place_player(app_root, Vector2i(44, top + ROOM_HEIGHT - 3))
	await _wait_until_resting(barrel)
	await wait_physics_frames(20)
	var barrel_start := barrel.global_position
	var player_start := player.global_position

	Input.action_press(InputActions.MOVE_RIGHT)
	await wait_physics_frames(60)
	Input.action_release(InputActions.MOVE_RIGHT)

	assert_gt(barrel.global_position.x, barrel_start.x + 24.0, "The barrel is pushed ahead of the player")
	assert_gt(player.global_position.x, player_start.x + 48.0, "The barrel never blocks the player")
	assert_gt(player.global_position.x, barrel_start.x, "The player passes the barrel's starting position")
	assert_true(barrel.is_live(), "A walking push is far below the impact detonation speed")
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)


func test_hook_attaches_to_a_barrel_pulls_it_and_detaches_when_it_detonates() -> void:
	var app_root := await _start_app("hook")
	var top := _build_room(app_root)
	var barrel := _barrels(app_root)[0]
	_place_barrel(app_root, barrel, Vector2i(52, top + ROOM_HEIGHT - 2))
	var player := app_root.get_player()
	_place_player(app_root, Vector2i(44, top + ROOM_HEIGHT - 3))
	await _wait_until_resting(barrel)
	await wait_physics_frames(20)
	var barrel_start := barrel.global_position

	_aim_at(app_root, barrel.global_position)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(2)
	assert_true(player.is_grapple_target_attached(), "The hook holds the barrel instead of terrain")
	assert_eq(player.current_grapple_anchor_position(), barrel.global_position)

	Input.action_press(InputActions.ROPE_UP)
	await wait_physics_frames(30)
	Input.action_release(InputActions.ROPE_UP)

	assert_lt(barrel.global_position.x, barrel_start.x - 24.0, "Reeling in pulls the barrel toward the player")
	assert_eq(player.current_grapple_anchor_position(), barrel.global_position, "The rope follows the moving barrel")
	assert_gt(
		player.global_position.distance_to(barrel.global_position),
		barrel.barrel_definition().explosion_definition.player_kill_radius * app_root.world_presenter.hex_radius,
		"Precondition: the player stays outside the barrel's kill radius"
	)

	assert_true(barrel.explosive.request_immediate_detonation())
	await wait_physics_frames(1)

	assert_false(player.is_grapple_attached(), "A detonated barrel releases the hook")
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	Input.action_release(InputActions.HOOK)


func test_lava_or_acid_reaching_a_resting_barrel_detonates_it_into_overpressured_sulfur_dioxide() -> void:
	var app_root := await _start_app("terrain")
	var top := _build_room(app_root)
	var barrels := _barrels(app_root)
	assert_gt(barrels.size(), 1)
	var world := app_root.current_world()
	var registry := app_root.terrain_registry()
	var sulfur_dioxide_id := registry.stable_id_for_name("Sulfur Dioxide")
	var hex_radius := app_root.world_presenter.hex_radius
	watch_signals(app_root.item_controller)
	var cases := [["Lava", 44], ["Sulfuric Acid", 56]]
	for index in cases.size():
		var terrain := registry.get_definition(registry.stable_id_for_name(cases[index][0]))
		var barrel := barrels[index]
		_place_barrel(app_root, barrel, Vector2i(cases[index][1], top + ROOM_HEIGHT - 2))
		await _wait_until_resting(barrel)
		assert_true(barrel.is_sleeping(), "A generated barrel at rest stops its physics steps")
		var impact := barrel.global_position
		var cell := HexMetrics.offset_for_world(impact, hex_radius)

		# Simulated fluid replaces committed Air without a change notification.
		world.set_committed_by_offset(cell.x, cell.y, terrain.stable_id, terrain.maximum_quantity)
		var barrel_ref: WeakRef = weakref(barrel)
		await wait_until(func() -> bool: return not _is_live(barrel_ref), 1.5)

		assert_false(_is_live(barrel_ref), "%s detonates the barrel" % terrain.display_name)
		assert_signal_emit_count(app_root.item_controller, "explosion_resolved", index + 1)
		var overpressured := 0
		var origin_hex := HexCoord.from_offset_odd_q(cell.x, cell.y)
		for offset in _cells_within(origin_hex, 4):
			if world.dimensions.is_in_bounds_offset(offset.x, offset.y) \
					and world.get_committed_by_offset(offset.x, offset.y) == sulfur_dioxide_id \
					and world.get_committed_quantity_by_offset(offset.x, offset.y) > 127:
				overpressured += 1
		assert_gt(overpressured, 0, "The %s blast leaves an overpressured sulfur dioxide cloud" % terrain.display_name)
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)


func test_blast_radius_arms_a_barrel_whose_explosion_chains_into_the_next_after_a_fuse() -> void:
	var app_root := await _start_app("chain")
	var top := _build_room(app_root)
	var barrels := _barrels(app_root)
	assert_gt(barrels.size(), 1)
	var first := barrels[0]
	var second := barrels[1]
	var hex_radius := app_root.world_presenter.hex_radius
	_place_barrel(app_root, first, Vector2i(46, top + ROOM_HEIGHT - 2))
	_place_barrel(app_root, second, Vector2i(54, top + ROOM_HEIGHT - 2))
	await _wait_until_resting(first)
	await _wait_until_resting(second)
	var first_hex := _hex_at(first.global_position, hex_radius)
	var second_hex := _hex_at(second.global_position, hex_radius)
	var bomb := load("res://config/items/explosions/small_bomb_explosion.tres") as ExplosionDefinition
	var origin_hex := first_hex.add(HexCoord.new(-bomb.blast_radius, 0))
	var origin_cell := origin_hex.to_offset_odd_q()
	var origin := HexMetrics.center_for_offset(origin_cell.x, origin_cell.y, hex_radius)
	var barrel_blast_radius := first.barrel_definition().explosion_definition.blast_radius
	assert_gt(origin_hex.distance_to(second_hex), bomb.blast_radius, "Precondition: the bomb cannot reach the second barrel")
	assert_lte(first_hex.distance_to(second_hex), barrel_blast_radius, "Precondition: the first barrel's blast reaches the second")
	watch_signals(app_root.item_controller)

	app_root.item_controller.resolve_explosion(bomb, origin)

	assert_true(first.explosive.is_chain_armed(), "The bomb's blast radius, not its lethal core, arms the first barrel")
	assert_false(second.explosive.is_chain_armed())
	assert_true(first.is_live(), "The chain fuse delays the detonation")
	var first_ref: WeakRef = weakref(first)
	await wait_until(func() -> bool: return not _is_live(first_ref), 1.0)
	assert_signal_emit_count(app_root.item_controller, "explosion_resolved", 2)
	assert_true(second.explosive.is_chain_armed(), "The barrel blast arms the next barrel")
	assert_true(second.is_live(), "Each link waits for its own fuse")
	var second_ref: WeakRef = weakref(second)
	await wait_until(func() -> bool: return not _is_live(second_ref), 1.0)
	assert_signal_emit_count(app_root.item_controller, "explosion_resolved", 3)
	assert_eq(app_root.get_run_state(), RunPhase.PLAYING)


func test_long_fall_detonates_a_barrel_on_impact() -> void:
	var app_root := await _start_app("impact")
	var top := _build_room(app_root)
	var barrel := _barrels(app_root)[0]
	var floor_y := HexMetrics.center_for_offset(50, top + ROOM_HEIGHT, app_root.world_presenter.hex_radius).y
	watch_signals(app_root.item_controller)

	_place_barrel(app_root, barrel, Vector2i(50, top))
	var barrel_ref: WeakRef = weakref(barrel)
	await wait_until(func() -> bool: return not _is_live(barrel_ref), 2.0)

	assert_false(_is_live(barrel_ref), "A fall of the room's height detonates the barrel")
	assert_signal_emit_count(app_root.item_controller, "explosion_resolved", 1)
	var impact := get_signal_parameters(app_root.item_controller, "explosion_resolved")[0] as Vector2
	assert_gt(impact.y, floor_y - 3.0 * app_root.world_presenter.hex_radius, "It detonates where it lands")


func test_pause_and_reward_picker_freeze_barrels_fuses_and_pushes() -> void:
	var app_root := await _start_app("freeze")
	var top := _build_room(app_root)
	var barrels := _barrels(app_root)
	var falling := barrels[0]
	var armed := barrels[1]
	_place_barrel(app_root, armed, Vector2i(56, top + ROOM_HEIGHT - 2))
	await _wait_until_resting(armed)
	_place_barrel(app_root, falling, Vector2i(44, top))
	await wait_physics_frames(3)
	assert_true(armed.explosive.try_arm_from_blast(armed.global_position, 0, app_root.world_presenter.hex_radius))

	for phase in [RunPhase.PAUSED, RunPhase.REWARD_PICKER]:
		if phase == RunPhase.PAUSED:
			app_root.ui.pause_button.pressed.emit()
		else:
			_first_chest(app_root.item_controller).touch_area.body_entered.emit(app_root.get_player())
		assert_eq(app_root.get_run_state(), phase)
		assert_false(falling.is_physics_processing())
		assert_false(armed.explosive.is_physics_processing())
		assert_false(app_root.item_controller.is_physics_processing(), "No push checks run while frozen")
		var falling_position := falling.global_position
		var fuse := armed.explosive.chain_fuse_remaining()
		await wait_physics_frames(30)
		assert_eq(falling.global_position, falling_position, "%s freezes a moving barrel" % phase)
		assert_eq(armed.explosive.chain_fuse_remaining(), fuse, "%s freezes a burning fuse" % phase)

		if phase == RunPhase.PAUSED:
			app_root.ui.resume_button.pressed.emit()
		else:
			(app_root.ui.reward_picker_cards.get_child(0) as RewardPickerCard).pressed.emit()
		assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
		assert_true(falling.is_physics_processing())
		assert_true(armed.explosive.is_physics_processing())
		assert_true(app_root.item_controller.is_physics_processing())
		await wait_physics_frames(2)
		assert_ne(falling.global_position, falling_position)
		assert_lt(armed.explosive.chain_fuse_remaining(), fuse)
		if phase == RunPhase.PAUSED:
			# Re-arm with a full fuse so the next phase still sees it burning.
			armed.explosive.disarm()
			assert_true(armed.explosive.try_arm_from_blast(armed.global_position, 0, app_root.world_presenter.hex_radius))
			_place_barrel(app_root, falling, Vector2i(44, top))
			await wait_physics_frames(3)


func test_restart_and_menu_free_barrels_and_empty_the_grapple_registry() -> void:
	var app_root := await _start_app("teardown")
	var top := _build_room(app_root)
	var barrel := _barrels(app_root)[0]
	_place_barrel(app_root, barrel, Vector2i(52, top + ROOM_HEIGHT - 2))
	_place_player(app_root, Vector2i(44, top + ROOM_HEIGHT - 3))
	await _wait_until_resting(barrel)
	await wait_physics_frames(20)
	_aim_at(app_root, barrel.global_position)
	Input.action_press(InputActions.HOOK)
	await wait_physics_frames(2)
	assert_true(app_root.get_player().is_grapple_target_attached())
	var old_barrels := _barrels(app_root)
	var old_targets := app_root._session.grapple_targets()
	assert_eq(old_targets.targets().size(), old_barrels.size())

	app_root.start_run_for_test(SeedUtils.seed_from_text("explosive-barrel-flow-teardown-restart"))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	Input.action_release(InputActions.HOOK)

	for old_barrel in old_barrels:
		assert_false(is_instance_valid(old_barrel), "Restart frees every barrel of the previous run")
	assert_true(old_targets.targets().is_empty())
	assert_false(app_root.get_player().is_grapple_attached())
	var new_barrels := _barrels(app_root)
	var new_targets := app_root._session.grapple_targets()
	assert_ne(new_targets, old_targets)
	assert_eq(new_targets.targets().size(), new_barrels.size())

	app_root.transition_to(RunPhase.MAIN_MENU)
	await wait_process_frames(1)

	assert_eq(app_root.active_session_count(), 0)
	for new_barrel in new_barrels:
		assert_false(is_instance_valid(new_barrel), "Returning to the menu frees every barrel")
	assert_true(new_targets.targets().is_empty())


func _start_app(suffix: String, seed_text: String = "") -> AppRoot:
	var app_root := (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as AppRoot
	app_root.configure_save_path_for_test("user://gut_explosive_barrel_flow_%s.json" % suffix)
	app_root.set_test_mode(true)
	add_child_autofree(app_root)
	await wait_process_frames(1)
	app_root.start_run_for_test(SeedUtils.seed_from_text(seed_text if not seed_text.is_empty() else "explosive-barrel-flow-%s" % suffix))
	await wait_until(func() -> bool:
		return app_root.get_run_state() == RunPhase.PLAYING and app_root.get_player() != null
	, 2.0)
	return app_root


func _barrels(app_root: AppRoot) -> Array[ExplosiveBarrel]:
	var barrels: Array[ExplosiveBarrel] = []
	for child in app_root.item_controller.get_children():
		if child is ExplosiveBarrel and not child.is_queued_for_deletion():
			barrels.append(child as ExplosiveBarrel)
	return barrels


func _session_targets(app_root: AppRoot) -> Array[GrappleTarget]:
	return app_root._session.grapple_targets().targets()


## Carves an Air room with a stone shell where no generated container or barrel sits,
## so headless tests control every cell a barrel or the player touches. Returns the top row.
func _build_room(app_root: AppRoot) -> int:
	var world := app_root.current_world()
	var registry := app_root.terrain_registry()
	var hex_radius := app_root.world_presenter.hex_radius
	var occupied: Array[Vector2i] = []
	var result := app_root.last_generation_result_for_test()
	for spawn in result.item_chest_spawns + result.perk_geode_spawns:
		occupied.append(spawn.anchor_offset)
	for barrel in _barrels(app_root):
		occupied.append(HexMetrics.offset_for_world(barrel.global_position, hex_radius))
	var top := -1
	for candidate in range(48, world.dimensions.depth - ROOM_HEIGHT - 64):
		var clear := true
		for cell in occupied:
			if cell.x >= ROOM_LEFT - ROOM_CLEARANCE and cell.x <= ROOM_RIGHT + ROOM_CLEARANCE \
					and cell.y >= candidate - ROOM_CLEARANCE and cell.y <= candidate + ROOM_HEIGHT + ROOM_CLEARANCE:
				clear = false
				break
		if clear:
			top = candidate
			break
	assert_gt(top, 0, "The test seed must leave room for a quiet test chamber")
	var air_id := registry.stable_id_for_name("Air")
	var stone_id := registry.stable_id_for_name("Stone")
	for col in range(ROOM_LEFT - 2, ROOM_RIGHT + 3):
		for row in range(top - 2, top + ROOM_HEIGHT + 2):
			var inside := col >= ROOM_LEFT and col <= ROOM_RIGHT and row >= top and row < top + ROOM_HEIGHT
			world.set_committed_by_offset(col, row, air_id if inside else stone_id)
	return top


func _place_barrel(app_root: AppRoot, barrel: ExplosiveBarrel, cell: Vector2i) -> void:
	barrel.global_position = HexMetrics.center_for_offset(cell.x, cell.y, app_root.world_presenter.hex_radius)
	barrel.velocity = Vector2.ZERO
	barrel.wake()


func _place_player(app_root: AppRoot, cell: Vector2i) -> void:
	var player := app_root.get_player()
	player.set_spawn_position(HexMetrics.center_for_offset(cell.x, cell.y, app_root.world_presenter.hex_radius))
	player.velocity = Vector2.ZERO
	player._movement_model.velocity = Vector2.ZERO


func _aim_at(app_root: AppRoot, world_position: Vector2) -> void:
	app_root._input_controller.handle_unhandled_input(InputEventMouseMotion.new(), world_position)


func _wait_until_resting(barrel: ExplosiveBarrel) -> void:
	var barrel_ref: WeakRef = weakref(barrel)
	await wait_until(func() -> bool: return not _is_live(barrel_ref) or barrel.is_resting(), 3.0)
	assert_true(barrel.is_resting(), "Precondition: the barrel comes to rest in the room")


## Reads a barrel through a weak reference because a detonated barrel is freed while a wait polls it.
func _is_live(barrel_ref: WeakRef) -> bool:
	var barrel := barrel_ref.get_ref() as ExplosiveBarrel
	return barrel != null and barrel.is_live()


func _first_chest(controller: RunItemController) -> ItemChest:
	for child in controller.get_children():
		if child is ItemChest and (child as ItemChest).spawn_data.definition.reward_kind == ItemChestDefinition.RewardKind.ITEMS:
			return child as ItemChest
	return null


func _hex_at(world_position: Vector2, hex_radius: float) -> HexCoord:
	var cell := HexMetrics.offset_for_world(world_position, hex_radius)
	return HexCoord.from_offset_odd_q(cell.x, cell.y)


func _cells_within(origin: HexCoord, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for delta_q in range(-radius, radius + 1):
		for delta_r in range(maxi(-radius, -delta_q - radius), mini(radius, -delta_q + radius) + 1):
			cells.append(origin.add(HexCoord.new(delta_q, delta_r)).to_offset_odd_q())
	return cells
