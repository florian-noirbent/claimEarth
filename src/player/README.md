# Player

`src/player` owns movement, grapple, camera models, environment status, runtime perk
tuning, and player presentation. `PlayerController` coordinates physics sequencing
and runtime sampling while consuming grid-backed terrain motion from `src/world`.
`PlayerRuntimeTuning` compiles authored movement/grapple resources and an immutable
perk snapshot into typed active policy. `PlayerPresentationController` owns the
body rig, rope, hook, sand-burrow look, and death sequence and is updated directly
by `PlayerController`; it has no gameplay decisions and, while the player lives, no
process loop of its own.
`GrappleRopeVisual` draws the rope and claw for the presentation and animates their
launch, bite, miss, and retraction from the attachment facts it is stepped with.
`PlayerAnimationSelector` picks the animation state and facing from a per-step
`PlayerAnimationSnapshot`, and `PlayerRig` plays that state, aims the arms,
swings the limbs limply while knocked out, and, while burrowing, draws itself over the
sand with a bright outline and a darkened body. The presentation advances the rig's
animation itself, once per physics step.
Pure models retain movement, grapple, and camera rules for focused tests.

`PlayerController.begin_death` hands the body to `PlayerDeathAnimator`, the one part
of the presentation that steps itself (once per physics step), because a dead
player's physics no longer runs. It plays the `DeathSequence` that
`DeathSequenceLibrary` (`config/player/death/`) stores for the cause: it holds a pose
on the whole rig, frees the sixteen parts into `GibSimulation` (circles with bounce,
friction, liquid drag, and sleep against `TerrainCollisionQuery`), drives the per-part
`player_gib` shaders, lets the rope fall back, and reports `death_cue` and
`gib_landed` facts for the feedback sinks. `DeathContext` carries what is known about
the death (velocity, blast center, impact surface, terrain tags at the body).

Tuning lives in resources under `config/player/`. `WorldGrappleAnchorQuery` is the boundary from grapple logic into terrain and into the moving `GrappleTarget` objects listed in a `GrappleTargetRegistry`; a hooked target is pulled by the rope while the player keeps unhooked movement rules, terrain motion and unstuck results provide typed velocity changes for the accumulating impact hazard, and hazard sampling asks terrain hazard behavior for fill-aware effects. Terrain unstucking targets only Air centers where the full player circle fits and re-evaluates that target each physics frame until clear. The greatest qualifying impact per physics frame adds its excess above the configured safe speed to the shared hazard-status model; accumulated knockout/death classification remains player-owned. Fill-weighted viscosity is sampled from packed terrain metadata after movement and grapple acceleration, then exponentially damps full velocity before collision without fabricating an impact.

Keep player input and physics responsive independent of terrain simulation commits. Camera movement follows descent and uses `DescendingCameraModel` for slow upward recovery to a two-hex margin when the player leaves the top of the screen. Camera shake comes from `CameraShakeModel`, a seeded trauma model the camera controller adds after follow and bounds are resolved; its tuning and the accessibility multiplier are exports on `DescendingCameraController`.
