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
src/app/                Run state, preferences, input, and top-level controllers
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
| `RunSession` | `RunItemController` | Inventory, selection, item chests, projectiles, explosions, flag flight |

Controllers receive dependencies through typed `configure(...)` methods. They do not
reach into one another. UI emits intent; gameplay controllers emit outcomes;
`AppRoot` maps both to `RunPhase` transitions.

`GameplayInputController` owns device integration and produces device-neutral
continuous input frames plus typed discrete intents for the active run. It merges
keyboard/mouse, virtual touch controls, and standard gamepads; player, item, and
grapple code consume those frames/intents and must not read device APIs directly.
`AppUiController` owns touch-overlay and settings presentation and emits touch state
and user preferences only. `AppRoot` composes the input and settings controllers,
routes normalized intents to the active session, and resets held input when a run
ends, pauses, loses focus, or the overlay is hidden.

Mouse item selection and throwing remain unhandled-input workflows routed through
`AppRoot`, so GUI-consumed clicks cannot trigger gameplay. Touch gesture ownership
and emulated-mouse suppression are contained in the input/UI boundary, preventing a
single phone gesture from producing duplicate gameplay actions.

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

`REWARD_PICKER` is a mandatory modal entered from `PLAYING` or `FLAG_IN_FLIGHT`.
`AppRoot` remembers the originating phase, suspends the complete run session, routes
one UI choice back to `RunItemController`, and restores that phase after the reward
is applied. Terminal outcomes clear and supersede a pending reward.

## World Data And Presentation

`WorldGrid` owns the packed terrain state as one RGBA8 cell buffer plus an
`ImageTexture` mirror:

- `R`: primary terrain ID in the low 4 bits and secondary terrain ID in the high
  4 bits.
- `G`: primary quantity from 0-255.
- `B`: committed lighting.
- `A`: secondary quantity from 0-255.

The primary component is the denser visible/gameplay material. The optional
secondary component is an invisible simulation work buffer for displaced lighter
material. Quantity 127 is visual fullness and 128-255 is overpressure. External
gameplay writes replace the primary component and clear the secondary component.

New grids initialize the `B` byte to darkness. The simulation backend lights only
the surface row during initialization, then owns lighting updates in that byte. It preserves light by
map location as terrain moves, injects terrain-defined emitters, a shared R8 texture
of non-terrain emitters, and the current player source. Reusable
`WorldLightSource2D` children translate their global position to a hex, register or
move one emitter, and unregister when disabled or removed. Standard mode updates
chests and ordinary objects on the normal terrain-light tick. High-frequency mode owns the single
local source evaluated on every CA pass within its configured radius. Item chests
own a standard component that follows their falling body and disable it when removed;
the player owns the high-frequency component. Other cells update only on the sixth
pass. Moving a standard emitter updates its source-texture cells without cancelling
an in-flight simulation pass. The render backend also retries a request when repeated
simulation advances observe that its frame-drawn callback never completed, preventing
a lost callback from permanently freezing the run. Values at the presentation-config exploration
threshold are retained as fog-of-war state. The terrain shader converts the byte to
black, graded, and full-brightness output.

CPU gameplay reads the packed RAM buffer through `WorldGrid` accessors. At runtime,
rendering samples the backend's final GPU simulation texture directly; the packed
`WorldGrid` texture remains the CPU snapshot mirror for gameplay writes, previews,
and reset state.

`WorldDimensions` owns rectangular indexing. `HexCoord` and `HexMetrics` own grid and
world-space conversion. Terrain byte IDs resolve through `TerrainRegistry`.

`WorldPresentationConfig` owns shared visual tuning for playable runs and the static
World Gen preview: terrain/fluid shader controls plus the sky, grass, and cave
backdrop. `WorldBackground` draws that backdrop behind terrain. Editing the shared
resource refreshes active renderer parameters without regenerating the world.
Static menu and editor previews force full brightness in `WorldPresenter` without
rewriting the generated grid's lighting bytes.
Terrain visual styles provide shader colors, and terrain materials with fill
textures are packed into a material-index atlas for shader sampling. Edge resources
are retained as assets/resources but are not part of the current terrain renderer.

