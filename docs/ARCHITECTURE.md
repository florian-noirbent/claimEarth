# Claim Earth - Architecture Guide

This document explains the implemented system and how to extend it. It is not a
historical build plan.

## Runtime Constraints

- Godot 4.7.2 with typed GDScript and the Compatibility renderer.
- Single-threaded Web export is the required baseline.
- No C# runtime, GDExtension, or required compute/thread support.
- Terrain is a fixed packed grid; scene nodes exist only for active gameplay and
  bounded world presentation.

## Repository Map

```text
config/                 Tunable Resource definitions and catalogs
scenes/app/main.tscn    Persistent application shell
scenes/app/run_session.tscn Disposable gameplay composition
scenes/player/          Player scene
scenes/ui/              Reusable editor-authored UI components
src/app/                Run state, preferences, input, and top-level controllers
src/generation/         Deterministic generation passes
src/items/              Definitions, actions, projectiles, explosions
src/leaderboard/        Service contract, fake, SimpleBoards adapter
src/player/             Movement, grapple, hazards, camera
src/presentation/       Chunk rendering, markers, effects
src/simulation/         Replaceable terrain simulation backend
src/statistics/         Lifetime player statistics, rules, and their persistence
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
| `AppRoot` | `StatisticsController` | Lifetime statistics, the in-progress run record, and statistics persistence |
| `AppRoot` | `FeedbackRouter` | Routing of gameplay and UI facts to `AudioDirector` and the session's `GameplayFeedback` |
| `RunSession` | `RunWorldController` | Registries, generation, player lifetime, simulation, camera bounds, presenter |
| `RunSession` | `RunItemController` | Inventory, selection, reward containers, explosive barrels, projectiles, explosions, flag flight |
| `RunSession` | `RunPerkController` | Unique perk pool, selected perks, and compiled immutable modifier snapshot |

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

UI motion is cosmetic and layered on top of logical state. `AppUiController` and the
`scenes/ui` components set visibility, text, and values first, then call the static
`UiMotion` helper (`src/app/ui_motion.gd`) for pops, fades, punches, shakes,
count-ups, bar growth, and button hover/press response. `UiMotion` keeps one tween per
control and channel (transform, modulate, value); starting an effect ends the previous
one on that channel at its rest state, so interrupted controls never keep a partial
scale, rotation, or opacity. Effects use scale, rotation, and modulate only, never
layout position, so containers stay authoritative. Tuning lives in the validated
`UiMotionConfig` resource `config/ui/ui_motion.tres`. Motion is skipped when no display
exists (`UiMotion.enabled`), so headless tests observe final states immediately; tests
that cover motion switch it on explicitly. A control that must leave after its owner
is already hidden, such as a chosen reward card, is moved to the UI `EffectsLayer`,
ignores input there, and frees itself. Feedback that needs facts from gameplay is
derived from data the UI already receives (item counts, depth, personal best); new
facts arrive through `AppRoot` like any other outcome.

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

## Feedback

Audio and visual feedback is a one-way seam. Gameplay owners emit typed facts and
never decide how a moment sounds or looks:

| Owner | Facts |
| --- | --- |
| `PlayerController` | `jumped`, `landed`, `hard_impact`, `knocked_out`, `hook_launched`, `hook_attached`, `hook_missed`, `hook_released`, `liquid_entered`, `liquid_exited`, `sand_burrow_changed`, `hazard_warning` |
| `RunItemController` | `item_thrown`, `tool_used`, `item_selected`, `projectile_bounced`, `projectile_resolved`, `fluid_bottle_burst`, `explosion_resolved`, `explosive_fuse_armed`, `world_object_destroyed`, `barrel_bumped`, `excavator_deployed`, `excavator_drilled`, `terrain_pulse_started`, `flag_flight_changed`, `flag_planted`, `flag_destroyed`, `reward_container_opened`, `reward_claimed` |
| `AppUiController` | `ui_feedback_requested(kind)` for hover and press on every button, including toolbar slots and reward cards |
| `AppRoot` | Run-state moments: run start, pause and resume, game over, score confirmed, player death, flag outcomes, victory, reward picker shown |

Facts carry world positions, speeds in px/s, definitions, and resource-declared keys
(`ItemDefinition.feedback_key`, container and barrel `statistics_key`).
`RunWorldController` relays player facts as `player_*` signals and `RunSession`
relays every fact unchanged. `HazardWarningTracker` rate-limits `hazard_warning`
with the level and interval exported on `PlayerController`.

`FeedbackRouter` (owned by `AppRoot`) is the only caller of the two sinks. It
connects each session's facts, converts hex units to world units, and calls one
named method per moment on both sinks; `AppRoot` calls its public methods for the
run-state moments. `AudioDirector` exposes one `play_*` method per moment and
`GameplayFeedback` one `spawn_*`/`show_*` method per moment that has a visual. The
sinks own every tuning choice: thresholds on raw speeds, colors, sizes, volumes, and
shake strength. Camera shake has one entry point,
`GameplayFeedback.request_shake(intensity, world_position)`, which forwards to the
run camera that `FeedbackRouter.use_camera` hands over when the player exists.

### World Effects

`GameplayFeedback` decides which effect a moment plays and at what scale, tint,
direction, and strength; it filters weak or repeated moments (footstep landings,
slow bounces, barrel bumps inside a cooldown). Everything about an effect's look is
data:

| Type | Role |
| --- | --- |
| `EffectEmitter` | One particle layer: shape (disc, glow, ring or arc, streak, chunk, shard, star), blend (normal or additive), count, delays, lifetime, placement, motion (ballistic or orbit), size, and a color gradient over its life |
| `EffectRecipe` | The emitter layers of one effect in draw order, plus the camera shake the moment asks for (`config/presentation/effects/*.tres`) |
| `GameplayEffectLibrary` | One recipe per moment, keyed dictionaries for moments that vary by death cause, resolution kind, object key, or container key, and the speed thresholds (`config/presentation/gameplay_effects.tres`) |
| `WorldEffects` | Child node of `GameplayFeedback` in `run_session.tscn`: holds the library and plays recipes into two shared `EffectBatch` layers |
| `EffectBatch` | Fixed ring of packed particle slots simulated and drawn by one canvas item with immediate-mode `_draw` |

Rules that keep effects cheap and safe:

- Effects never add nodes. The two layers (normal below additive) hold at most
  `particles_per_layer` particles each. Above `pressure_start` usage an emitter
  spawns a shrinking share of its count, down to `pressure_floor`; a full layer
  replaces its oldest particles. A layer without particles stops processing.
- Particle motion uses the frame delta, particles end by lifetime, and the layers
  are freed with the session, so disposing a run mid-effect needs no cleanup.
- Recipe lengths and speeds are world px multiplied by the played scale. Explosion
  recipes are played at a scale of the blast radius, so their lengths are fractions
  of that radius and one recipe serves every explosion size; `explosion_large` adds
  layers for explosions with large feedback, and the explosion's effect color tints
  the emitters that set a `tint_amount`.
- The layers draw above terrain, world objects, and the player (`layer_z_index`) and
  below the HUD. Cave darkness is part of the terrain shader, so effects are not
  darkened: fire, sparks, and flashes read as emissive in unlit caves. Effects do
  not add light to the terrain lighting simulation.
- Anchored emitters (knockout stars, hazard pulse) follow the node the run camera
  follows.
- A planted flag stays in the world as a sprite owned by `GameplayFeedback`.

To add or change an effect, edit or add an `EffectRecipe` resource, reference it
from the library, and play it from the moment's `GameplayFeedback` method. A new
look that the emitter fields cannot express belongs in `EffectEmitter` and
`EffectBatch`, not in a one-off effect node.

### Camera Shake

`DescendingCameraController` feeds every request into `CameraShakeModel`, a pure
trauma model. A request for a peak offset adds trauma (the root of its share of the
full offset); trauma is capped at 1 and decays exponentially. The shake is trauma
squared times seeded simplex noise sampled over time, applied as a translation and
a small roll, so motion is smooth and repeatable. The request position attenuates
the shake by its distance from the camera target (full inside
`shake_full_distance`, none beyond `shake_zero_distance`) and adds a short kick away
from the cause. The offset is added after follow and bounds are resolved and never
moves the view below the world's bottom edge. Explosions ask for an intensity
proportional to their blast radius. `shake_intensity_multiplier` (0 to 2, set
through `set_shake_intensity_multiplier`) scales or disables all shake for
accessibility settings.

To add a feedback moment:

1. Emit a typed fact from the owner at the moment it happens; relay it through
   `RunWorldController` (player facts) and `RunSession`.
2. Add a documented `play_*` method to `AudioDirector` and, when it has a visual, a
   `spawn_*`/`show_*` method to `GameplayFeedback`.
3. Connect the fact in `FeedbackRouter.attach` and call both sinks from one handler.
4. Test the fact on its owner and, for a new routing rule, in
   `tests/integration/test_feedback_flow.gd`.

## Statistics

`StatisticsController` is a persistent sibling of `ScoreController` with its
thresholds in `StatisticsRules` (`config/statistics/statistics_rules.tres`). It knows
nothing about items, perks, or UI: callers pass stable IDs, death and flag-loss causes,
and container keys, which it stores as string-keyed counters in `PlayerStatistics`.
Event counters update lifetime totals at once; run aggregates (games played, depth,
time, streaks, victories) fold in at `end_run()`. A run records at most one death
and at most one flag resolution, and both may occur because Relentless drops the
flag on death.

Data flow: `RunItemController` emits typed `item_used(ItemDefinition)`,
`reward_claimed(RewardClaim)`, and `world_object_destroyed(statistics_key, position)` outcomes,
which `RunSession` forwards. The last reports a chest, geode, or explosive barrel
consumed by its own detonation, keyed by its definition's `statistics_key`. `AppRoot` maps
those and its existing run outcomes to controller calls: `begin_run` when a run
becomes ready, `record_progress` from `_process` during active play, the first
unlocked death (including a Relentless death), the planted or destroyed flag, and
`end_run` on a terminal outcome, at flag plant before name entry, and whenever a
restart or the menu abandons a run. `end_run` is idempotent. Late outcomes ignored
by the terminal-outcome lock are not recorded.

The main-menu Statistics button emits `statistics_requested`. `AppRoot` passes a
statistics snapshot, `ItemCatalog`, `PerkCatalog`, `StatisticsPresentationConfig`,
and the rules to `StatisticsViewBuilder`, which returns generic
`StatisticsViewData` sections (tiles, icon grid, or ranked bars). `AppUiController`
hands that data to `StatisticsPage`, which renders entries without knowing what
they mean. The builder iterates catalogs and presentation key lists; keys missing
from the presentation still render with its fallback icon.

`GENERATING` creates a new run session, generates terrain, initializes the GPU
simulation backend, and commits the configured initial settlement ticks before the
player, generated containers, and inventory are attached. `MAIN_MENU` disposes the
active gameplay session and shows static menu art. Generation and settlement tasks
must tolerate their host session being cancelled and freed.

`REWARD_PICKER` is a mandatory modal entered from `PLAYING` or `FLAG_IN_FLIGHT`.
`AppRoot` remembers the originating phase, suspends the complete run session, routes
one UI choice back to `RunItemController`, and restores that phase after the reward
is applied. Terminal outcomes clear and supersede a pending reward.

## Perks And Reward Containers

`PerkDefinition` resources contain composable modifier and cancellation effects.
`RunPerkController` draws unique choices from `PerkCatalog`, then compiles the
selected effects into `PerkModifierSnapshot`; consumers receive the snapshot rather
than mutating authored tuning resources. `ItemChestDefinition.reward_kind` keeps the
chest picker generic: ordinary chests draw item options while geodes draw perks.
Container geometry, destruction behavior, light, and generated placement remain
definition-driven. Explosion runtime specs keep terrain destruction, vaporization,
and player-kill radii separate so perks can safely adjust one without changing the
others.

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
gameplay writes normally replace the primary component and clear the secondary
component. Resource-authored explosion emissions are the exception: they preserve
both components while filling a matching product, then use an unused secondary slot
only when nearby visible capacity is exhausted.

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
`WorldGrid` texture remains the CPU snapshot mirror for gameplay writes, editor
previews, and reset state.

`WorldDimensions` owns rectangular indexing. `HexCoord` and `HexMetrics` own grid and
world-space conversion. Terrain byte IDs resolve through `TerrainRegistry`.

`WorldPresentationConfig` owns shared visual tuning for playable runs and the static
World Gen preview: terrain/fluid shader controls plus the sky, grass, and cave
backdrop. `WorldBackground` draws that backdrop behind terrain. Editing the shared
resource refreshes active renderer parameters without regenerating the world.
Static editor previews force full brightness in `WorldPresenter` without rewriting
the generated grid's lighting bytes; the main menu uses separate static art.
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
treats out-of-bounds grid cells beside and below the map as virtual solid hexes and those above the top row, between the side walls, as open sky, then tests circular and convex-polygon bodies against nearby solid hex polygons from
`HexMetrics`. Its shape-aware Air queries accept only destinations where the complete
body is clear. They search by canonical hex distance, then break equal-ring ties by
world distance, upward position, and left position. Every shape query visits only the
offset-cell range whose hexagons can reach the shape. The query also reports that
range for a world rectangle and one solidity state per cell, optionally flagging Air.
`TerrainRegionWatch` captures those states for a region and reports when committed
terrain changes them; it compares the region's packed cell bytes first, so light and
fluid quantity changes cost one byte comparison and never count as a change.
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
hazards, breathability, and blast response. The catalog is `config/terrain/catalog.tres`.
Motion resources also provide a non-negative per-second viscosity coefficient. This
player-drag value is independent of the cellular-automata transfer rates that tune
how the terrain itself flows.

Call sites must not branch on terrain ID, display name, script class, or resource
path. Add behavior through the existing strategy/resource boundary. The simulation
backend may compile registry data into IDs for its hot loop.

`EnvironmentStatus` owns generic player hazard meters. Terrain hazard behaviors
resolve fill-aware meter definitions, including their icon, color, fill/recovery
durations, configurable full-rate terrain quantity, and display order; the player samples those definitions at occupied body
hexes and forwards meter snapshots through the run controllers to `AppUiController`.
Suffocation is the one environment-wide rule: the head must resolve to terrain marked
breathable, walking upward through partial cells before evaluating the next full cell;
individual terrain may instead block breathing at any quantity. The HUD is
generic and never branches on a hazard cause. New terrain hazards therefore add a
behavior resource and authored icon rather than UI logic.

`TerrainSimulationBackend` defines initialization, advancement, commit, region
read, render attachment, active texture access, availability, mutation notification,
and shutdown.
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
Secondary material first moves into compatible or partial neighbors. A displaced
pressure-balancing gas crosses a foreign medium only against that medium's own
travel, down through a light gas and up through anything else, so it cannot cycle
between the same cells and stall their primary transfers. When trapped,
it pressure-balances pairwise into full same-material neighbors up to the packed
255 ceiling. This replaces whole-cell density swaps and preserves lighter liquids
under falling or landsliding Sand. Pairwise resolution conserves component
quantities unless an explicit rule applies, such as liquid contact or gameplay
mutation. The simulation supplies a virtual solid cell for pair neighbors below the
map, preventing moving terrain from leaking through the bottom edge without
requiring a generated solid row. A completed six-pass tick publishes only a
revisioned snapshot commit; the backend does not copy or diff every cell on the CPU.
Terrain contact reactions are typed `TerrainContactReaction` strategies in the
terrain catalog. Each strategy compiles its opcode, products, direction policy, and
four meaningful tuning bytes without terrain-name or ID branches. The GPU reaction
texture contains a 16x16 header plane and a 16x16 parameter plane; reaction shader
branches read only parameters defined by their opcode. Dense and light gases author
normal pressure and packed capacity on their terrain definition. Light gases run the
liquid rules upside down within the same pair ownership, without an ID-specific
branch: they rise, fill cells from the ceiling down to normal pressure, and level
across the half-hex column stagger through their side-flow offset. Above normal
pressure, matching neighbors equalize pairwise, and a cell pushes gas into a lower
neighbor only when every higher exit is blocked and it exceeds that neighbor by the
height between them: a full cell vertically, the side-flow offset diagonally.
Displaced secondary light gas only rises. The pair above the top row has no in-bounds
owner, so the odd vertical pass instead removes light gas from top-row cells at its
vertical rate; no other terrain crosses a map edge.

Boiling is the one once-per-tick proximity reaction. During the even vertical pass,
each Water cell, flagged as a boiling reactant in the compiled rule texture so other
terrain skips the scan, checks its six neighbors for the authored boiling opcode, consumes whole
Water units on a deterministic cadence, and adds the configured expanded Steam product
to an empty or matching component in that same cell. A Water cell reacts at most once
per tick regardless of contact-edge count; occupied component capacity applies
backpressure, and the Lava neighbor is never mutated.

Persistent burning is an optional terrain behavior compiled into additional rule
texture rows. It authors the burn-product ID, ignition-token quantity, deterministic
per-tick consumption schedule, and product yield; `255` means no burn product.
Static burning Sulfur retains its configured matching secondary Sulfur Dioxide token
while all non-burning secondary materials, including Air ID `0`, may drain completely.

Exact `TerrainChangeSet`s remain reserved for bounded gameplay mutations whose
affected cells are already known.

`BlastReaction` can author a `TerrainEmissionDefinition`. `ExplosionService` records
those emissions while resolving destruction, applies terrain changes first, then
deterministically deposits the product through primary and compatible secondary
capacity. It never creates a matching secondary component under unburning terrain
whose persistent-burn product would interpret that component as an ignition marker.
Sulfur Dioxide already present in a vaporize core follows the same preserved-component
path, beginning at the first hex ring beyond the core rather than being deleted.

Gameplay writes are authoritative. External `TerrainChangeSet`s cancel any
unfinished six-pass tick, upload the patched packed world texture, and restart
simulation from that known state. This keeps player physics and item effects
independent from the visual simulation cadence while preventing simulation races
with explosions or digging.

The shipped backend is GPU render-texture only; headless tests do not emulate terrain
motion. Playable runs use `GenerationProfile.initial_settle_ticks` to advance complete
six-pass ticks before attaching the player and generated containers. Progress is
reported as one monotonic loading sequence weighted by generation steps and committed
settlement ticks. Headless runs detect the unavailable backend, skip settlement, and
continue so automated startup tests remain usable. Threaded and compute backends are
not implemented. A future threaded backend must
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

Generation context/results also carry typed `GeneratedItemChestSpawn` and
`GeneratedExplosiveBarrelSpawn` records. The generic generated-item pass partitions
its configured depth band into deterministic jittered areas, probes each area's
candidates in a seeded order, asks one `GeneratedItemPlacementDefinition` whether a
candidate is acceptable, then lets it prepare terrain and record a typed spawn. It
never scans or shuffles the full map. Columns, area height, column stagger, and
per-area chance are resource-driven. Exact anchors and chamber footprints are
reserved across item passes, but no minimum separation is imposed. Rejecting a
candidate through `accepts_anchor` consumes no randomness, so kinds that accept every
anchor keep their anchors. `ItemChestDefinition` carves Air at and above the anchor
while preserving the previously generated terrain below and records the per-chest
reward seed. `ExplosiveBarrelDefinition` accepts only anchors with a solid three-cell
cradle below and no terrain carrying its detonating tags within its clearance, carves
a smaller chamber the same way, and records the barrel spawn; its pass runs after the
chest and geode passes with its own seed key, so it leaves their anchors unchanged.
Playable sessions hand those records to `RunItemController`; the World Gen preview
instantiates the same chest and barrel scenes with interaction disabled. Add another
generated-item kind with the recipe below; the grid sampler must remain type-agnostic.

The editor-side tuning surface lives in
`addons/claim_earth_generation_tools/`. It previews static generated terrain through
the same `WorldGenerator` and `WorldPresenter` path used at runtime. It also displays
generated chest and barrel visuals without interaction, but does not spawn the player,
projectiles, or terrain simulation.

Generation changes must retain deterministic hashes, valid registered terrain IDs,
spawn air, the default bottom lava band, and distribution tests. Grid-edge collision
uses virtual solid cells at the sides and the bottom; generation does not create stone boundary walls.

## Player, Camera, And Items

`PlayerController` is a `CharacterBody2D` node coordinating `PlayerMovementModel`,
`GrappleModel`, environment sampling, grid-backed terrain motion, and horizontal
clamping. `PlayerRuntimeTuning` compiles the immutable perk snapshot against the
authored movement and grapple resources, producing duplicated active configs and
typed player, terrain, and hazard policy without exposing modifier keys throughout
the controller. `PlayerPresentationController` owns the body rig, rope, hook, and
sand-outline visuals; `PlayerController` updates it synchronously after physics and
it owns no gameplay decisions or independent processing.

The body is `PlayerRig`, a cutout skeleton generated into
`scenes/player/player_rig.tscn` by `tools/build_player_rig.gd`. Bones form the
hierarchy, while the part sprites sit in one flat list in draw order and follow
their bones through `RemoteTransform2D`, so draw order never depends on the bone
tree or on `z_index`. A second flat list behind it draws every part again as a grown
silhouette through `player_outline.gdshader`, which outlines the whole body without
an offscreen pass. Each physics step `PlayerController` fills one
`PlayerAnimationSnapshot`; the pure `PlayerAnimationSelector` turns it into a
`PlayerAnimationState` and a facing, including the landing crouch timer and the
short grace that ignores footing lost for a few frames on hex slopes. The rig's
`AnimationTree` state machine holds one clip per state with a cross-fade between
every pair and only blends; it never decides a state. The tree runs in manual
mode: `PlayerPresentationController` advances the rig once per physics step and the
procedural layers then pose on top of the clips in the same call. Those layers are
arm aiming at the hook (or, while swinging, holding the hands on the body's center
line so mirroring the rig leaves the rope start in place), the lean along the rope,
and the knockout. The presentation steps `GrappleRopeVisual` in the same call: it
receives only whether the hook is attached and where, and derives the launch
flight, the bite, the fall back after a miss, and the whip back after a release
from those facts and the step time. While knocked
out, the presentation turns the body (spin in flight, rolling with ground speed,
lying flat at rest) and `PlayerRig` swings the limp bones as damped pendulums under
gravity, the body's acceleration, air drag, and spin, inside per-joint limits, then
eases them back to the clips. To add a state, add its name to
`PlayerAnimationState`, a clip to the builder's table, and its rule and tests to
the selector, then regenerate the scene.

The player does not use Godot terrain colliders for movement; terrain collision
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
unchanged. Its typed result reports position, velocity, the velocity change caused
by escape, and whether the body overlapped terrain at all, without knowing about player damage. `PlayerController` consumes the velocity change for impact rules;
`ItemChest` ignores it and uses a separate swept-rectangle fall path that changes
only vertical velocity, stops without restitution, and derives a snapped visual tilt
from left/right terrain support.

A resting `ItemChest` or `ExplosiveBarrel` does not poll. Each composes a
`WorldBodySleep` state that holds its sleep flags, check intervals, and a
`TerrainRegionWatch`, and emits `woken` so the body resumes its physics steps. Once a
grounded support check leaves a chest's position and rotation unchanged, a chest with
sleep enabled stops its physics steps and captures a watch over every cell that check
read: the body, the support contact strip, the tilt probes, and, for a chest enclosed
in terrain, the whole unstuck search region including its Air cells. An identical
check would repeat the same result until one of those cells changes, so waking on a
change and resuming the ordinary fall and unstuck steps rests the chest where an
always-polling chest would. A barrel rests when a slow grounded step barely
accelerated it or terrain encloses it; its watch always flags Air, so lava or acid
arriving in an empty cell counts as a change. Fluid replacing fluid does not change a
watch, so a barrel touching a non-Air fluid keeps polling on its grounded interval
instead of sleeping. Pushes, hook pulls, and blast impulses wake a barrel directly.
`RunItemController` owns one `WorldBodySleepScheduler` that tracks the sleep state of
every generated chest and barrel, enables their sleep, and delivers the wake checks:
on the grounded check interval for bodies inside the camera view plus a margin, on
slower intervals for off-screen and enclosed bodies, and immediately for bodies
watching the dirty rectangle of an item-caused terrain change. The intervals, the
margin, and the support contact distance are `ItemChestDefinition` and
`ExplosiveBarrelDefinition` tuning. Simulation commits replace the committed cells
without reporting a changed region, which is why simulated terrain reaches sleeping
bodies through the scheduled comparison rather than a notification. A body that no
scheduler tracks never sleeps and keeps polling its support on the grounded check
interval.

`WorldGrappleAnchorQuery` also tests the hook ray against the circles of the run's
`GrappleTargetRegistry` and returns whichever comes first: the nearest target contact
or the first hookable terrain cell. A `GrappleAnchor` that holds a `GrappleTarget`
follows the target through `current_position()`, and the rope length is measured to
the target's center. While a target is attached, `GrappleModel` leaves the player's
velocity and position untouched and calls `pull_toward` on the target whenever the
player is farther away than the rope length; rope-length input still applies.
`PlayerController` keeps the swing-only rules (suspended ground snapping, free air
control under Glass Cannon, and touch rope mapping) for terrain anchors
(`is_swing_attached()`). An invalid target detaches the hook on the next physics step.
Player code never learns the target's type: `RunSession` creates one registry per run
and passes it to `RunWorldController.configure_grapple_targets` for the anchor query
and to `RunItemController.configure_run`, which registers and unregisters targets as
their objects enter and leave the run and empties the registry in `clear_run()`.

`DescendingCameraController` is horizontally locked by `RunWorldController`, zoomed
to map width, and uses `DescendingCameraModel` for downward-only vertical movement.

Items are registered through `config/items/catalog.tres`. `ItemDefinition` points to
an `ItemActionFactory`; factories create polymorphic `ItemAction` implementations.
`RunItemController` treats all selected items through that contract. `WorldRigidBody2D`
owns terrain sampling, gravity, shared grid-edge collision response, and blast-pulse reception for dynamic item bodies.
`ItemProjectile` composes that body with item resolution, bounce, fuse, and temporary flare light;
autonomous objects such as the excavator use the same body directly. `ExplosiveBarrel`
extends the body for terrain sampling and blast-impulse reception but moves as a
circle through `TerrainBodyMotionSolver`, the player's solver, so it rolls, rests, and
receives a per-step velocity change. It composes `WorldExplosive2D` like a chest and
requests immediate detonation when terrain carrying its definition's
`detonating_terrain_tags` touches its center or rim samples with an active hazard, or
when a collision's velocity change reaches `impact_detonation_speed`.
`RunItemController` spawns barrels from their generated spawn records and registers
their explosives, sleep states, and grapple targets; `ExplosiveBarrelGrappleTarget`
adapts a barrel through a weak reference. `active_projectile_count()` and debug item
clearing skip generated barrels. While the run is active and barrels exist, the
controller runs one physics step that hands every barrel the player's position,
collision radius, and velocity; an overlapping barrel wakes and moves out
horizontally with a capped share of that velocity, and the player is never slowed. The renderer reserves high-frequency light slots for the player and the
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
also propagated to projectiles, chest and barrel physics, chest monitoring, the
barrel push step, and explosive chain timers so pause and modal phases freeze all
active item workflows.

`ExplosionService` traverses hexes, asks each terrain blast strategy for its effect,
updates committed cells, and returns an `ExplosionResult` containing the terrain
change set plus the inclusive lethal-core cells. The lethal radius always vaporizes
terrain and is also checked against the player. Bombs, chests, and barrels compose
`WorldExplosive2D` with separate validated `ExplosionDefinition` resources.
`RunItemController` registers those components generically; lethal-cell footprint
overlap arms a one-shot delayed chain without branches on the host item type. An
explosive configured to arm in the blast radius (barrels opt in through
`detonates_in_blast_radius`) also arms when its own hex lies within the explosion's
blast radius in hex steps from the impact hex, the same reach the terrain blast
propagates. Every arming starts the explosive's chain fuse, so with a positive fuse
a chain advances one link per fuse instead of recursing within one explosion. The
component runs physics steps only while that chain fuse burns. Every detonation
deposits `ExplosionDefinition.terrain_emission` at the explosion origin after terrain
destruction, while `perk_terrain_emission` stays perk-gated; the barrel uses it for an
overpressured Sulfur Dioxide cloud. `RunItemController` compiles `CompiledTerrainData`
once per run and shares it with chests, barrels, projectiles, and excavators.
Explosion definitions also tune radial impulse strength. `RunItemController` applies
that impulse through `WorldRigidBody2D`, so bombs, flags, excavators, barrels, and
future dynamic items share the behavior without selection branches. A future jelly perk can expose
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

`StatisticsRepository` stores lifetime statistics in a separate
`user://claim_earth_statistics.json`, written through a temporary file and only when
a run ends (or statistics are reset), never per frame. Missing or corrupt data, and
invalid fields, fall back to empty values. The controller does no disk IO until
`configure()`; `AppRoot` keeps statistics in memory only in test mode unless a test
supplies a path through `configure_statistics_path_for_test`.

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
4. Add contact rules through `TerrainContactReaction` resources and extend simulation only through strategy/registry compilation.
5. Add registry, rule, generation, and rendering tests as applicable.

### Add An Item

1. Add an action factory and action implementing the common contracts.
2. Add definition/factory `.tres` files and register the definition in the catalog.
3. Keep selection, HUD inventory, and spawning generic.
4. Test inventory, projectile lifecycle, resolution, and full run-state effects.

To add an item to chest rewards, add an `ItemChestOption` to the chest definition
resource with its quantity and relative selection weight. No picker or controller
branch is required.

### Add A Generated World Object

1. Subclass `GeneratedItemPlacementDefinition` with validated tuning and implement
   `accepts_anchor`, `required_edge_clearance`, `prepare_terrain`, and `record_spawn`
   into a typed spawn list on `GenerationContext` and `WorldGenerationResult`.
2. Register the definition in `config/generation/item_catalog.tres` and add a
   `GeneratedItemPass` instance after the existing item passes with its own
   `pass_seed_key`, so existing anchors stay unchanged.
3. Spawn and own the runtime nodes in `RunItemController`, registering explosives,
   sleep states, and grapple targets through their generic contracts, and show them
   non-interactively in the World Gen preview.
4. Add fixed-seed generation, preview, and run-workflow tests.

### Add A Grapple Target

1. Implement a `GrappleTarget` adapter for the object (validity, anchor position,
   radius, `pull_toward`) that reads invalid once the object is freed or spent.
2. Register it in the run's `GrappleTargetRegistry` from the object's owning
   controller when it enters the run and unregister it when it leaves; never add
   target-type checks to player or grapple code.
3. Cover attachment, pulling, and invalidation with a fake target in grapple tests
   and with the real object in an integration test.

### Add A Run Workflow Or Screen

1. Add UI nodes under `UiLayer` and presentation logic to `AppUiController`.
2. Emit a typed intent signal rather than calling gameplay directly.
3. Route it in `AppRoot`; add a `RunPhase` only when behavior truly needs a state.
4. Apply the final visibility and values at once, then add motion through `UiMotion`
   with durations from `UiMotionConfig`; buttons created at runtime call
   `UiMotion.attach_button`.
5. Cover visibility, transition, repeated-entry, and cleanup behavior. Cover motion
   with `UiMotion.enabled` forced on and assert that controls end at rest.

### Add A Statistic

1. Add the field or counter to `PlayerStatistics`, including `to_dictionary` and
   tolerant `from_dictionary` parsing.
2. Add a typed `record_*` method to `StatisticsController`; per-frame paths must not
   allocate, save, or emit.
3. Emit the source outcome as a typed signal from its owner and route it in `AppRoot`.
4. Present it in `StatisticsViewBuilder` with generic entries; new death causes,
   flag-loss causes, and containers only need a `StatisticKeyPresentation` entry in
   `config/statistics/statistics_presentation.tres`.
5. Cover the rule in unit tests and the complete workflow in
   `tests/integration/test_statistics_flow.gd`.

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
| UI motion and feedback | `test_ui_motion` and `test_app_ui_motion` unit tests plus fast suite |
| Generation | Fixed-seed generation tests plus fast suite |
| Simulation/rendering/collision | Fast suite and performance suite |
| Save/leaderboard | Offline fake-service tests plus fast suite |
| Statistics | Controller/builder unit tests, statistics flow integration test, plus fast suite |
| Feedback facts and routing | Owner signal tests, feedback flow integration test, plus fast suite |
| World effects and camera shake | Effect library validation, effect budget and feedback unit tests, shake model tests, fast suite, and performance suite |
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
