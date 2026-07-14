## Owns projectile flight, terrain sampling, fuse/bounce behavior, and resolution signals.
class_name ItemProjectile
extends WorldRigidBody2D


signal resolved(projectile: ItemProjectile, impact_position: Vector2, resolution_kind: StringName)


var fuse_seconds := 0.0
var remaining_fuse := 0.0
var action: ItemAction
var explosive: WorldExplosive2D


func _ready() -> void:
	_ensure_visuals()
	remaining_fuse = fuse_seconds


func configure(config: Dictionary) -> void:
	fuse_seconds = float(config.get("fuse_seconds", 0.0))
	remaining_fuse = fuse_seconds
	configure_body(config)
	var explosion_definition := config.get("explosion_definition") as ExplosionDefinition
	if explosion_definition != null:
		if explosive == null:
			explosive = WorldExplosive2D.new()
			explosive.name = "WorldExplosive"
			add_child(explosive)
		explosive.configure(explosion_definition, _pending_polygon)
	var light_definition := config.get("light_definition") as WorldLightSourceDefinition
	if light_definition != null:
		var light_source := WorldLightSource2D.new()
		light_source.name = "WorldLightSource"
		light_source.definition = light_definition
		add_child(light_source)
		light_source.configure(simulation_backend, hex_radius, StringName("item_projectile:%d" % get_instance_id()))


func _physics_process(delta: float) -> void:
	remaining_fuse -= delta
	var body_result := advance_body(delta)
	if body_result == &"lava":
		_resolve_at(global_position, body_result)
		queue_free()
		return
	if body_result == &"impact":
		resolved.emit(self, global_position, body_result)
		queue_free()
		return

	if remaining_fuse <= 0.0:
		_resolve_at(global_position, &"fuse")
		queue_free()


func _resolve_at(impact_position: Vector2, resolution_kind: StringName) -> void:
	if explosive != null:
		explosive.request_immediate_detonation()
		return
	resolved.emit(self, impact_position, resolution_kind)
