## Cutout skeleton of the player: plays animation states, aims both arms at the hook,
## swings the limbs limply while knocked out, shows through sand while burrowing, and
## hands its parts over one by one when a death sequence takes the body apart.
##
## The rig has no process loop. Its owner calls play_state, advance, update_ragdoll,
## and update_aim once per step, in that order.
class_name PlayerRig
extends Node2D


## Bones that hang limp while knocked out, parents first, with their joint limits in
## degrees. A bone without limits turns freely; "up" marks a bone that points upward
## from its joint in the rest pose instead of hanging from it.
const LIMP_BONES: Array[Dictionary] = [
	{"bone": ^"%Head", "limits": Vector2(-32.0, 32.0), "up": true},
	{"bone": ^"%Backpack", "limits": Vector2(-16.0, 16.0)},
	{"bone": ^"%UpperArm"},
	{"bone": ^"%Forearm", "limits": Vector2(-150.0, 5.0)},
	{"bone": ^"%UpperArmLeft"},
	{"bone": ^"%ForearmLeft", "limits": Vector2(-150.0, 5.0)},
	{"bone": ^"%Thigh", "limits": Vector2(-110.0, 70.0)},
	{"bone": ^"%Shin", "limits": Vector2(0.0, 140.0)},
	{"bone": ^"%ThighLeft", "limits": Vector2(-110.0, 70.0)},
	{"bone": ^"%ShinLeft", "limits": Vector2(0.0, 140.0)},
]

## Remaining turn, in radians, below which a hand snaps onto the body's center line.
const CENTER_LOCK_ANGLE := 0.1

## How quickly the arms swing onto and off the hook target; higher is snappier.
@export var aim_response := 18.0
@export_group("Ragdoll")
## Acceleration that counts as one unit of pull on a limp limb; normally the player's gravity.
@export var limp_reference_acceleration := 900.0
## Angular acceleration of a limp limb held level under one unit of pull.
@export var limp_swing := 70.0
## How quickly a swinging limp limb loses its speed.
@export var limp_damping := 5.0
## How strongly air drag trails the limbs behind the body's motion.
@export var limp_drag := 1.2
## Largest pull a sudden stop or kick can put on the limbs, in units of pull.
@export var limp_maximum_pull := 5.0
## Time the limbs take to return from limp to the animated pose.
@export var limp_recover_seconds := 0.25

@export_group("Sand Burrow")
## Silhouette outline materials outside and inside sand; the rig builder fills these in.
@export var outline_material: ShaderMaterial
@export var burrow_outline_material: ShaderMaterial
## Tint of the painted body while it is drawn over the sand it is buried in.
@export var burrow_body_tint := Color.WHITE
## Absolute draw layer of a burrowing rig; it must be above the terrain.
@export var burrow_z_index := 10

@export_group("Parts")
## Transparent margin around every part texture, in texture pixels.
@export var part_texture_margin := 32.0

@onready var animation_tree: AnimationTree = %AnimationTree
@onready var arm_aim: Node2D = %ArmAim
@onready var arm_aim_left: Node2D = %ArmAimLeft
@onready var grip: Node2D = %Grip
@onready var grip_left: Node2D = %GripLeft
@onready var _skeleton: Node2D = $Skeleton
@onready var _pelvis: Node2D = %Pelvis
@onready var _outline: Node2D = $Outline
@onready var _sprites: Node2D = $Sprites

var _playback: AnimationNodeStateMachinePlayback
var _state: StringName = &""
var _limp_nodes: Array[Node2D] = []
var _limp_angles := PackedFloat32Array()
var _limp_speeds := PackedFloat32Array()
var _limp_weight := 0.0
var _limp_velocity := Vector2.ZERO
var _burrowed := false
var _raised := false


func _ready() -> void:
	_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	for limp in LIMP_BONES:
		_limp_nodes.append(get_node(limp["bone"]) as Node2D)
	_limp_angles.resize(LIMP_BONES.size())
	_limp_speeds.resize(LIMP_BONES.size())


