## Generates scenes/player/player_rig.tscn: the player's cutout skeleton, draw-ordered
## sprites, animation clips, and animation state machine.
##
## The tables below are the source of the rig; rerunning overwrites the scene, so
## edit here rather than in the editor. Import the part textures first.
## Usage: godot --headless --path . --script res://tools/build_player_rig.gd
extends SceneTree


const OUTPUT_PATH := "res://scenes/player/player_rig.tscn"
const TEXTURE_DIR := "res://assets/objects/player/"
const RIG_SCRIPT_PATH := "res://src/player/player_rig.gd"

const OUTLINE_SHADER_PATH := "res://src/player/player_outline.gdshader"

## World height of the standing rig, from boot sole to helmet top.
const RIG_HEIGHT := 52.0
## Transparent margin tools/extract_player_parts.py leaves around every part texture.
const TEXTURE_MARGIN := 32.0
const FAR_LIMB_TINT := Color(0.8, 0.78, 0.84)
## The silhouette outline that separates the body from the cave behind it.
const OUTLINE_COLOR := Color(0.07, 0.04, 0.03)
## Outline thickness in world units; it cannot exceed the texture margin once scaled.
const OUTLINE_WIDTH := 1.7
## The look while burrowing through sand, when the whole rig is drawn over the terrain:
## a brighter, thicker silhouette outline and a dark tint that sets the buried body off against the sand.
const BURROW_OUTLINE_COLOR := Color(1.0, 0.84, 0.22)
const BURROW_OUTLINE_WIDTH := 2.3
const BURROW_BODY_TINT := Color(0.42, 0.33, 0.22)
## Absolute draw layer of a burrowing rig, above the terrain and below world effects.
const BURROW_Z_INDEX := 10
const DEFAULT_BLEND_SECONDS := 0.12
## Cross-fade into a state, for the states that should not use the default.
const BLEND_SECONDS := {
	&"idle": 0.16,
	&"jump": 0.06,
	&"land": 0.05,
	&"ragdoll": 0.06,
}

## Bones, parents first. All coordinates are texture pixels.
##   pivot  - the joint inside the bone's own texture.
##   attach - where that joint sits inside the parent's texture.
##   z      - draw order, back to front; bones without a texture are not drawn.
##   scale  - uniform size of the drawn part; width - extra thickness across the limb.
const BONES: Array[Dictionary] = [
	{"name": "Pelvis", "parent": "", "texture": "pelvis", "pivot": Vector2(102, 75), "attach": Vector2.ZERO, "z": 12, "width": 1.12},
	{"name": "Torso", "parent": "Pelvis", "texture": "torso", "pivot": Vector2(125, 208), "attach": Vector2(108, 58), "z": 8, "width": 1.1},
	{"name": "Head", "parent": "Torso", "texture": "head", "pivot": Vector2(168, 252), "attach": Vector2(114, 56), "z": 13},
	{"name": "Backpack", "parent": "Torso", "texture": "backpack", "pivot": Vector2(180, 90), "attach": Vector2(44, 104), "z": 7, "scale": 0.85},
	{"name": "ArmAim", "parent": "Torso", "attach": Vector2(72, 92)},
	{"name": "UpperArm", "parent": "ArmAim", "texture": "upper_arm", "pivot": Vector2(92, 65), "attach": Vector2.ZERO, "z": 16, "width": 1.35},
	{"name": "Forearm", "parent": "UpperArm", "texture": "forearm", "pivot": Vector2(68, 44), "attach": Vector2(78, 156), "z": 15, "width": 1.35},
	{"name": "Hand", "parent": "Forearm", "texture": "hand", "pivot": Vector2(70, 48), "attach": Vector2(68, 114), "z": 14, "width": 1.25},
	{"name": "Grip", "parent": "Hand", "attach": Vector2(75, 80)},
	{"name": "ArmAimLeft", "parent": "Torso", "attach": Vector2(110, 92)},
	{"name": "UpperArmLeft", "parent": "ArmAimLeft", "texture": "upper_arm_left", "pivot": Vector2(92, 68), "attach": Vector2.ZERO, "z": 3, "far": true, "width": 1.35},
	{"name": "ForearmLeft", "parent": "UpperArmLeft", "texture": "forearm_left", "pivot": Vector2(70, 44), "attach": Vector2(78, 160), "z": 2, "far": true, "width": 1.35},
	{"name": "HandLeft", "parent": "ForearmLeft", "texture": "hand_left", "pivot": Vector2(72, 48), "attach": Vector2(70, 120), "z": 1, "far": true, "width": 1.25},
	{"name": "GripLeft", "parent": "HandLeft", "attach": Vector2(72, 82)},
	{"name": "Thigh", "parent": "Pelvis", "texture": "thigh", "pivot": Vector2(90, 44), "attach": Vector2(88, 92), "z": 11, "width": 1.3},
	{"name": "Shin", "parent": "Thigh", "texture": "shin", "pivot": Vector2(102, 46), "attach": Vector2(92, 128), "z": 10, "width": 1.3},
	{"name": "Boot", "parent": "Shin", "texture": "boot", "pivot": Vector2(90, 46), "attach": Vector2(92, 142), "z": 9, "width": 1.15},
	{"name": "ThighLeft", "parent": "Pelvis", "texture": "thigh_left", "pivot": Vector2(88, 44), "attach": Vector2(114, 92), "z": 6, "far": true, "width": 1.3},
	{"name": "ShinLeft", "parent": "ThighLeft", "texture": "shin_left", "pivot": Vector2(102, 46), "attach": Vector2(90, 132), "z": 5, "far": true, "width": 1.3},
	{"name": "BootLeft", "parent": "ShinLeft", "texture": "boot_left", "pivot": Vector2(88, 46), "attach": Vector2(92, 142), "z": 4, "far": true, "width": 1.15},
]

