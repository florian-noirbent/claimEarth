class_name GameplayAssertions
extends RefCounted


static func assert_app_is_playing(test_case: GutTest, app_root: AppRoot) -> void:
	test_case.assert_eq(app_root.get_run_state(), RunPhase.PLAYING)
	test_case.assert_true(app_root.ui.overlay_root.visible)
	test_case.assert_true(app_root.ui.playing_panel.visible)
	test_case.assert_not_null(app_root.get_player())
	test_case.assert_true(app_root.get_player().is_physics_processing())


static func assert_no_scene_leaks(test_case: GutTest, presenter: WorldPresenter, _max_visible_chunks: int) -> void:
	test_case.assert_eq(presenter.total_renderer_nodes(), 1)


static func assert_projectile_visual_configured(test_case: GutTest, projectile: ItemProjectile, expected_point_count: int) -> void:
	test_case.assert_eq(projectile.visual_polygon().size(), expected_point_count)
	test_case.assert_eq(projectile.outline_point_count(), expected_point_count + 1)
