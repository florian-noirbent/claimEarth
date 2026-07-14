# Player

`src/player` owns movement, grapple, camera models, and environment status. `PlayerController` coordinates runtime sampling and consumes grid-backed terrain motion from `src/world`; pure models hold movement, grapple, and camera rules for focused tests.

Tuning lives in resources under `config/player/`. `WorldGrappleAnchorQuery` is the boundary from grapple logic into terrain, terrain motion and unstuck results provide typed velocity changes for the accumulating impact hazard, and hazard sampling asks terrain hazard behavior for fill-aware effects. Terrain unstucking targets only Air centers where the full player circle fits and re-evaluates that target each physics frame until clear. The greatest qualifying impact per physics frame adds its excess above the configured safe speed to the shared hazard-status model; accumulated knockout/death classification remains player-owned. Fill-weighted viscosity is sampled from packed terrain metadata after movement and grapple acceleration, then exponentially damps full velocity before collision without fabricating an impact.

Keep player input and physics responsive independent of terrain simulation commits. Camera movement remains downward-only through `DescendingCameraModel`.
