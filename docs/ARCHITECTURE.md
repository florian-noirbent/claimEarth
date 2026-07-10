# Claim Earth - Architecture Guide

This document explains the implemented system and how to extend it. It is not a
historical build plan.

## Runtime Constraints

- Godot 4.6.3 with typed GDScript and the Compatibility renderer.
- Single-threaded Web export is the required baseline.
- No C# runtime, GDExtension, or required compute/thread support.
- Terrain is a fixed packed grid; scene nodes exist only for active gameplay and
  bounded world presentation.

## Repository Map

```text
config/                 Tunable Resource definitions and catalogs
scenes/app/main.tscn    Persistent application shell
scenes/app/run_session.tscn Disposable gameplay/preview composition
scenes/player/          Player scene
scenes/ui/              Reusable editor-authored UI components
src/app/                Run state and four top-level controllers
src/generation/         Deterministic generation passes
src/items/              Definitions, actions, projectiles, explosions
src/leaderboard/        Service contract, fake, SimpleBoards adapter
src/player/             Movement, grapple, hazards, camera
src/presentation/       Chunk rendering, markers, effects
src/simulation/         Replaceable terrain simulation backend
src/terrain/            Terrain definitions and behavior strategies
src/world/              Packed grid and hex coordinate types
tests/                  Contracts, unit, integration, performance
tools/                  Import, test, export, and browser scripts
```

## Runtime Composition

`scenes/app/main.tscn` composes the persistent application shell. `AppRoot` owns
`RunCoordinator`, UI, audio, scores, leaderboard workflows, and the active disposable
`RunSession`. Starting or restarting frees the previous session before instantiating
a fresh `scenes/app/run_session.tscn`; returning to the menu disposes active gameplay
and shows static menu art by default. This guarantees that players, projectiles, world data,
simulation state, and inventory never cross run boundaries.

Application responsibilities are split between the persistent shell and the active
disposable session:

| Owner | Component | Owns |
| --- | --- | --- |
| `AppRoot` | `AppUiController` | Persistent menu, HUD, pause, name entry, results, leaderboard rendering |
| `AppRoot` | `ScoreController` | Saves, player profile, personal/global bests, leaderboard service |
| `RunSession` | `RunWorldController` | Registries, generation, player lifetime, simulation, bounds, presenter |
| `RunSession` | `RunItemController` | Inventory, selection, projectiles, explosions, flag flight |

Controllers receive dependencies through typed `configure(...)` methods. They do not
reach into one another. UI emits intent; gameplay controllers emit outcomes;
`AppRoot` maps both to `RunPhase` transitions.

Discrete item selection and throwing use unhandled input events routed by `AppRoot`
to the active session. GUI-consumed mouse clicks therefore cannot trigger gameplay.
Continuous movement and grapple state remain polled by the active player.

## Run State

`RunCoordinator` starts at `MAIN_MENU` and transitions through `GENERATING`,
`PLAYING`, `FLAG_IN_FLIGHT`, `NAME_ENTRY`, `SUBMITTING`, `DEATH`, `RESULT`,
`PAUSED`, and `LEADERBOARD`.

`AppRoot` holds the terminal-outcome lock. The first death, planted flag, or destroyed
flag wins; later competing outcomes are ignored. Keep score persistence in
`ScoreController`, not item or player code.

`GENERATING` creates a new run session and resets inventory from item resources.
`MAIN_MENU` disposes the active gameplay session. The legacy generated menu preview
path remains opt-in for tests and development, and previews use their own fresh
session when enabled. Generation tasks must tolerate their host session being
cancelled and freed.

## World Data And Presentation

`WorldGrid` owns the packed terrain state as one RGBA8 cell buffer plus an
`ImageTexture` mirror:

- `R`: terrain stable ID.
- `G`: 0-255 fill amount.
- `B`: lighting/reserved byte.
- `A`: flags/reserved byte.

CPU gameplay reads the packed RAM buffer through `WorldGrid` accessors. At runtime,
rendering samples the backend's final GPU simulation texture directly; the packed
`WorldGrid` texture remains the CPU snapshot mirror for gameplay writes, previews,
and reset state.

`WorldDimensions` owns rectangular indexing. `HexCoord` and `HexMetrics` own grid and
world-space conversion. Terrain byte IDs resolve through `TerrainRegistry`.

