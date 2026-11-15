## What the player body is doing this physics step, as far as its animation is concerned.
class_name PlayerAnimationSnapshot
extends RefCounted


var velocity := Vector2.ZERO
var grounded := false
var ragdolling := false
var ragdoll_spin_direction := 1.0
var ragdoll_spin_speed := 0.0
## True while the rope holds a fixed point the body swings around.
var swinging := false
## Share of the body inside liquid, from 0 to 1.
var liquid_submersion := 0.0
var sand_burrowing := false
