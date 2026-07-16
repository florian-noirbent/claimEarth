# Player

`src/player` owns movement, grapple, camera models, environment status, runtime perk
tuning, and player presentation. `PlayerController` coordinates physics sequencing
and runtime sampling while consuming grid-backed terrain motion from `src/world`.
`PlayerRuntimeTuning` compiles authored movement/grapple resources and an immutable
perk snapshot into typed active policy. `PlayerPresentationController` owns the
editor-authored body, rope, hook, and sand-outline visuals and is updated directly
by `PlayerController`; it has no gameplay decisions or independent process loop.
Pure models retain movement, grapple, and camera rules for focused tests.

Tuning lives in resources under `config/player/`. `WorldGrappleAnchorQuery` is the boundary from grapple logic into terrain, terrain motion and unstuck results provide typed velocity changes for the accumulating impact hazard, and hazard sampling asks terrain hazard behavior for fill-aware effects. Terrain unstucking targets only Air centers where the full player circle fits and re-evaluates that target each physics frame until clear. The greatest qualifying impact per physics frame adds its excess above the configured safe speed to the shared hazard-status model; accumulated knockout/death classification remains player-owned. Fill-weighted viscosity is sampled from packed terrain metadata after movement and grapple acceleration, then exponentially damps full velocity before collision without fabricating an impact.

Keep player input and physics responsive independent of terrain simulation commits. Camera movement follows descent and uses `DescendingCameraModel` for slow upward recovery to a two-hex margin when the player leaves the top of the screen.