`WorldBackground` draws the run backdrop behind terrain: a sky gradient above depth
0, a tiled grass transition band on the surface edge, and a shader-graded tiled cave
texture below it. Terrain visual styles provide shader colors, and terrain
materials with fill textures are packed into a material-index atlas for shader
sampling. Edge resources are retained as assets/resources but are not part of the
current terrain renderer.

`WorldPresenter` draws one shader-driven world quad. The fragment shader converts
pixels to hex grid coordinates, samples the `WorldGrid` RGBA8 terrain texture,
samples terrain style/material data, and draws the matching terrain color or atlas
texture. Terrain edge outlines are shader-rendered from resource style data;
neighbor blending is intentionally deferred.

Terrain collision is gameplay-side grid physics, not presentation. `TerrainCollisionQuery`
reads committed `WorldGrid` cells and `CompiledTerrainData` solidity/fill tables,
then tests circular bodies against nearby solid hex polygons from `HexMetrics`.
`TerrainBodyMotionSolver` resolves circular body movement, floor support, and
step-up behavior without creating physics-server shapes or chunk collider nodes.

Gameplay mutations update `WorldGrid`'s packed CPU buffer directly through focused
services such as `ExplosionService`, then publish a `TerrainChangeSet`. Change sets
contain exact changed cells and their dirty rectangle, refresh the terrain texture,
and cancel any unfinished simulation tick so mixed pre-mutation and post-mutation
passes cannot overwrite authoritative gameplay writes.

## Terrain And Simulation

`TerrainDefinition` resources contain identity, block density,
collision/passability, visual style, hookability, and strategy resources for motion,
hazards, and blast response. The catalog is `config/terrain/catalog.tres`.

Call sites must not branch on terrain ID, display name, script class, or resource
path. Add behavior through the existing strategy/resource boundary. The simulation
backend may compile registry data into IDs for its hot loop.

`TerrainSimulationBackend` defines initialization, advancement, commit, region
read, render attachment, active texture access, mutation notification, and shutdown.
`RenderTextureSimulationBackend` is the implemented backend. `RunWorldController`
advances at most one CA pass per gameplay frame while playing.

The backend compiles resource definitions into packed ID-indexed motion,
directional transfer, block density, fill-sensitive solidity, passability, and
color tables. One logical simulation tick is six pairwise CA passes over the full
world: the three even connection pairs, then the three odd pairs. The backend
retains the GPU result after the even phase in alternating render targets alongside
the final odd-phase texture, so the next tick cannot overwrite a displayed trail.
`WorldPresenter` renders final terrain only, consulting the even texture solely to
draw verified vertical liquid trails through final-air cells. Pairwise resolution preserves material/fill unless an explicit rule applies, such as
liquid contact or gameplay mutation. Commits contain exact changed cells and fill
changes for the completed six-pass tick.

Gameplay writes are authoritative. External `TerrainChangeSet`s cancel any
unfinished six-pass tick, upload the patched packed world texture, and restart
simulation from that known state. This keeps player physics and item effects
independent from the visual simulation cadence while preventing simulation races
with explosions or digging.

Threaded and compute backends are not implemented. A future threaded backend must
reuse the plain simulation/build inputs and outputs, keep scene-tree and resource
application on the main thread, and remain optional for the single-thread Web build.

## Generation

`WorldGenerator` iterates the ordered `GenerationProfile.passes` stack. Each pass is
a resource instance with its own enable state, parameters, depth-range blend, and
target-replacement whitelist. The default profile ships base noise, three typed
hazard pocket instances for sand/water/lava, a noisy surface spawn shaft, and boundary seal
behaviors, but the stack may be reordered, duplicated, or selectively disabled
without code changes.

`WorldGenerationTask` yields between dynamic progress labels derived from the active
pass stack, then executes generation once for the requested seed. Generation
invariants such as spawn air, bottom sealing, air ratio, and valid registered IDs
are enforced by deterministic tests rather than a runtime validation pass. The
active defaults live in `config/generation/default_profile.tres`.

The editor-side tuning surface lives in
`addons/claim_earth_generation_tools/`. It previews static generated terrain through
the same `WorldGenerator` and `WorldPresenter` path used at runtime, but does not
spawn the player, items, or terrain simulation.