## Animation clips. "rotations" maps a bone to degrees: either one constant or
## [time, degrees] keys. Positive turns clockwise with the rig facing right, so it
## swings a hanging limb backward and leans the torso forward. "pelvis" keys move
## the whole body by texture pixels. Bones left out stay in the rest pose.
const CLIPS: Array[Dictionary] = [
	{
		"name": &"idle", "length": 2.4, "loop": true,
		"pelvis": [[0.0, Vector2(0, 0)], [1.2, Vector2(0, 4)], [2.4, Vector2(0, 0)]],
		"rotations": {
			"Torso": [[0.0, 0], [1.2, 2], [2.4, 0]],
			"Head": [[0.0, 0], [1.2, -2], [2.4, 0]],
			"Backpack": [[0.0, 0], [1.2, -2], [2.4, 0]],
			"UpperArm": [[0.0, 5], [1.2, 8], [2.4, 5]],
			"Forearm": -10,
			"UpperArmLeft": [[0.0, -6], [1.2, -9], [2.4, -6]],
			"ForearmLeft": -10,
			"Thigh": 5, "Shin": 3, "Boot": -8,
			"ThighLeft": -9, "ShinLeft": 4, "BootLeft": 5,
		},
	},
	{
		"name": &"walk", "length": 0.8, "loop": true,
		"pelvis": [[0.0, Vector2(0, 5)], [0.2, Vector2(0, -3)], [0.4, Vector2(0, 5)], [0.6, Vector2(0, -3)], [0.8, Vector2(0, 5)]],
		"rotations": {
			"Torso": [[0.0, 4], [0.2, 6], [0.4, 4], [0.6, 6], [0.8, 4]],
			"Head": -3,
			"Backpack": [[0.0, -2], [0.2, 2], [0.4, -2], [0.6, 2], [0.8, -2]],
			"UpperArm": [[0.0, 24], [0.4, -24], [0.8, 24]],
			"Forearm": [[0.0, -10], [0.4, -32], [0.8, -10]],
			"UpperArmLeft": [[0.0, -24], [0.4, 24], [0.8, -24]],
			"ForearmLeft": [[0.0, -32], [0.4, -10], [0.8, -32]],
			"Thigh": [[0.0, -28], [0.4, 24], [0.6, 0], [0.8, -28]],
			"Shin": [[0.0, 6], [0.2, 10], [0.4, 14], [0.6, 58], [0.8, 6]],
			"Boot": [[0.0, 8], [0.2, -8], [0.4, -20], [0.6, -30], [0.8, 8]],
			"ThighLeft": [[0.0, 24], [0.2, 0], [0.4, -28], [0.8, 24]],
			"ShinLeft": [[0.0, 14], [0.2, 58], [0.4, 6], [0.6, 10], [0.8, 14]],
			"BootLeft": [[0.0, -20], [0.2, -30], [0.4, 8], [0.6, -8], [0.8, -20]],
		},
	},
	{
		"name": &"run", "length": 0.48, "loop": true,
		"pelvis": [[0.0, Vector2(0, 8)], [0.12, Vector2(0, -8)], [0.24, Vector2(0, 8)], [0.36, Vector2(0, -8)], [0.48, Vector2(0, 8)]],
		"rotations": {
			"Torso": [[0.0, 13], [0.12, 16], [0.24, 13], [0.36, 16], [0.48, 13]],
			"Head": -8,
			"Backpack": [[0.0, -4], [0.12, 3], [0.24, -4], [0.36, 3], [0.48, -4]],
			"UpperArm": [[0.0, 45], [0.24, -50], [0.48, 45]],
			"Forearm": [[0.0, -70], [0.24, -90], [0.48, -70]],
			"UpperArmLeft": [[0.0, -50], [0.24, 45], [0.48, -50]],
			"ForearmLeft": [[0.0, -90], [0.24, -70], [0.48, -90]],
			"Thigh": [[0.0, -52], [0.24, 36], [0.36, -5], [0.48, -52]],
			"Shin": [[0.0, 22], [0.12, 18], [0.24, 50], [0.36, 105], [0.48, 22]],
			"Boot": [[0.0, 20], [0.12, -10], [0.24, -30], [0.36, -20], [0.48, 20]],
			"ThighLeft": [[0.0, 36], [0.12, -5], [0.24, -52], [0.48, 36]],
			"ShinLeft": [[0.0, 50], [0.12, 105], [0.24, 22], [0.36, 18], [0.48, 50]],
			"BootLeft": [[0.0, -30], [0.12, -20], [0.24, 20], [0.36, -10], [0.48, -30]],
		},
	},
	{
		"name": &"jump", "length": 0.6, "loop": true,
		"rotations": {
			"Torso": -5,
			"Head": -8,
			"Backpack": [[0.0, 4], [0.3, 6], [0.6, 4]],
			"UpperArm": [[0.0, -62], [0.3, -70], [0.6, -62]],
			"Forearm": -75,
			"UpperArmLeft": [[0.0, -150], [0.3, -142], [0.6, -150]],
			"ForearmLeft": -20,
			"Thigh": -55, "Shin": 85, "Boot": 10,
			"ThighLeft": 12, "ShinLeft": 28, "BootLeft": 25,
		},
	},
	{
		"name": &"fall", "length": 0.5, "loop": true,
		"rotations": {
			"Torso": 6,
			"Head": 10,
			"Backpack": [[0.0, -6], [0.25, -9], [0.5, -6]],
			"UpperArm": [[0.0, -112], [0.25, -128], [0.5, -112]],
			"Forearm": [[0.0, -15], [0.25, -30], [0.5, -15]],
			"UpperArmLeft": [[0.0, 125], [0.25, 110], [0.5, 125]],
			"ForearmLeft": [[0.0, -25], [0.25, -10], [0.5, -25]],
			"Thigh": [[0.0, -25], [0.25, -12], [0.5, -25]],
			"Shin": [[0.0, 35], [0.25, 50], [0.5, 35]],
			"Boot": 15,
			"ThighLeft": [[0.0, 20], [0.25, 8], [0.5, 20]],
			"ShinLeft": [[0.0, 50], [0.25, 35], [0.5, 50]],
			"BootLeft": 20,
		},
	},
	{
		"name": &"land", "length": 0.3, "loop": false,
		"pelvis": [[0.0, Vector2(0, 34)], [0.3, Vector2(0, 26)]],
		"rotations": {
			"Torso": [[0.0, 22], [0.3, 16]],
			"Head": -12,
			"Backpack": -6,
			"UpperArm": 28, "Forearm": -40,
			"UpperArmLeft": -20, "ForearmLeft": -45,
			"Thigh": [[0.0, -42], [0.3, -36]],
			"Shin": [[0.0, 72], [0.3, 62]],
			"Boot": [[0.0, -30], [0.3, -26]],
			"ThighLeft": [[0.0, -52], [0.3, -46]],
			"ShinLeft": [[0.0, 76], [0.3, 66]],
			"BootLeft": [[0.0, -24], [0.3, -20]],
		},
	},
	{
		"name": &"hook_swing", "length": 1.4, "loop": true,
		"rotations": {
			"Torso": [[0.0, -3], [0.7, 3], [1.4, -3]],
			"Head": -14,
			"Backpack": [[0.0, 3], [0.7, -3], [1.4, 3]],
			"UpperArm": 178, "Forearm": 4,
			"UpperArmLeft": 168, "ForearmLeft": 10,
			"Thigh": [[0.0, 8], [0.7, 20], [1.4, 8]],
			"Shin": [[0.0, 24], [0.7, 36], [1.4, 24]],
			"Boot": 22,
			"ThighLeft": [[0.0, -18], [0.7, -6], [1.4, -18]],
			"ShinLeft": [[0.0, 34], [0.7, 22], [1.4, 34]],
			"BootLeft": 18,
		},
	},
	{
		"name": &"swim", "length": 1.0, "loop": true,
		"pelvis": [[0.0, Vector2(0, -4)], [0.5, Vector2(0, 4)], [1.0, Vector2(0, -4)]],
		"rotations": {
			"Torso": [[0.0, 20], [0.5, 26], [1.0, 20]],
			"Head": -16,
			"Backpack": [[0.0, -3], [0.5, 3], [1.0, -3]],
			"UpperArm": [[0.0, -105], [0.5, -35], [1.0, -105]],
			"Forearm": [[0.0, -15], [0.5, -65], [1.0, -15]],
			"UpperArmLeft": [[0.0, -35], [0.5, -105], [1.0, -35]],
			"ForearmLeft": [[0.0, -65], [0.5, -15], [1.0, -65]],
			"Thigh": [[0.0, 22], [0.5, -12], [1.0, 22]],
			"Shin": [[0.0, 20], [0.5, 42], [1.0, 20]],
			"Boot": 30,
			"ThighLeft": [[0.0, -12], [0.5, 22], [1.0, -12]],
			"ShinLeft": [[0.0, 42], [0.5, 20], [1.0, 42]],
			"BootLeft": 30,
		},
	},
	{
		"name": &"burrow", "length": 0.44, "loop": true,
		"rotations": {
			"Torso": [[0.0, 24], [0.22, 30], [0.44, 24]],
			"Head": -18,
			"UpperArm": [[0.0, -125], [0.22, -60], [0.44, -125]],
			"Forearm": [[0.0, -20], [0.22, -70], [0.44, -20]],
			"UpperArmLeft": [[0.0, -60], [0.22, -125], [0.44, -60]],
			"ForearmLeft": [[0.0, -70], [0.22, -20], [0.44, -70]],
			"Thigh": [[0.0, 18], [0.22, -8], [0.44, 18]],
			"Shin": [[0.0, 30], [0.22, 55], [0.44, 30]],
			"ThighLeft": [[0.0, -8], [0.22, 18], [0.44, -8]],
			"ShinLeft": [[0.0, 55], [0.22, 30], [0.44, 55]],
		},
	},
	# PlayerRig swings the head, backpack, arms, and legs itself while knocked out,
	# so this clip only holds the pose those bones start from and the rest of the body.
	{
		"name": &"ragdoll", "length": 1.0, "loop": true,
		"rotations": {
			"Torso": 8,
			"Head": 10,
			"UpperArm": -30, "Forearm": -25,
			"UpperArmLeft": 25, "ForearmLeft": -25,
			"Thigh": -15, "Shin": 30, "Boot": 25,
			"ThighLeft": 15, "ShinLeft": 30, "BootLeft": 25,
		},
	},
]