func current_state() -> StringName:
	return _state


func play_state(state: StringName) -> void:
	if state == _state:
		return
	_state = state
	if _playback.is_playing():
		_playback.travel(state)
	else:
		_playback.start(state)


func is_burrowed() -> bool:
	return _burrowed


## Shows the body through sand: terrain is drawn over the player, so a burrowing rig
## moves above it with a bright outline and a tinted body. Every part keeps following
## its bone, so the silhouette stays the animated one.
func set_burrowed(burrowed: bool) -> void:
	if burrowed == _burrowed:
		return
	_burrowed = burrowed
	_apply_draw_layer()
	_sprites.modulate = burrow_body_tint if burrowed else Color.WHITE
	var part_material := burrow_outline_material if burrowed else outline_material
	for part: CanvasItem in _outline.get_children():
		part.material = part_material


## Draws the rig above the terrain, which normally covers it, without the burrow look.
func set_raised_above_terrain(raised: bool) -> void:
	_raised = raised
	_apply_draw_layer()


func _apply_draw_layer() -> void:
	var above := _burrowed or _raised
	z_as_relative = not above
	z_index = burrow_z_index if above else 0


## Number of drawn body parts, in draw order from back to front.
func part_count() -> int:
	return _sprites.get_child_count()


func part_name(index: int) -> StringName:
	return _sprites.get_child(index).name


## The painted sprite of a part and the silhouette sprite behind it.
func part_sprite(index: int) -> Sprite2D:
	return _sprites.get_child(index) as Sprite2D


func part_outline(index: int) -> Sprite2D:
	return _outline.get_child(index) as Sprite2D


## Stops a part's two sprites from following their bone, so the caller can move them
## itself. A released part stays released.
func release_part(index: int) -> void:
	var bone := get_node_or_null("%%%s" % part_name(index))
	if bone == null:
		return
	for child in bone.get_children():
		var follower := child as RemoteTransform2D
		if follower != null:
			follower.remote_path = NodePath()


## Advances the animation clips; the limp limbs and the arm aim are then posed on top.
func advance(delta: float) -> void:
	animation_tree.advance(delta)


## How much of the pose is the limp ragdoll instead of the animation, from 0 to 1.
func limp_weight() -> float:
	return _limp_weight


## Swings the limp bones as damped pendulums while knocked out, and eases them back
## to the animation afterwards. velocity is the body's world velocity and spin is its
## world rotation speed, in radians per second. A lying body rests on the ground, so
## its limbs settle along the body instead of hanging down through the floor.
func update_ragdoll(active: bool, lying: bool, velocity: Vector2, spin: float, delta: float) -> void:
	var starting := active and _limp_weight <= 0.0
	if active:
		_limp_weight = 1.0
	elif _limp_weight > 0.0:
		_limp_weight = maxf(0.0, _limp_weight - delta / maxf(limp_recover_seconds, 0.001))
	if starting:
		_limp_velocity = velocity
	if _limp_weight <= 0.0 or delta <= 0.0:
		return

	# Gravity, the reaction to the body's own acceleration, and air drag, in units of pull.
	var unit := maxf(limp_reference_acceleration, 0.001)
	var pull := Vector2.DOWN * unit
	pull -= (velocity - _limp_velocity) / delta
	pull -= velocity * limp_drag
	_limp_velocity = velocity
	pull = (pull / unit).limit_length(limp_maximum_pull)
	var center := _pelvis.global_position
	var to_rig := global_transform.affine_inverse()
	# The rig turns with the body, so a limb that keeps its world direction turns the
	# other way inside the rig. A mirrored rig sees that turn reversed.
	var frame_turn := -spin * delta * signf(scale.x)

	for index in LIMP_BONES.size():
		var limp: Dictionary = LIMP_BONES[index]
		var bone := _limp_nodes[index]
		var parent_angle := _rig_angle(bone.get_parent() as Node2D)
		var animated := bone.rotation
		if starting:
			_limp_angles[index] = parent_angle + animated
			_limp_speeds[index] = 0.0
		# Spinning throws each limb outward from the body's center.
		var bone_pull := pull + (bone.global_position - center) * spin * spin / unit
		# Only the direction is taken into the rig, so the rig's scale cannot change the strength.
		var rest_angle := 0.0
		if not lying:
			rest_angle = to_rig.basis_xform(bone_pull).angle()
			rest_angle += PI * 0.5 if limp.get("up", false) else -PI * 0.5
		var angle := _limp_angles[index] + frame_turn
		var speed := _limp_speeds[index]
		speed += limp_swing * bone_pull.length() * sin(rest_angle - angle) * delta
		speed *= exp(-limp_damping * delta)
		angle += speed * delta

		var local_angle := wrapf(angle - parent_angle, -PI, PI)
		if limp.has("limits"):
			var limits: Vector2 = limp["limits"]
			var limited := clampf(local_angle, deg_to_rad(limits.x), deg_to_rad(limits.y))
			if limited != local_angle:
				# A limb stopped by its joint is carried along by its parent.
				speed = 0.0
				local_angle = limited
		_limp_angles[index] = parent_angle + local_angle
		_limp_speeds[index] = speed
		bone.rotation = lerp_angle(animated, local_angle, _limp_weight)