`WorldPresenter` draws one shader-driven world quad. The fragment shader converts
pixels to hex grid coordinates, samples the `WorldGrid` RGBA8 terrain texture,
samples terrain style/material data, and draws the matching terrain color or atlas
texture. Terrain edge outlines and mixed-material boundaries are shader-rendered
from resource style data. The shader is split into includes for maintainable source
ownership but still compiles as one material and one draw call. See
[`TERRAIN_RENDERING.md`](TERRAIN_RENDERING.md) for its data flow, canonical hex
direction order, and performance benchmark contract.

Terrain collision is gameplay-side grid physics, not presentation. `TerrainCollisionQuery`
reads committed `WorldGrid` cells and `CompiledTerrainData` solidity/fill tables,
then tests circular and convex-polygon bodies against nearby solid hex polygons from
`HexMetrics`. Its shape-aware Air queries accept only destinations where the complete
body is clear. They search by canonical hex distance, then break equal-ring ties by
world distance, upward position, and left position.
`TerrainBodyMotionSolver` resolves circular body movement, floor support, and
step-up behavior without creating physics-server shapes or chunk collider nodes. Its
motion result reports the complete collision-caused velocity change. Floor probing
supplements an already grounded body crossing uneven terrain and never grounds a
descending body before real contact.

Gameplay mutations update `WorldGrid`'s packed CPU buffer directly through focused
services such as `ExplosionService`, then publish a `TerrainChangeSet`. Change sets
contain exact changed cells and their dirty rectangle, refresh the terrain texture,
and cancel any unfinished simulation tick so mixed pre-mutation and post-mutation
passes cannot overwrite authoritative gameplay writes.

## Terrain And Simulation

`TerrainDefinition` resources contain identity, block density,
collision/passability, visual style, hookability, and strategy resources for motion,
hazards, and blast response. The catalog is `config/terrain/catalog.tres`.
Motion resources also provide a non-negative per-second viscosity coefficient. This
player-drag value is independent of the cellular-automata transfer rates that tune
how the terrain itself flows.

Call sites must not branch on terrain ID, display name, script class, or resource
path. Add behavior through the existing strategy/resource boundary. The simulation
backend may compile registry data into IDs for its hot loop.

`EnvironmentStatus` owns generic player hazard meters. Terrain hazard behaviors
resolve fill-aware meter definitions, including their icon, color, fill/recovery
durations, terrain-fill rate curve, and display order; the player samples those definitions at occupied body
hexes and forwards meter snapshots through the run controllers to `AppUiController`.
Suffocation is the one environment-wide rule: the head must resolve to empty Air,
walking upward through partial cells before evaluating the next full cell. The HUD is
generic and never branches on a hazard cause. New terrain hazards therefore add a
behavior resource and authored icon rather than UI logic.

`TerrainSimulationBackend` defines initialization, advancement, commit, region
read, render attachment, active texture access, mutation notification, and shutdown.
`RenderTextureSimulationBackend` is the implemented backend. `RunWorldController`
owns a real-time accumulator that accrues 60 CA passes per active gameplay second.
It schedules only whole due passes, deducts only work accepted by the backend, and
retains fractional or excess debt. Frames above 60 FPS can skip simulation; slower
frames can submit up to the six remaining passes of the current tick as one ordered
batch. Pausing, leaving a run, or losing application focus resets the accumulator so
background time is never replayed. Each render target uses `UPDATE_ONCE`, then the
batch completes through one post-draw callback after Godot's normal viewport render
phase; simulation never forces a global viewport redraw.