var _bones := {}
var _bone_paths := {}
var _rest_positions := {}


func _init() -> void:
	var root := Node2D.new()
	root.name = "PlayerRig"
	root.set_script(load(RIG_SCRIPT_PATH))

	var skeleton := Node2D.new()
	skeleton.name = "Skeleton"
	_add(root, root, skeleton)
	var outline := Node2D.new()
	outline.name = "Outline"
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add(root, root, outline)
	var sprites := Node2D.new()
	sprites.name = "Sprites"
	sprites.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add(root, root, sprites)

	var outline_material := ShaderMaterial.new()
	outline_material.shader = load(OUTLINE_SHADER_PATH)
	outline_material.set_shader_parameter(&"outline_color", OUTLINE_COLOR)
	var bounds := _build_skeleton(root, skeleton, sprites, outline, outline_material)
	var rig_scale := RIG_HEIGHT / bounds.size.y
	outline_material.set_shader_parameter(&"width", OUTLINE_WIDTH / rig_scale)
	if maxf(OUTLINE_WIDTH, BURROW_OUTLINE_WIDTH) / rig_scale > TEXTURE_MARGIN:
		push_error("An outline is wider than the %s px texture margin." % TEXTURE_MARGIN)
		quit(1)
		return
	var burrow_outline_material := ShaderMaterial.new()
	burrow_outline_material.shader = outline_material.shader
	burrow_outline_material.set_shader_parameter(&"outline_color", BURROW_OUTLINE_COLOR)
	burrow_outline_material.set_shader_parameter(&"width", BURROW_OUTLINE_WIDTH / rig_scale)
	root.set(&"outline_material", outline_material)
	root.set(&"burrow_outline_material", burrow_outline_material)
	root.set(&"burrow_body_tint", BURROW_BODY_TINT)
	root.set(&"burrow_z_index", BURROW_Z_INDEX)
	skeleton.scale = Vector2(rig_scale, rig_scale)
	# The rig origin is the ground point under the pelvis.
	skeleton.position = Vector2(0.0, -bounds.end.y * rig_scale)

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	_add(root, root, player)
	var library := AnimationLibrary.new()
	library.add_animation(&"RESET", _build_animation({"name": &"RESET", "length": 0.001, "loop": false}))
	for clip in CLIPS:
		library.add_animation(clip["name"], _build_animation(clip))
	player.add_animation_library(&"", library)

	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	tree.unique_name_in_owner = true
	_add(root, root, tree)
	tree.tree_root = _build_state_machine()
	# PlayerRig advances the tree itself, once per physics step, before posing on top of it.
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.anim_player = tree.get_path_to(player)
	tree.active = true

	var scene := PackedScene.new()
	var result := scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, OUTPUT_PATH)
	root.free()
	if result != OK:
		push_error("Could not save %s: %s" % [OUTPUT_PATH, error_string(result)])
		quit(1)
		return
	print("Saved %s" % OUTPUT_PATH)
	quit()


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


