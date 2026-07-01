# Player

`src/player` owns movement, grapple, camera models, and environment status. `PlayerController` coordinates runtime sampling and consumes grid-backed terrain motion from `src/world`; pure models hold movement, grapple, and camera rules for focused tests.

Tuning lives in resources under `config/player/`. `WorldGrappleAnchorQuery` is the boundary from grapple logic into terrain, and hazard sampling asks terrain hazard behavior for fill-aware effects.

Keep player input and physics responsive independent of terrain simulation commits. Camera movement remains downward-only through `DescendingCameraModel`.
