extends GutTest


class FakeSettlementBackend extends TerrainSimulationBackend:
	var controller: RunWorldController
	var world: WorldGrid
	var scheduled_passes := 0
	var commits := 0
	var player_existed_during_settlement := false
	var _commit_ready := false

	func initialize(next_world: WorldGrid, _registry: TerrainRegistry, _seed: int) -> void:
		world = next_world

	func is_available() -> bool:
		return true

	func advance(max_passes: int) -> SimulationProgress:
		var progress := SimulationProgress.new()
		if controller != null and controller.player() != null:
			player_existed_during_settlement = true
		if _commit_ready or max_passes <= 0:
			return progress
		progress.passes_scheduled = mini(max_passes, 6)
		scheduled_passes += progress.passes_scheduled
		_commit_ready = progress.passes_scheduled == 6
		return progress

	func commit_if_ready() -> SimulationCommit:
		var commit := SimulationCommit.new()
		if not _commit_ready:
			return commit
		_commit_ready = false
		commits += 1
		commit.did_commit = true
		commit.revision = commits
		return commit

	func presentation_texture() -> Texture2D:
		return world.texture() if world != null else null

	func presentation_even_texture() -> Texture2D:
		return presentation_texture()


class FakeGrappleTarget extends GrappleTarget:
	var center := Vector2.ZERO

	func is_valid() -> bool:
		return true

	func anchor_position() -> Vector2:
		return center

	func radius() -> float:
		return 6.0


func test_configure_exposes_valid_registries_and_empty_read_models() -> void:
	var controller := RunWorldController.new()
	controller.terrain_catalog = load("res://config/terrain/catalog.tres")
	controller.item_catalog = load("res://config/items/catalog.tres")
	var background := WorldBackground.new()
	background.presentation_config = load("res://config/presentation/default_world_presentation.tres").duplicate(true) as WorldPresentationConfig
	var presenter := WorldPresenter.new()
	presenter.presentation_config = load("res://config/presentation/default_world_presentation.tres").duplicate(true) as WorldPresentationConfig
	var markers := Node2D.new()
	add_child_autofree(controller)
	add_child_autofree(background)
	add_child_autofree(presenter)
	add_child_autofree(markers)

	controller.configure(
		load("res://config/generation/default_profile.tres"),
		load("res://scenes/player/player.tscn"),
		background,
		presenter,
		markers
	)

	assert_not_null(controller.terrain_registry())
	assert_not_null(controller.item_registry())
	assert_null(controller.current_world())
	assert_null(controller.player())


func test_cancel_generation_is_safe_before_any_generation_starts() -> void:
	var controller := RunWorldController.new()
	add_child_autofree(controller)
	controller.cancel_generation()
	assert_null(controller.current_world())


func test_leaving_active_gameplay_clears_accumulated_simulation_time() -> void:
	var controller := RunWorldController.new()
	add_child_autofree(controller)
	controller._simulation_clock.add_time(0.25)
	assert_gt(controller._simulation_clock.pending_passes(), 0.0)

	controller.set_active(false)

	assert_eq(controller._simulation_clock.pending_passes(), 0.0)


func test_initial_settlement_commits_fifty_ticks_before_creating_player() -> void:
	var session := _configured_session(50)
	var backend := FakeSettlementBackend.new()
	backend.controller = session.world_controller
	session.world_controller._simulation_backend = backend
	var progress_values: Array[float] = []
	var progress_labels: Array[String] = []
	session.generation_progressed.connect(func(progress: float, label: String) -> void:
		progress_values.append(progress)
		progress_labels.append(label)
	)

	await session.world_controller.start_run(SeedUtils.seed_from_text("initial-settlement"))

	assert_eq(backend.commits, 50)
	assert_eq(backend.scheduled_passes, 300)
	assert_false(backend.player_existed_during_settlement)
	assert_not_null(session.world_controller.player())
	assert_true(progress_labels.has("Settling terrain"))
	assert_eq(progress_values.back(), 1.0)
	for index in range(1, progress_values.size()):
		assert_gte(progress_values[index], progress_values[index - 1])


func test_non_positive_initial_settlement_ticks_bypass_backend_advancement() -> void:
	var session := _configured_session(-5)
	var backend := FakeSettlementBackend.new()
	backend.controller = session.world_controller
	session.world_controller._simulation_backend = backend

	await session.world_controller.start_run(SeedUtils.seed_from_text("no-initial-settlement"))

	assert_eq(backend.commits, 0)
	assert_eq(backend.scheduled_passes, 0)
	assert_not_null(session.world_controller.player())


func test_grapple_targets_reach_the_player_hook_across_restarts_and_reconfiguration() -> void:
	var session := _configured_session(-5)
	var backend := FakeSettlementBackend.new()
	backend.controller = session.world_controller
	session.world_controller._simulation_backend = backend

	await session.world_controller.start_run(SeedUtils.seed_from_text("grapple-targets-first"))
	assert_true(_hook_hits_registered_target(session.world_controller, session.grapple_targets()))

	await session.world_controller.start_run(SeedUtils.seed_from_text("grapple-targets-second"))
	assert_true(_hook_hits_registered_target(session.world_controller, session.grapple_targets()))

	var replacement := GrappleTargetRegistry.new()
	session.world_controller.configure_grapple_targets(replacement)
	assert_true(_hook_hits_registered_target(session.world_controller, replacement))


func _hook_hits_registered_target(controller: RunWorldController, targets: GrappleTargetRegistry) -> bool:
	var player := controller.player()
	assert_not_null(player)
	var target := FakeGrappleTarget.new()
	target.center = player.global_position + Vector2.RIGHT * 20.0
	targets.register(target)
	var query: GrappleAnchorQuery = player._grapple_model._anchor_query
	var anchor := query.find_anchor(player.global_position, player.global_position + Vector2.RIGHT * 100.0)
	targets.unregister(target)
	return anchor != null and anchor.target == target


func _configured_session(initial_settle_ticks: int) -> RunSession:
	var scene := load("res://scenes/app/run_session.tscn") as PackedScene
	var session := scene.instantiate() as RunSession
	var profile := load("res://config/generation/default_profile.tres").duplicate(true) as GenerationProfile
	profile.initial_settle_ticks = initial_settle_ticks
	add_child_autofree(session)
	session.configure(profile, load("res://scenes/player/player.tscn") as PackedScene)
	return session
