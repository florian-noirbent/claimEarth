extends GutTest


func test_inventory_status_tracks_selection_without_exposing_inventory() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)

	controller.select_index(1)
	var status := controller.inventory_status()
	assert_eq(status.selected_name, "Large Bomb")
	assert_eq(status.counts.size(), 3)


func test_flag_resolution_emits_depth_and_lava_outcome() -> void:
	var controller := RunItemController.new()
	add_child_autofree(controller)
	controller.configure_catalog(_item_registry(), 16.0)
	watch_signals(controller)

	var landing_position := HexMetrics.center_for_offset(4, 27, 16.0)
	controller.resolve_flag_landing(null, landing_position, null, &"impact")
	assert_signal_emitted_with_parameters(controller, "flag_planted", [27, landing_position])
	controller.resolve_flag_landing(null, landing_position, null, &"lava")
	assert_signal_emitted(controller, "flag_destroyed")


func _item_registry() -> ItemRegistry:
	var registry := ItemRegistry.new()
	assert_true(registry.try_configure(load("res://config/items/catalog.tres")))
	return registry