## Creates the bones and their sprites, returning the rest-pose bounds in texture pixels.
func _build_skeleton(
	root: Node2D,
	skeleton: Node2D,
	sprites: Node2D,
	outline: Node2D,
	outline_material: ShaderMaterial
) -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	var origins := {}
	var drawn: Array[Dictionary] = []
	for bone in BONES:
		var bone_name: String = bone["name"]
		var parent_name: String = bone["parent"]
		var node := Node2D.new()
		node.name = bone_name
		node.unique_name_in_owner = true
		var parent_node: Node2D = skeleton
		var parent_origin := Vector2.ZERO
		if parent_name != "":
			parent_node = _bones[parent_name]
			parent_origin = origins[parent_name]
			node.position = (bone["attach"] as Vector2) - _pivot(_definition(parent_name))
		_add(root, parent_node, node)
		_bones[bone_name] = node
		_bone_paths[bone_name] = str(root.get_path_to(node))
		_rest_positions[bone_name] = node.position
		origins[bone_name] = parent_origin + node.position

		if not bone.has("texture"):
			continue
		var texture := load("%s%s.png" % [TEXTURE_DIR, bone["texture"]]) as Texture2D
		var part_scale := _part_scale(bone)
		var margin := Vector2(TEXTURE_MARGIN, TEXTURE_MARGIN)
		var top_left: Vector2 = origins[bone_name] - (_pivot(bone) - margin) * part_scale
		var rect := Rect2(top_left, (texture.get_size() - margin * 2.0) * part_scale)
		bounds = rect if not has_bounds else bounds.merge(rect)
		has_bounds = true
		drawn.append({"bone": bone, "node": node, "texture": texture})

	drawn.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["bone"]["z"]) < int(b["bone"]["z"])
	)
	for entry in drawn:
		var bone: Dictionary = entry["bone"]
		# Sprites live in flat lists so draw order is independent of the bone hierarchy.
		var sprite := _add_part_sprite(root, sprites, entry, "Sprite")
		if bone.get("far", false):
			sprite.modulate = FAR_LIMB_TINT
		# Every silhouette sits behind every painted part, so only the body's outer edge shows.
		_add_part_sprite(root, outline, entry, "Outline").material = outline_material
	return bounds