The backend compiles resource definitions into packed ID-indexed motion,
directional transfer, block density, quantity-sensitive solidity, passability, and
color tables. One logical simulation tick is six pairwise CA passes over the full
world: the three even connection pairs, then the three odd pairs. Two alternating
banks each contain one `SubViewport` per logical pass. A batch chains each slot from
the previous slot, preserving the same dependency order as one-pass frames without
crossing a tick boundary. The backend retains the GPU result after the even phase
alongside the final odd-phase texture, and alternating banks ensure the next tick
cannot overwrite a displayed trail.
`WorldPresenter` renders final terrain only, consulting the even texture solely to
draw verified vertical moving-terrain trails through final-air cells. Liquids keep
their fluid appearance while falling sand uses its solid material. Presenter and
simulation shaders share only canonical hex topology helpers; pair ownership and
cellular-automata resolution remain simulation-specific. Each pair normalizes its
two-component outputs by removing empty components, merging matching material,
promoting a remaining secondary, and ordering different material by density.
Secondary material first moves into compatible or partial neighbors. When trapped,
it pressure-balances pairwise into full same-material neighbors up to the packed
255 ceiling. This replaces whole-cell density swaps and preserves lighter liquids
under falling or landsliding Sand. Pairwise resolution conserves component
quantities unless an explicit rule applies, such as liquid contact or gameplay
mutation. The simulation supplies a virtual solid cell for pair neighbors below the
map, preventing moving terrain from leaking through the bottom edge without
requiring a generated solid row. A completed six-pass tick publishes only a
revisioned snapshot commit; the backend does not copy or diff every cell on the CPU.
Exact `TerrainChangeSet`s remain reserved for bounded gameplay mutations whose
affected cells are already known.

Gameplay writes are authoritative. External `TerrainChangeSet`s cancel any
unfinished six-pass tick, upload the patched packed world texture, and restart
simulation from that known state. This keeps player physics and item effects
independent from the visual simulation cadence while preventing simulation races
with explosions or digging.

The shipped backend is GPU render-texture only; headless tests do not emulate terrain
motion. Threaded and compute backends are not implemented. A future threaded backend must
reuse the plain simulation/build inputs and outputs, keep scene-tree and resource
application on the main thread, and remain optional for the single-thread Web build.

## Generation

`WorldGenerator` iterates the ordered `GenerationProfile.passes` stack. Each pass is
a resource instance with its own enable state, parameters, independent top/bottom
depth-range blends, and target-replacement whitelist. The default profile ships base
noise, three typed hazard pocket instances for sand/water/lava, a noisy surface spawn
shaft, and a bottom lava fill, but the stack may be reordered, duplicated, or
selectively disabled without code changes.

`WorldGenerationTask` yields between dynamic progress labels derived from the active
pass stack, then executes generation once for the requested seed. Generation
invariants such as spawn air, the bottom lava fill, air ratio, and valid registered IDs
are enforced by deterministic tests rather than a runtime validation pass. The
active defaults live in `config/generation/default_profile.tres`.

The generic Fill pass exposes its output terrain through the World Gen editor. It
converts the normalized depth band to a half-open row range before writing cells, so
a narrow band visits only its selected rows rather than scanning the complete map.

Generation context/results also carry typed `GeneratedItemChestSpawn` records. The
generic generated-item pass partitions its configured depth band into deterministic
jittered areas, asks one `GeneratedItemPlacementDefinition` to prepare terrain and
record a typed spawn, and never scans or shuffles the full map. Columns, area height,
column stagger, and per-area chance are resource-driven. Exact anchors are reserved
across item passes, but no minimum separation is imposed. `ItemChestDefinition` is
the first placement definition: it carves Air at and above the anchor while preserving
the previously generated terrain below and records the per-chest reward seed. Playable
sessions hand those records to `RunItemController`; the World Gen preview instantiates
the same chest scene with interaction disabled. Add another generated-item kind by
implementing the placement-definition hooks and configuring another pass instance;
the grid sampler must remain type-agnostic.

