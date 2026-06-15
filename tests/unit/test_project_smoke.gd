extends GutTest


func test_project_uses_godot_4_6() -> void:
	var version := Engine.get_version_info()
	assert_eq(version.major, 4)
	assert_eq(version.minor, 6)


func test_main_scene_is_configured() -> void:
	var main_scene := ProjectSettings.get_setting("application/run/main_scene", "") as String
	assert_eq(main_scene, "res://scenes/app/main.tscn")


func test_main_scene_has_required_runtime_resources() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var app_root := scene.instantiate() as AppRoot
	add_child_autofree(app_root)

	assert_not_null(app_root.generation_profile)
	assert_not_null(app_root.leaderboard_config)
	assert_not_null(app_root.player_scene)


func test_web_compatible_renderer_is_configured() -> void:
	var renderer := ProjectSettings.get_setting("rendering/renderer/rendering_method", "") as String
	assert_eq(renderer, "gl_compatibility")
