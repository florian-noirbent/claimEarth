extends GutTest


func test_base_target_is_safely_invalid() -> void:
	var target := GrappleTarget.new()
	assert_false(target.is_valid())
	assert_eq(target.anchor_position(), Vector2.ZERO)
	assert_eq(target.radius(), 0.0)
	target.pull_toward(Vector2(10.0, 0.0), 4.0, 1.0 / 60.0)


func test_registry_ignores_null_and_duplicate_registration() -> void:
	var registry := GrappleTargetRegistry.new()
	var first := GrappleTarget.new()
	var second := GrappleTarget.new()
	registry.register(null)
	registry.register(first)
	registry.register(first)
	registry.register(second)
	assert_eq(registry.targets(), [first, second] as Array[GrappleTarget])

	var snapshot := registry.targets()
	registry.unregister(first)
	assert_eq(snapshot.size(), 2, "targets() returns a copy")
	assert_eq(registry.targets(), [second] as Array[GrappleTarget])
	registry.unregister(first)
	registry.clear()
	assert_true(registry.targets().is_empty())
