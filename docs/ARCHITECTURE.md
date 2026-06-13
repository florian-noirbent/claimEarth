# Claim Earth - Technical Architecture

## 1. Constraints and Decisions

- Engine: Godot 4.6.
- Language: typed GDScript. The .NET editor may be used; no C# runtime code is
  shipped because Godot 4.6 cannot export C# projects to Web.
- Release: itch.io HTML5, modern desktop Chromium and Firefox.
- Renderer: Compatibility/WebGL 2. Godot Web does not expose the Forward+/Mobile
  `RenderingDevice` compute path because WebGL 2 has no compute shaders.
- Default export: single-threaded for maximum itch.io/browser compatibility.
- Simulation cadence: committed terrain updates every 0.5 seconds, with immediate
  local handling for explosions and player hazards.
- Architecture must allow a threaded or future WebGPU backend without changing
  gameplay systems.

## 2. Project Layout

```text
res://
  addons/gut/                 # Pinned GUT 9.6 test framework
  assets/
    audio/
    fonts/
    vector/
  config/
    generation/
    items/
    player/
    terrain/
    visual/
  scenes/
    app/
    gameplay/
    items/
    player/
    ui/
  shaders/
  src/
    app/
    audio/
    core/
    generation/
    items/
    leaderboard/
    player/
    presentation/
    simulation/
    terrain/
    world/
  tests/
    integration/
    performance/
    unit/
  docs/
```

Dependencies point inward: presentation and Godot scenes depend on domain services;
domain services do not depend on UI scenes. Resources contain configuration and
behavior strategy references, not global mutable run state.

## 3. Runtime Composition

`AppRoot` is the composition root and the only place allowed to choose concrete
implementations. It creates and injects:

- `RunCoordinator`
- `WorldGenerator`
- `TerrainRegistry`
- `ItemFactory`
- `TerrainSimulationBackend`
- `WorldMutationService`
- `SaveRepository`
- `LeaderboardService`
- presentation adapters and scene factories

Use Godot signals for observable events crossing scene ownership boundaries. Use
direct typed method calls within one subsystem. Avoid a global event bus.

Only stable cross-scene services may be autoloads: `App`, `SaveRepository`, and
`AudioDirector`. Run-specific state belongs under the current gameplay scene.

## 4. Run State Machine

`RunCoordinator` owns explicit states:

```text
MAIN_MENU -> GENERATING -> PLAYING -> FLAG_IN_FLIGHT -> NAME_ENTRY
                                      |                    |
                                      v                    v
                                    DEATH              SUBMITTING
                                      |                    |
                                      +------> RESULT <----+
                                                   |
                                                   v
                                              GENERATING
```

Each state controls allowed commands and scene/UI visibility. State transitions are
idempotent. Death and flag resolution race through one `RunOutcomeGate`; the first
valid terminal outcome wins, preventing score-after-death and duplicate submission.

## 5. World Model

### Coordinates and storage

`HexCoord` is an immutable value object with conversion, neighbor, distance, and
world-position functions. It is the sole owner of hex math.

`WorldGrid` stores terrain definition IDs in two `PackedByteArray` buffers:

- `committed_cells`: state consumed by rendering, collision, and general queries.
- `working_cells`: state being calculated for the next simulation commit.

Index formula and bounds checks are centralized in `WorldDimensions`. A byte ID is
resolved through `TerrainRegistry`; IDs are stable within a build and validated at
startup. Dynamic per-cell flags such as awake/dirty are separate packed bitsets so
terrain IDs stay compact.

At 100 by 2000, each byte buffer is about 200 KB. Full-map storage is cheap; scene
nodes and collision objects are created only near the camera.

### Chunks

- Default chunk size: 20 columns by 32 rows, configurable.
- `ChunkActivityIndex` tracks awake, dirty-render, dirty-collision, and scheduled
  chunks.
- A terrain mutation wakes its chunk and all neighbor chunks touched by the rule.
- A chunk sleeps after configurable consecutive commits with no changes.
- The active band includes camera-visible chunks, one render margin, player/hazard
  chunks, projectile paths, and all currently unstable cells.