## World point above the shoulder where the hand of a turning arm meets the body's center line.
func _center_line_reach(aim: Node2D, hand: Node2D) -> Vector2:
	var shoulder := to_local(aim.global_position)
	var arm_length := shoulder.distance_to(to_local(hand.global_position))
	var rise := sqrt(maxf(arm_length * arm_length - shoulder.x * shoulder.x, 0.0))
	return to_global(Vector2(0.0, shoulder.y - rise))


## Rotation of a bone relative to the rig, summed up the skeleton.
func _rig_angle(bone: Node2D) -> float:
	var angle := 0.0
	while bone != null and bone != _skeleton:
		angle += bone.rotation
		bone = bone.get_parent() as Node2D
	return angle


## Turns both arms toward a world position on top of whatever animation is playing,
## or back to the animated pose when not aiming. With centered set, each hand is
## instead held on the body's center line, where it stays put when the rig turns to
## face the other way.
func update_aim(aiming: bool, world_position: Vector2, delta: float, centered: bool = false) -> void:
	var weight := 1.0 - exp(-aim_response * delta)
	_update_arm_aim(arm_aim, grip, aiming, world_position, weight, centered)
	_update_arm_aim(arm_aim_left, grip_left, aiming, world_position, weight, centered)


## World position of the near hand, where the rope is held.
func grip_position() -> Vector2:
	return grip.global_position


func _update_arm_aim(
	aim: Node2D,
	hand: Node2D,
	aiming: bool,
	target: Vector2,
	weight: float,
	centered: bool
) -> void:
	var desired := 0.0
	if aiming:
		if centered:
			target = _center_line_reach(aim, hand)
		var shoulder := aim.get_parent() as Node2D
		var to_target := shoulder.to_local(target) - aim.position
		var to_hand := shoulder.to_local(hand.global_position) - aim.position
		if to_target.length_squared() > 0.0001 and to_hand.length_squared() > 0.0001:
			# The animated arm direction, without the aim already applied, is turned onto the target.
			desired = to_target.angle() - (to_hand.angle() - aim.rotation)
	# A hand that has reached the center line locks onto it, so the smoothing cannot
	# let it trail behind the swaying torso.
	if aiming and centered and absf(angle_difference(aim.rotation, desired)) < CENTER_LOCK_ANGLE:
		weight = 1.0
	aim.rotation = lerp_angle(aim.rotation, desired, weight)
