## Plays effect recipes in the world. Every effect of a run shares two particle layers with
## a fixed budget, so a chain of explosions thins out instead of adding nodes.
class_name WorldEffects
extends Node2D


## Share of the disc texture's radius that is fully opaque; the rest is its soft edge.
const DISC_EDGE_START := 0.94

## Looks and thresholds of the gameplay moments GameplayFeedback plays through this node.
@export var library: GameplayEffectLibrary
## Particles each blend layer can show at once; the oldest ones are replaced beyond it.
@export_range(16, 4096, 1) var particles_per_layer := 512
## Share of a layer in use above which new effects spawn fewer particles.
@export_range(0.0, 1.0, 0.01) var pressure_start := 0.45
## Share of its particle count an emitter keeps when its layer is full.
@export_range(0.05, 1.0, 0.01) var pressure_floor := 0.2
## Draw order of the layers: above terrain, world objects, and the player.
@export var layer_z_index := 20
## Pixel size of the generated glow and disc textures.
@export_range(8, 256, 1) var radial_texture_size := 128

var _layers: Array[EffectBatch] = []


func _ready() -> void:
	_ensure_layers()


## Makes every random choice repeatable.
func set_seed(seed_value: int) -> void:
	_ensure_layers()
	for index in _layers.size():
		_layers[index].set_seed(seed_value + index)


## Plays a recipe at a world position. effect_scale multiplies its lengths and speeds, tint
## colors the emitters that take one, direction aims the emitters that follow it, intensity
## (0 to 1 and above) scales the emitters that react to it, and duration_seconds stretches
## the emitters timed by the moment.
func play(
	recipe: EffectRecipe,
	world_position: Vector2,
	effect_scale: float = 1.0,
	tint: Color = Color.WHITE,
	direction: Vector2 = Vector2.RIGHT,
	intensity: float = 1.0,
	duration_seconds: float = 1.0
) -> void:
	if recipe == null:
		return
	_ensure_layers()
	var direction_angle := direction.angle() if direction.length_squared() > 0.0 else 0.0
	for emitter in recipe.emitters:
		if emitter == null or emitter.colors == null:
			continue
		var layer := _layers[emitter.blend]
		var wanted := emitter.count
		if emitter.count_scales_with_intensity:
			wanted = maxi(roundi(wanted * intensity), 1)
		var count := maxi(ceili(wanted * budget_scale(layer)), 1)
		layer.emit(emitter, count, world_position, effect_scale, tint, direction_angle, intensity, duration_seconds)


## Moves the point that anchored particles follow, such as the player.
func set_anchor_position(anchor_position: Vector2) -> void:
	for layer in _layers:
		layer.set_anchor_position(anchor_position)


## Share of its particle count an emitter gets on this layer right now.
func budget_scale(layer: EffectBatch) -> float:
	var usage := float(layer.used_count()) / layer.capacity()
	if usage <= pressure_start:
		return 1.0
	return lerpf(1.0, pressure_floor, (usage - pressure_start) / maxf(1.0 - pressure_start, 0.001))


func live_particle_count() -> int:
	var total := 0
	for layer in _layers:
		total += layer.used_count()
	return total


func particle_capacity() -> int:
	return particles_per_layer * _layers.size()


## Advances every layer by hand, for tests and captures that do not wait for frames.
func advance(delta: float) -> void:
	for layer in _layers:
		layer.advance(delta)


func clear() -> void:
	for layer in _layers:
		layer.clear()


func _ensure_layers() -> void:
	if not _layers.is_empty():
		return
	var glow := _create_radial_texture(PackedFloat32Array([0.0, 0.35, 1.0]), PackedFloat32Array([1.0, 0.45, 0.0]))
	var disc := _create_radial_texture(PackedFloat32Array([0.0, DISC_EDGE_START, 1.0]), PackedFloat32Array([1.0, 1.0, 0.0]))
	# Indexed by EffectEmitter.Blend: the additive layer draws over the normal one.
	for additive: bool in [false, true]:
		var layer := EffectBatch.new(particles_per_layer, additive)
		layer.name = "AdditiveLayer" if additive else "NormalLayer"
		layer.z_index = layer_z_index + (1 if additive else 0)
		layer.set_textures(glow, disc)
		add_child(layer)
		_layers.append(layer)


## White radial texture whose alpha follows the given stops from center to edge.
func _create_radial_texture(offsets: PackedFloat32Array, alphas: PackedFloat32Array) -> Texture2D:
	var colors := PackedColorArray()
	for alpha in alphas:
		colors.append(Color(1.0, 1.0, 1.0, alpha))
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = radial_texture_size
	texture.height = radial_texture_size
	return texture
