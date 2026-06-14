# Claim Earth - Architecture Guide

This document explains the implemented system and how to extend it. It is not a
historical build plan.

## Runtime Constraints

- Godot 4.6.3 with typed GDScript and the Compatibility renderer.
- Single-threaded Web export is the required baseline.
- No C# runtime, GDExtension, or required compute/thread support.
- Terrain is a fixed packed grid; scene nodes exist only for active gameplay and
  visible chunks.

## Repository Map

```text
config/                 Tunable Resource definitions and catalogs
scenes/app/main.tscn    Main composition scene
scenes/player/          Player scene
src/app/                Run state and four top-level controllers
src/generation/         Deterministic generation passes
src/items/              Definitions, actions, projectiles, explosions
src/leaderboard/        Service contract, fake, SimpleBoards adapter
src/player/             Movement, grapple, hazards, camera
src/presentation/       Chunk rendering/collision, markers, effects
src/simulation/         Replaceable terrain simulation backend
src/terrain/            Terrain definitions and behavior strategies
src/world/              Packed grid and hex coordinate types
tests/                  Contracts, unit, integration, performance
tools/                  Import, test, export, and browser scripts
```

## Runtime Composition

`scenes/app/main.tscn` composes the application. `AppRoot` owns `RunCoordinator`,
routes typed signals, arbitrates terminal outcomes, and exposes a small test facade.
It delegates implementation details to four child controllers:

| Controller | Owns |
| --- | --- |
| `AppUiController` | Menu, HUD, pause, name entry, results, leaderboard rendering |
| `RunWorldController` | Registries, generation, player lifetime, simulation, bounds, presenter |
| `RunItemController` | Inventory, selection, projectiles, explosions, flag flight |
| `ScoreController` | Saves, player profile, personal/global bests, leaderboard service |

Controllers receive dependencies through typed `configure(...)` methods. They do not
reach into one another. UI emits intent; gameplay controllers emit outcomes;
`AppRoot` maps both to `RunPhase` transitions.

## Run State

`RunCoordinator` starts at `MAIN_MENU` and transitions through `GENERATING`,
`PLAYING`, `FLAG_IN_FLIGHT`, `NAME_ENTRY`, `SUBMITTING`, `DEATH`, `RESULT`,
`PAUSED`, and `LEADERBOARD`.

`AppRoot` holds the terminal-outcome lock. The first death, planted flag, or destroyed
flag wins; later competing outcomes are ignored. Keep score persistence in
`ScoreController`, not item or player code.

## World Data And Presentation

`WorldGrid` owns two `PackedByteArray` buffers:

- `committed_cells`: authoritative state read by gameplay and presentation.
- `working_cells`: candidate state produced by terrain simulation.

`WorldDimensions` owns rectangular indexing. `HexCoord` and `HexMetrics` own grid and
world-space conversion. Terrain byte IDs resolve through `TerrainRegistry`.

`ChunkActivityIndex` uses 20x32-cell chunks by default. It tracks dirty chunks and
computes the depth window used by simulation and presentation.

`WorldPresenter` creates one `WorldChunkRenderer` and one `WorldChunkCollision` per
visible chunk. It rebuilds newly visible or dirty chunks and frees chunks leaving the
window. Renderers and colliders consume `WorldGrid`; they never mutate it.

Gameplay mutations currently update committed cells directly through focused
services such as `ExplosionService`, then mark the affected rectangle dirty. There
is no general `WorldMutationService`; add one only if multiple mutation paths gain
meaningfully duplicated synchronization rules.

## Terrain And Simulation

`TerrainDefinition` resources contain identity, collision/passability, visual style,
hookability, and strategy resources for motion, hazards, and blast response. The
catalog is `config/terrain/catalog.tres`.

Call sites must not branch on terrain ID, display name, script class, or resource
path. Add behavior through the existing strategy/resource boundary. The simulation
backend may compile registry data into IDs for its hot loop.

`TerrainSimulationBackend` defines initialization, scheduling, advancement, commit,
region read, and shutdown. `CooperativeChunkBackend` is the implemented backend.
`RunWorldController` schedules chunks around the player's visible depth window and
invokes a simulation step at the configured 0.5-second cadence.

The cooperative backend resets working state from committed state, applies queued
changes, performs one deterministic terrain tick, and commits only when working and
committed buffers differ. This equality check prevents false perpetual commits after
fluid/sand activity settles.

Do not describe time-budget slicing, sleeping chunks, pair registries, threaded
backends, or compute backends as implemented. They are possible future work and must
remain behind `TerrainSimulationBackend` if introduced.

## Generation

`WorldGenerator` runs these passes in order:

1. `BaseNoisePass`
2. `PocketNoisePass`
3. `ShowcasePocketPass`
4. `SpawnChamberPass`
5. `BoundarySealPass`
6. `GenerationValidationPass`

`WorldGenerationTask` yields between progress labels, then executes generation.
Rejected maps retry with deterministically derived seeds. The active defaults live in
`config/generation/default_profile.tres`, not the script's fallback values.

Generation changes must retain deterministic hashes, valid registered terrain IDs,
spawn air, the bottom two stone rows, and distribution tests. Horizontal player
bounds are invisible runtime constraints; generation does not create stone side
walls.

## Player, Camera, And Items

`PlayerController` is a `CharacterBody2D` coordinating `PlayerMovementModel`,
`GrappleModel`, environment sampling, step-up behavior, and horizontal clamping.
Movement and grapple tuning are resources under `config/player/`.

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
3. Dirty only affected chunks and keep renderer/collider node counts bounded.
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
