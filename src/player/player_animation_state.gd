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
## Poses a death sequence holds before the body comes apart; never picked while alive.
const DEATH_CHOKE := &"death_choke"
const DEATH_SPREAD := &"death_spread"
const DEATH_SLUMP := &"death_slump"

const ALL: Array[StringName] = [
	IDLE, WALK, RUN, JUMP, FALL, LAND, HOOK_SWING, SWIM, BURROW, RAGDOLL,
	DEATH_CHOKE, DEATH_SPREAD, DEATH_SLUMP,
]