Generation changes must retain deterministic hashes, valid registered terrain IDs,
spawn air, the bottom two stone rows, and distribution tests. Horizontal player
bounds are invisible runtime constraints; generation does not create stone side
walls.

## Player, Camera, And Items

`PlayerController` is a `CharacterBody2D` node coordinating `PlayerMovementModel`,
`GrappleModel`, environment sampling, grid-backed terrain motion, and horizontal
clamping. It does not use Godot terrain colliders for movement; terrain collision
is delegated to the world-level query and motion solver. Movement and grapple
tuning are resources under `config/player/`.

`DescendingCameraController` is horizontally locked by `RunWorldController`, zoomed
to map width, and uses `DescendingCameraModel` for downward-only vertical movement.

Items are registered through `config/items/catalog.tres`. `ItemDefinition` points to
an `ItemActionFactory`; factories create polymorphic `ItemAction` implementations.
`RunItemController` treats all selected items through that contract. `ItemProjectile`
owns flight, terrain sampling, bounce, fuse, and resolution signals.

`ExplosionService` traverses hexes, asks each terrain blast strategy for its effect,
updates committed cells, and marks the resulting dirty rectangle. The lethal radius
always vaporizes terrain and is also checked against the player.

## Persistence And Leaderboard

`SaveRepository` stores JSON under `user://` with last player name, personal best,
and pending submissions. Missing or corrupt data falls back to defaults.

`LeaderboardService` is the dependency boundary. Production uses
`SimpleBoardsLeaderboardService`; tests and offline scenarios use
`FakeLeaderboardService`. Response parsing is isolated in
`SimpleBoardsResponseParser`.

The Web client API key is public by nature. Do not log it unnecessarily, but do not
model it as a server secret. Never use the live service from automated tests.

## Common Feature Recipes

### Add Terrain

1. Create/reuse motion, hazard, blast, and visual resources.
2. Create the `TerrainDefinition` resource with a unique stable ID.
3. Add it to `config/terrain/catalog.tres`.
4. Extend simulation behavior only through strategy/registry compilation.
5. Add registry, rule, generation, and rendering tests as applicable.

### Add An Item

1. Add an action factory and action implementing the common contracts.
2. Add definition/factory `.tres` files and register the definition in the catalog.
3. Keep selection, HUD inventory, and spawning generic.
4. Test inventory, projectile lifecycle, resolution, and full run-state effects.

### Add A Run Workflow Or Screen

1. Add UI nodes under `UiLayer` and presentation logic to `AppUiController`.
2. Emit a typed intent signal rather than calling gameplay directly.
3. Route it in `AppRoot`; add a `RunPhase` only when behavior truly needs a state.
4. Cover visibility, transition, repeated-entry, and cleanup behavior.

### Change Simulation Or Rendering

1. Add deterministic counters/fixtures before optimizing.
2. Keep player physics independent from terrain commit cadence.
3. Keep renderer node counts bounded and avoid per-cell scene nodes.
4. Run both fast and performance suites; use the Web milestone gate for renderer or
   export changes.

## Tests And Gates

| Change | Required minimum |
| --- | --- |
| Pure rule/resource | Relevant unit and contract tests |
| Run/UI workflow | Integration test plus fast suite |
| Generation | Fixed-seed generation tests plus fast suite |
| Simulation/rendering/collision | Fast suite and performance suite |
| Save/leaderboard | Offline fake-service tests plus fast suite |
| Export/browser/project settings | `tools/ci.ps1 -Milestone` |

Commands and environment setup are documented in `tools/README.md`. Current suites:

- `tests/contracts`: registry and architecture constraints.
- `tests/unit`: deterministic domain behavior.
- `tests/integration`: scene and complete workflow behavior.
- `tests/performance`: structural frame-loop and bounded-node contracts.

Manual testing evaluates feel, readability, balance, and browser presentation. Add a
regression test for reproducible logic defects.

## Definition Of Done

- Behavior matches `GAME_DESIGN.md`, or that document changes in the same commit.
- Ownership and extension guidance here still matches the code.
- Shipped GDScript has clean diagnostics and typed public boundaries.
- Relevant tests and required gates pass without unexpected script/engine errors.
- New tuning is resource-configured where designers are expected to iterate.
- No central terrain/item type branch or per-cell Node architecture is introduced.
