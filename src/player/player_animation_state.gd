## Names of the player rig animation states; each matches one clip in the rig scene.
class_name PlayerAnimationState
extends RefCounted


const IDLE := &"idle"
const WALK := &"walk"
const RUN := &"run"
const JUMP := &"jump"
const FALL := &"fall"
const LAND := &"land"
const HOOK_SWING := &"hook_swing"
const SWIM := &"swim"
const BURROW := &"burrow"
const RAGDOLL := &"ragdoll"

const ALL: Array[StringName] = [
	IDLE, WALK, RUN, JUMP, FALL, LAND, HOOK_SWING, SWIM, BURROW, RAGDOLL,
]