`WorldMutationService` is the exclusive writer from gameplay systems. It applies
immediate mutations to the committed buffer, records dirty regions, updates nearby
collision, and queues equivalent changes into the backend's next working state.

## 6. Terrain Polymorphism

No gameplay system may branch on terrain IDs, enum values, resource paths, or names.

### Definitions

`TerrainDefinition` is a custom `Resource` containing:

- Stable ID and display name.
- Physical properties and collision policy.
- Visual material/palette configuration.
- `TerrainMotionBehavior` strategy.
- `TerrainHazardBehavior` strategy.
- `BlastReaction` strategy.
- Hookability and destructibility capabilities.

Strategies are reusable resources:

- `StableMotion`
- `FallingMotion`
- `LiquidMotion`
- `NoHazard`, `LavaHazard`, `SuffocationHazard`, `BurialHazard`
- `NoBlastReaction`, `TransformBlastReaction`, `DiffuseBlastReaction`,
  `DetonateBlastReaction`

Simulation dispatches through a precompiled behavior opcode/table derived from the
resource registry. This keeps the hot loop data-oriented while preserving
polymorphic configuration at the architecture boundary. The compiler, not gameplay
code, maps strategies to simulation operations.

### Pair interactions

`TerrainInteractionRegistry` resolves ordered source/destination behavior pairs.
Rules are resources implementing `TerrainPairInteraction`, such as solidification
and density swap. The registry uses definition IDs as lookup keys internally; no
caller contains pair-specific branches.

Startup validation fails loudly for duplicate IDs, missing strategies, invalid
transitions, or an unregistered required interaction.

## 7. Items and Explosions

`ItemDefinition` is a resource containing inventory count, projectile scene,
trajectory settings, icon, and an `ItemActionFactory`.

`ItemFactory.create(definition, context)` produces an `ItemAction`. Implementations
include bomb and flag actions, but selection and throwing code only sees the common
interface:

```gdscript
func can_use(context: ItemUseContext) -> bool
func create_projectile(context: ItemUseContext) -> Projectile
func on_resolved(result: ProjectileResult) -> void
```

`BombDefinition` supplies fuse, terrain radius, lethal radius, impulse, water
attenuation, and chain-reaction configuration. `ExplosionService` traverses cells by
hex distance, builds `BlastContext`, and calls each terrain's `BlastReaction`.

`FlagAction` reports exactly one of planted, destroyed, or invalid. The outcome gate
then transitions the run. Item code never decides score persistence directly.

Projectile trajectory calculation is a pure service shared by runtime physics,
tests, and any aiming preview.

## 8. Simulation Backends

### Contract

All implementations satisfy `TerrainSimulationBackend`:

```gdscript
func initialize(world: WorldGrid, registry: TerrainRegistry, seed: int) -> void
func queue_change(change: CellChange) -> void
func schedule(active_chunks: PackedInt32Array) -> void
func advance(time_budget_usec: int) -> SimulationProgress
func commit_if_ready() -> SimulationCommit
func read_region(region: Rect2i) -> PackedByteArray
func shutdown() -> void
```

The backend never owns player physics, scoring, rendering, or scene nodes.

### Jam backend: CooperativeChunkBackend

- Runs in the main process but uses a strict microsecond budget per frame.
- Copies only scheduled chunks plus a one-cell interaction halo into working state.
- Processes deterministic phases: queued mutations, downward movement, lateral
  liquid movement, pair interactions, then dirty/activity calculation.
- Uses intent buffers so each source and destination participates in at most one
  move per phase.
- Resolves competing intents by deterministic hash of run seed, tick, and cell.
- Alternates traversal orientation each tick to avoid persistent left/right bias.
- Atomically swaps completed chunk state into the committed buffer every 0.5 seconds.
- Carries unfinished work across frames without blocking rendering or input.

If the backend cannot finish within one cadence, it records an overrun metric,
reduces non-visible scheduling first, and never performs an unbounded catch-up loop.

### Optional backend: ThreadedChunkBackend

Implement behind the same contract only after the cooperative backend passes release
budgets. It may use `WorkerThreadPool` in native builds or web thread-enabled builds.
It operates on copied packed data and communicates only through thread-safe queues;
it never touches Nodes, Resources, RenderingServer, or PhysicsServer from workers.