The editor-side tuning surface lives in
`addons/claim_earth_generation_tools/`. It previews static generated terrain through
the same `WorldGenerator` and `WorldPresenter` path used at runtime. It also displays
generated chest visuals without interaction, but does not spawn the player,
projectiles, or terrain simulation.

Generation changes must retain deterministic hashes, valid registered terrain IDs,
spawn air, the default bottom lava band, and distribution tests. Horizontal player
bounds are invisible runtime constraints; generation does not create stone side
walls.

## Player, Camera, And Items

`PlayerController` is a `CharacterBody2D` node coordinating `PlayerMovementModel`,
`GrappleModel`, environment sampling, grid-backed terrain motion, and horizontal
clamping. It does not use Godot terrain colliders for movement; terrain collision
is delegated to the world-level query and motion solver. It combines velocity changes
reported by ordinary motion, post-grapple correction, and terrain unsticking once per
physics frame. The greatest qualifying change adds its hazardous excess to a
player-owned `EnvironmentStatus` meter; that generic status model also handles
resource-tuned recovery and presentation snapshots. Accumulated level is classified
against the movement-resource knockout and lethal thresholds, so one large impact
retains its result while nearby smaller impacts compound. `PlayerController` owns the
timed uncontrolled tumble and emits lethal impact outcomes. Movement, impact, and
grapple tuning are resources under `config/player/`.

After movement and grapple acceleration, `PlayerController` averages fill-weighted
viscosity across its three occupied-body samples and applies exponential damping to
the complete velocity before terrain collision. `CompiledTerrainData` stores the
coefficient in a packed float table, and `TerrainCollisionQuery` combines it with
committed cell fill. The damping is frame-rate independent and is not reported as a
collision velocity change, though its reduced incoming speed can lower a later impact.

`HazardStatus` snapshots may expose a generic secondary threshold and lethal endpoint.
The reusable hazard row renders those markers without knowing that the impact meter's
secondary threshold represents knockout.

`TerrainBodyUnstuckSolver` owns the shared full-body-clearance escape rule used by
the player's circle and the chest's rectangular footprint. It re-queries the target
on each physics frame and applies the configured push speed only while the body
overlaps terrain; if no fitting Air destination is in range, it leaves the body
unchanged. Its typed result reports position, velocity, and the velocity change caused
by escape without knowing about player damage. `PlayerController` consumes that fact for impact rules;
`ItemChest` ignores it and uses a separate swept-rectangle fall path that changes
only vertical velocity, stops without restitution, and derives a snapped visual tilt
from left/right terrain support.

`DescendingCameraController` is horizontally locked by `RunWorldController`, zoomed
to map width, and uses `DescendingCameraModel` for downward-only vertical movement.

Items are registered through `config/items/catalog.tres`. `ItemDefinition` points to
an `ItemActionFactory`; factories create polymorphic `ItemAction` implementations.
`RunItemController` treats all selected items through that contract. `WorldRigidBody2D`
owns terrain sampling, gravity, collision response, and blast-pulse reception for dynamic item bodies.
`ItemProjectile` composes that body with item resolution, bounce, fuse, and temporary flare light;
autonomous objects such as the excavator use the same body directly. The renderer reserves high-frequency light slots for the player and the
most recently thrown flare; older flares remain visible without displacing the player.
Immediate item actions resolve one aimed neighboring hex and publish their
terrain changes through `RunItemController`; float tool charges allow a final
undercharged valid hit. Item status retains catalog indices while hiding empty
dynamic slots so toolbar clicks and keyboard shortcuts stay stable.

Item chest rewards use `ItemChestDefinition` and weighted `ItemChestOption` resources.
Selection is deterministic and without replacement. `RunItemController` owns active
chest nodes, pending item choices, and inventory application, while
`AppUiController` receives generic `RewardChoiceViewData` cards so a future perk
owner can reuse the picker without item-specific UI branches. Session activation is
also propagated to projectiles, chest physics and monitoring, and explosive chain
timers so pause and modal phases freeze all active item workflows.

