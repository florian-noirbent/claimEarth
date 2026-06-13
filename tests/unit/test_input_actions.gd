extends GutTest


func test_all_documented_input_actions_exist() -> void:
	for action_name in InputActions.ALL:
		assert_true(InputMap.has_action(action_name), action_name)