Itch.io requires opt-in SharedArrayBuffer hosting for web threads. Therefore the jam
release must remain correct and playable without this backend.

### Future compute backend

A future WebGPU/native implementation may upload packed cell buffers and return dirty
regions. It must preserve contract tests and commit semantics. No other subsystem
changes when swapping backends.

## 9. Generation

`WorldGenerator` composes ordered `GenerationPass` resources:

1. `BaseNoisePass`
2. `PocketNoisePass`
3. `SpawnChamberPass`
4. `BoundarySealPass`
5. `GenerationValidationPass`

`GenerationProfile` exposes seed policy, octave count, frequencies, amplitudes,
thresholds, depth curves, pocket size/frequency, spawn dimensions, and repair limits.
Noise objects receive explicit seeds. Generation code has no calls to global random
state, making fixtures reproducible.

Generation is sliced across frames with progress reporting. A rejected map retries
with a deterministically derived seed and a configured maximum retry count.

## 10. Player and Physics

`PlayerController` is a thin coordinator of components:

- `GroundMotor`
- `AirMotor`
- `JumpAbility`
- `GrappleAbility`
- `ItemThrowAbility`
- `EnvironmentStatus`
- `PlayerHealth`

Components consume an `InputFrame` produced by `PlayerInputSource`. Tests inject a
fake source. Components communicate through typed state and signals rather than
querying siblings by scene path.

Collision uses chunked generated polygons or merged convex shapes for solid cells,
rebuilt only for dirty chunks near the player. A conservative temporary collision
overlay is applied immediately after a mutation and removed after the chunk rebuild,
preventing the player from colliding with visually removed terrain.

Hazard sampling queries occupied hexes through each terrain's hazard strategy.
Timers live in `EnvironmentStatus`, reset on leaving the applicable environment, and
emit a typed death cause through `PlayerHealth`.

## 11. Rendering

`WorldPresenter` owns a pool of `ChunkRenderer` nodes for visible chunks only.

- Build one batched mesh per terrain visual layer per visible chunk, not one node per
  cell.
- Generate flat-top hex vertices procedurally.
- Apply `TerrainVisualStyle` resources so fill, outline, and pattern cues stay data
  driven instead of branching on terrain identity.
- Procedural interior texture comes from shader-compatible noise or generated image
  textures supported by WebGL 2.
- Boundary outlines are emitted only where a solid cell neighbors air/passable space.
- Fluids may animate through UV/time uniforms without changing logical state.
- Rebuild a chunk only when its committed dirty flag changes.

`WorldCollisionPresenter` independently consumes collision dirty regions. Rendering
and collision never mutate the world model.

Vector source assets remain SVG. Imported raster size and filtering are explicitly
configured to avoid browser-dependent blur.

## 12. Camera and Score Markers

`DescendingCameraController` stores `deepest_camera_y`; its vertical output is the
maximum of that value and the downward target, clamped to map bounds. It never moves
upward during `PLAYING`.

`DepthMarkerPresenter` renders personal and global best dashed lines based on depth
values, independent of generated cell state. Markers remain readable but do not
collide or affect gameplay.

`AudioDirector` and `GameplayFeedback` are presentation-only companions that synthesize
short cues, rings, and camera shake from gameplay events without owning game rules.

## 13. Persistence and SimpleBoards

### Local persistence

`SaveRepository` reads/writes versioned JSON at `user://claim_earth_save.json`:

```json
{
  "version": 1,
  "last_player_name": "Player",
  "personal_best_depth": 0,
  "pending_submissions": []
}
```

Writes use a temporary file and replace strategy where supported. Corrupt or missing
data falls back to defaults. If `OS.is_userfs_persistent()` reports unavailable, the
UI warns that progress may not survive the browser session.

### Online service

`LeaderboardService` exposes asynchronous signals/results for:

- `fetch_top(limit)`
- `submit_score(score_submission)`
- `retry_pending()`