`ExplosionService` traverses hexes, asks each terrain blast strategy for its effect,
updates committed cells, and returns an `ExplosionResult` containing the terrain
change set plus the inclusive lethal-core cells. The lethal radius always vaporizes
terrain and is also checked against the player. Bombs and chests compose
`WorldExplosive2D` with separate validated `ExplosionDefinition` resources.
`RunItemController` registers those components generically; lethal-cell footprint
overlap arms a one-shot delayed chain without branches on the host item type.
Explosion definitions also tune radial impulse strength. `RunItemController` applies
that impulse through `WorldRigidBody2D`, so bombs, flags, excavators, and future dynamic
items share the behavior without selection branches. A future jelly perk can expose
the same receiver behavior from its player-owned perk boundary.

## Persistence And Leaderboard

`SaveRepository` stores JSON under `user://` with last player name, personal best,
and pending submissions. Missing or corrupt data falls back to defaults.

`AppSettingsController` persists user preferences independently of scores and
leaderboard data. Phone controls default from the `mobile`, `web_android`, and
`web_ios` feature tags; only an explicit Settings-screen choice is persisted and it
overrides automatic detection. Missing or corrupt settings fall back to that automatic
default. The discrete frame-limit preference accepts only 30, 60, 90, 120, or zero
for Unlimited, defaulting to 30 on the same mobile targets and Unlimited elsewhere.
`AppRoot` applies it immediately through `Engine.max_fps`; it does not alter the
fixed-rate terrain clock. These preferences remain independent and keep device
policy out of gameplay ownership.

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

To add an item to chest rewards, add an `ItemChestOption` to the chest definition
resource with its quantity and relative selection weight. No picker or controller
branch is required.

### Add A Run Workflow Or Screen

1. Add UI nodes under `UiLayer` and presentation logic to `AppUiController`.
2. Emit a typed intent signal rather than calling gameplay directly.
3. Route it in `AppRoot`; add a `RunPhase` only when behavior truly needs a state.
4. Cover visibility, transition, repeated-entry, and cleanup behavior.

### Add Or Change Input

1. Extend `GameplayInputController` frames/intents rather than reading `Input` from
   gameplay controllers.
2. Keep platform-specific detection, touch gestures, gamepad mapping, and input
   arbitration at the input/UI boundary.
3. Keep persistent preferences in `AppSettingsController`; UI emits the requested
   value and `AppRoot` applies it.
4. Test device-source merging and edge transitions independently from player/item
   behavior, then cover a complete input workflow in integration tests.

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
| Input/touch/gamepad/settings | Input unit/contract tests, run/UI integration tests, plus fast suite |
| Export/browser/project settings | `tools/ci.ps1 -Milestone` |

Commands and environment setup are documented in `tools/README.md`. Current suites:

- `tests/contracts`: registry and architecture constraints.
- `tests/unit`: deterministic domain behavior.
- `tests/integration`: scene and complete workflow behavior.
- `tests/performance`: structural frame-loop and bounded-node contracts.

Manual testing evaluates feel, readability, balance, and browser presentation. For
phone input, verify a fullscreen landscape Web export on Android Chromium and iOS
Safari (or another available iOS browser): simultaneous sticks/ring use, gesture
cancellation, safe spacing around the HUD, and phone-control auto-detection and
override. For gamepads, verify activation after the browser's first controller button
press and the documented standard mapping. Add a regression test for reproducible
logic defects.

## Definition Of Done

- Behavior matches `GAME_DESIGN.md`, or that document changes in the same commit.
- Ownership and extension guidance here still matches the code.
- Shipped GDScript has clean diagnostics and typed public boundaries.
- Relevant tests and required gates pass without unexpected script/engine errors.
- New tuning is resource-configured where designers are expected to iterate.
- No central terrain/item type branch or per-cell Node architecture is introduced.