## Adds one sprite of a bone's texture to a flat list and makes it follow the bone.
func _add_part_sprite(root: Node2D, list: Node2D, entry: Dictionary, follower_name: String) -> Sprite2D:
	var bone: Dictionary = entry["bone"]
	var sprite := Sprite2D.new()
	sprite.name = bone["name"]
	sprite.texture = entry["texture"]
	sprite.centered = false
	sprite.offset = -_pivot(bone)
	_add(root, list, sprite)
	var follower := RemoteTransform2D.new()
	follower.name = follower_name
	follower.scale = _part_scale(bone)
	_add(root, entry["node"], follower)
	follower.remote_path = follower.get_path_to(sprite)
	return sprite


func _part_scale(bone: Dictionary) -> Vector2:
	var uniform: float = bone.get("scale", 1.0)
	return Vector2(uniform * float(bone.get("width", 1.0)), uniform)


func _definition(bone_name: String) -> Dictionary:
	for bone in BONES:
		if bone["name"] == bone_name:
			return bone
	return {}


func _pivot(bone: Dictionary) -> Vector2:
	return bone.get("pivot", Vector2.ZERO)


func _build_animation(clip: Dictionary) -> Animation:
	var animation := Animation.new()
	animation.length = clip["length"]
	animation.loop_mode = Animation.LOOP_LINEAR if clip["loop"] else Animation.LOOP_NONE
	var rotations: Dictionary = clip.get("rotations", {})
	for bone in BONES:
		var bone_name: String = bone["name"]
		if not bone.has("texture"):
			continue
		# Every clip keys every drawn bone, so no pose leaks from the previous state.
		var track := _add_track(animation, "%s:rotation" % _bone_paths[bone_name])
		var keys: Variant = rotations.get(bone_name, 0)
		if keys is Array:
			for key: Array in keys:
				animation.track_insert_key(track, key[0], deg_to_rad(key[1]))
		else:
			animation.track_insert_key(track, 0.0, deg_to_rad(keys))

	var pelvis_track := _add_track(animation, "%s:position" % _bone_paths["Pelvis"])
	var rest: Vector2 = _rest_positions["Pelvis"]
	for key: Array in clip.get("pelvis", [[0.0, Vector2.ZERO]]):
		animation.track_insert_key(pelvis_track, key[0], rest + (key[1] as Vector2))
	return animation


func _add_track(animation: Animation, path: String) -> int:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	animation.track_set_interpolation_loop_wrap(track, true)
	return track


## Every state can cross-fade straight into every other; PlayerAnimationSelector decides when.
func _build_state_machine() -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()
	var names: Array[StringName] = []
	for index in CLIPS.size():
		var state: StringName = CLIPS[index]["name"]
		names.append(state)
		var node := AnimationNodeAnimation.new()
		node.animation = state
		var angle := TAU * float(index) / float(CLIPS.size())
		machine.add_node(state, node, Vector2(520, 320) + Vector2.from_angle(angle) * 300.0)

	var entry := AnimationNodeStateMachineTransition.new()
	entry.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition(&"Start", names[0], entry)
	for from_state in names:
		for to_state in names:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = BLEND_SECONDS.get(to_state, DEFAULT_BLEND_SECONDS)
			machine.add_transition(from_state, to_state, transition)
	return machine
