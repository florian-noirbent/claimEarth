class_name ExcavatorRobot
extends WorldRigidBody2D


var controller: RunItemController
var factory: ExcavatorItemActionFactory
var remaining := 0.0
var tick_remaining := 0.0
var active := true
var explosive: WorldExplosive2D
var _grounded := false
var tick_interval_multiplier := 1.0


func configure(
	controller_value: RunItemController,
	factory_value: ExcavatorItemActionFactory,
	position_value: Vector2,
	world_value: WorldGrid,
	terrain_registry_value: TerrainRegistry,
	hex_radius_value: float
) -> void:
	controller = controller_value
	factory = factory_value
	world = world_value
	terrain_registry = terrain_registry_value
	hex_radius = hex_radius_value
	global_position = position_value
	remaining = factory.duration_seconds
	tick_remaining = factory.tick_seconds
	configure_body({
		"gravity": factory.gravity,
		"stop_on_impact": true,
		"destroyed_by_lava": true,
		"polygon": factory.body_points,
		"color": factory.body_color,
		"outline_color": factory.body_outline_color,
		"visual_texture": factory.visual_texture,
	})
	explosive = WorldExplosive2D.new()
	explosive.name = "WorldExplosive"
	add_child(explosive)
	explosive.configure(factory.explosion_definition, visual_polygon(), self)
	explosive.detonation_requested.connect(_on_detonation_requested)


func set_active(value: bool) -> void:
	active = value
	set_physics_process(value)
	if explosive != null:
		explosive.set_active(value)


func _physics_process(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	var body_result := advance_body(delta)
	if body_result == &"lava":
		if explosive != null:
			explosive.request_immediate_detonation()
		else:
			queue_free()
		return
	if body_result == &"grounded":
		_grounded = true
	elif body_result == &"" and velocity.length_squared() > 0.001:
		_grounded = false
	remaining -= delta
	tick_remaining -= delta
	if _grounded and tick_remaining <= 0.0 and remaining >= 0.0:
		tick_remaining += factory.tick_seconds * tick_interval_multiplier
		controller.excavator_tick(self, factory)
	if remaining <= 0.0:
		queue_free()


func _on_detonation_requested(_explosive: WorldExplosive2D) -> void:
	if controller != null:
		controller.resolve_explosion(factory.explosion_definition, global_position)
	queue_free()