`SimpleBoardsLeaderboardService` uses `HTTPRequest` and configuration supplied at
export time. API key and leaderboard ID are never embedded in domain resources or
tests. DTO parsing validates required fields and treats malformed responses as
service failures.

`FakeLeaderboardService` is injected in tests and offline development. UI depends
only on the interface and explicitly renders loading, success, empty, and failure
states.

## 14. Testing Strategy

Use GUT 9.6 pinned under `addons/gut`. Tests are typed GDScript and run both from the
editor and headlessly.

### Unit tests

- Hex coordinate conversion, all six neighbors, distance, indexing, and boundaries.
- Camera downward-only behavior and map clamping.
- Inventory selection/consumption and invalid commands.
- Movement state transitions, coyote time, jump buffering, rope limits, and detach.
- Projectile trajectory and blast-distance calculations.
- Every terrain blast/hazard/motion strategy.
- Flag landing, lava destruction, score depth, and run outcome races.
- Save migration, corrupt-save recovery, name validation, and pending submissions.

### Contract and property tests

- Iterate every registered terrain and item definition and run the same capability
  contract. Adding a resource automatically adds it to the test matrix.
- Reject duplicate IDs and incomplete definitions.
- Verify no domain script uses forbidden terrain/item type branching with a small
  source scan test.
- Generate many fixed seeds and assert dimensions, sealed sides/bottom, safe spawn,
  valid IDs, deterministic hashes, and configured distribution ranges.

### Simulation fixtures

Use small textual grids converted through the registry. Cover falling, lateral flow,
sand swaps, lava-water stone creation, boundaries, conflicts, sleep/wake, explosion
mutations, alternating traversal, and cadence commits.

Run every fixture through each backend and compare committed cell buffers and dirty
regions. Randomized tests always print the seed on failure.

### Integration and scene tests

- Menu to generation to play.
- Input selection and throwing each item.
- Hook attach, swing inputs, and release.
- Each death cause discards score.
- Valid flag pauses play, prefills editable name, submits once, saves local best, and
  starts a new seeded run.
- Destroyed flag cancels the run.
- Leaderboard success, empty, malformed, timeout, offline, and retry behavior through
  the fake service.
- Dirty terrain updates both presentation and collision.

### Performance and release tests

- Benchmark generation and active-band simulation using fixed worst-case fluid/sand
  fixtures.
- Assert no simulation frame slice exceeds its configured main-thread budget.
- Assert a terrain commit completes within 0.5 seconds on the agreed reference
  desktop browser/machine; report metrics rather than hiding overruns.
- Headless test command is part of CI and must fail on any test error.
- CI exports the Web preset and checks that all expected files exist.
- Browser smoke automation loads the exported build in current Chromium and Firefox,
  starts a run, confirms input responsiveness, and fails on console errors.

Manual testing is for movement feel, rope enjoyment, pacing, difficulty, visual
clarity, sound, and balance. A reproducible logic defect requires an automated
regression test before it is considered fixed.

## 15. Build Order

1. Project input, resource registries, hex math, world buffers, and GUT setup.
2. Static generated cave rendering/collision and deterministic generation tests.
3. Player movement, downward camera, and hook with test input injection.
4. Item factory, bombs, immediate terrain mutation, deaths, and flag outcome.
5. Cooperative simulation backend and complete terrain interactions.
6. Run flow, HUD, persistence, personal-best marker, and menu.
7. SimpleBoards adapter, leaderboard UI, pending submission handling.
8. Vector/procedural art, animation, effects, audio, performance tuning.
9. Web export, itch.io upload verification, browser smoke tests, and balancing.

Every stage ends with a playable vertical path and green automated tests. Avoid
building all infrastructure before validating the corresponding gameplay behavior.

## 16. Definition of Done

- Public behavior matches `docs/GAME_DESIGN.md`.
- New terrain and item definitions require resources/strategies, not edits to central
  conditional logic.
- Domain rules are deterministic and covered by unit or contract tests.
- Web export runs on itch.io in Chromium and Firefox without requiring experimental
  thread support.
- Performance instrumentation confirms 60 FPS gameplay target and 0.5-second terrain
  commits on the reference machine.
- No known logic defect is left solely to manual reproduction.
