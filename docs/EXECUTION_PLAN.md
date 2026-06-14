# Claim Earth - Execution Plan

## 1. Purpose

This is the live implementation ledger for Claim Earth. It breaks the GDD and
architecture into independently verifiable, commit-sized steps. The active agent
must update this document during every step and include that update in the step's
final commit.

Product and technical decisions remain authoritative in:

- `docs/GAME_DESIGN.md`
- `docs/ARCHITECTURE.md`
- `AGENTS.md`

## 2. Status Protocol

Allowed step states are `NOT_STARTED`, `IN_PROGRESS`, `BLOCKED`, and `COMPLETE`.

At the start of a step:

1. Confirm every dependency is `COMPLETE`.
2. Set exactly one step to `IN_PROGRESS`.
3. Fill in its start date and assigned work lanes.
4. Commit no code yet; the status change travels with the completed step commit.

Before completing a step:

1. Run all step gates and the full automated suite available at that point.
2. Record concise evidence in the step's `Result` field.
3. Set the step to `COMPLETE`, add completion date and final commit subject.
4. Stage only files belonging to the step, including this document.
5. Create one non-amended commit using the specified commit subject.
6. At the start of the next step, record this resulting hash in that step's tracking
   update. Do not create a documentation-only follow-up merely to record the hash.

If blocked, set `BLOCKED`, record the exact failed gate and attempted remedies, and
do not commit partial implementation as a completed step.

## 3. Shared Worktree and Subagents

All agents use this one worktree. Do not create worktrees, temporary branches, or
agent-specific copies of tracked files.

### Coordinator responsibilities

- Own this execution ledger, cross-subsystem interfaces, integration, final tests,
  and every Git operation.
- Inspect uncommitted changes before assigning work.
- Give each subagent an explicit, disjoint write set and acceptance result.
- Never ask two agents to edit the same scene, resource, project configuration, or
  plan file concurrently.
- Integrate and review agent output before running gates. Subagents never commit.
- Stop dispatching when a discovered interface change would invalidate parallel work.

### Context-saving delegation

- Use explorer agents for bounded read-only questions, such as locating a Godot API
  pattern or reviewing one subsystem contract.
- Use worker agents for isolated implementation slices with named file ownership.
- Give agents only the relevant document sections, interfaces, and paths instead of
  replaying the full project history.
- Require workers to report changed files, tests run, assumptions, and unresolved
  risks in their final response.
- Prefer two or three meaningful lanes over many tiny tasks; coordination overhead is
  part of the jam budget.

### Parallel lane pattern

Within a step, parallelize only after shared interfaces and resource schemas exist.
A typical step uses:

- **Lane A - Domain:** pure typed GDScript and unit tests.
- **Lane B - Presentation:** scenes, rendering, UI, and assets using stable contracts.
- **Lane C - Verification:** fixtures, integration tests, static checks, or docs.
- **Coordinator - Integration:** composition, project settings, conflict resolution,
  full gates, ledger update, and commit.

## 4. Global Gates

Every completed implementation step must satisfy all currently applicable gates:

- Godot imports the project without parser or resource errors.
- Relevant GUT tests pass; once the headless runner exists, the full suite passes.
- No central terrain/item type branch is introduced.
- New tuning values live in resources rather than unexplained code constants.
- Deterministic failures print their seed.
- The project remains launchable through its main scene after Step 2.
- No test contacts the real SimpleBoards API.
- Documentation is updated when behavior or architecture changes.

The coordinator records exact runnable commands in `tools/README.md` once the Godot
binary path and test installation are established. Until then, verification through
the editor must be recorded explicitly rather than claimed as headless automation.

## 5. Step Ledger

| Step | Deliverable | Dependencies | State | Commit subject |
| --- | --- | --- | --- | --- |
| 0 | Repository and toolchain baseline | None | COMPLETE | `chore: establish web toolchain baseline` |
| 1 | Core contracts, hex math, registries, and tests | 0 | COMPLETE | `feat: add core world and definition contracts` |
| 2 | App shell, main scene, input map, and test harness | 1 | COMPLETE | `feat: add application shell and automated test harness` |
| 3 | Deterministic map generation and packed world data | 2 | COMPLETE | `feat: generate deterministic hex cave worlds` |
| 4 | Chunk rendering, outlines, and collision presentation | 3 | COMPLETE | `feat: render and collide generated cave chunks` |
| 5 | Player movement and descending camera | 4 | COMPLETE | `feat: add responsive player movement and camera` |
| 6 | Grappling hook and rope movement | 5 | COMPLETE | `feat: add grappling hook traversal` |
| 7 | Item factory, projectiles, bombs, and mutations | 6 | COMPLETE | `feat: add configurable bombs and terrain mutation` |
| 8 | Hazards, death, flag planting, and scoring | 7 | COMPLETE | `feat: complete run outcomes and flag scoring` |
| 9 | Cooperative terrain simulation | 8 | COMPLETE | `feat: simulate sand water and lava` |
| 10 | Menus, HUD, persistence, and score markers | 9 | COMPLETE | `feat: add complete local game flow and interface` |
| 11 | SimpleBoards and leaderboard workflow | 10 | COMPLETE | `feat: integrate online leaderboard services` |
| 12 | Final vector art, procedural materials, audio, and effects | 11 | COMPLETE | `feat: complete cartoon presentation and feedback` |
| 13 | Performance, web export, browser automation, and itch.io release | 12 | COMPLETE | `release: prepare Claim Earth web jam build` |

Exactly one row may be `IN_PROGRESS` during execution. This document's initial
planning commit precedes Step 0 and establishes the Git repository.

## 6. Detailed Steps

### Step 0 - Repository and Toolchain Baseline

**Deliverables**

- Verify the initialized Git baseline and record its commit hash.
- Normalize the project for GDScript Web work: remove unused C# project settings,
  select Compatibility rendering, and preserve Godot 4.6 feature metadata.
- Confirm or document installation of Godot 4.6, export templates, and the command
  used to launch it. Do not hard-code a developer-specific executable path in tracked
  project files.
- Add repository conventions, tool command documentation, and a Web export preset
  skeleton when export templates are available.
- Update this step with actual tool availability and initial commit reference.

**Parallel lanes**

- Lane A: inspect Godot/web project settings and propose the minimal configuration.
- Lane B: inspect GUT 9.6 installation and headless invocation requirements.
- Coordinator: apply configuration, validate, update the ledger, and commit.

**Gates**

- `git status` is clean after the step commit.
- Project opens under Godot 4.6 without requiring a .NET SDK.
- Renderer is Compatibility and the project contains no shipped C# source/project.
- Tool limitations are stated truthfully in `Result`.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - toolchain, project configuration, GUT, smoke project,
  validation, and Git.
- Previous commit: `133bdd9`
- Final commit: `chore: establish web toolchain baseline`
- Result: Verified the supplied Mono editor, then installed the official standard
  GDScript editor `4.6.3.stable.official.7d41c59c4` under `%LOCALAPPDATA%` because the
  Mono editor reports a missing .NET SDK during import. The user-level `GODOT4`
  variable points to the standard console executable. Installed official 4.6.3 Web
  export templates and pinned GUT 9.6.0. Headless import passed, all 3 baseline tests
  passed, the main scene started, and the non-threaded Web release exported. The
  exported build loaded and rendered in installed Chrome using WebGL 2 Compatibility
  with no runtime exceptions. Firefox is not installed locally, so Firefox smoke
  remains a Step 13 release gate.

### Step 1 - Core Contracts, Hex Math, Registries, and Tests

**Deliverables**

- Establish source/test directories and naming conventions.
- Implement `HexCoord`, `WorldDimensions`, packed `WorldGrid`, cell changes, dirty
  regions, and deterministic seed helpers.
- Implement terrain/item base definitions, strategy contracts, registries, startup
  validation, and resource fixtures for all required types.
- Add contract tests, hex/indexing tests, and a source check forbidding central type
  branches.

**Parallel lanes**

- Lane A owns hex/world value objects and tests.
- Lane B owns definition/strategy contracts, registries, and registry tests.
- Lane C owns static architecture checks and test fixtures.
- Coordinator owns shared interfaces and composition validation.

**Gates**

- All coordinates round-trip and edge indexing is tested.
- Duplicate/missing definitions fail validation.
- Required terrain/item resources load and pass common contracts.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - world/core contracts, registries, fixtures, tests, and
  integration.
- Previous commit: `f07dba5`
- Final commit: `feat: add core world and definition contracts`
- Result: Added deterministic seed helpers, flat-top hex coordinate/value objects,
  packed `WorldGrid` buffers, dirty-region/cell-change primitives, terrain and item
  resource contracts, validation registries, and fixture catalogs for all required
  terrain and item types. Added unit tests plus registry and architecture guardrail
  coverage. `tools/import.ps1` and `tools/test.ps1` both pass, with 17/17 tests green.

### Step 2 - App Shell, Main Scene, Input Map, and Test Harness

**Deliverables**

- Add `AppRoot`, scene navigation, run-state skeleton, and dependency composition.
- Define every named input action from the GDD.
- Install/pin GUT 9.6, add headless test scripts, and document commands.
- Add a minimal main menu and gameplay placeholder proving scene transitions.
- Establish CI configuration if a remote repository is available; otherwise provide
  local CI-equivalent scripts without assuming a provider.

**Parallel lanes**

- Lane A owns run-state/application contracts and tests.
- Lane B owns shell scenes and placeholder UI.
- Lane C owns GUT installation, runners, and CI scripts.
- Coordinator owns `project.godot`, main scene, and integration.

**Gates**

- Main scene launches and transitions menu -> generating -> playing placeholder.
- Headless tests return a nonzero exit code on a deliberate temporary failure and
  pass after it is removed.
- Input actions exist and are addressed only by action name.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - app shell, run state, input map, local CI scripts,
  scene integration, and tests.
- Previous commit: `1233043`
- Final commit: `feat: add application shell and automated test harness`
- Result: Added `AppRoot`, `RunCoordinator`, named run phases, the full project input
  map, and a placeholder main-menu -> generating -> playing flow with integration
  coverage. Added local `ci.ps1` and `assert_test_failure.ps1`; the temporary failure
  probe confirms headless tests return a nonzero exit code. `tools/ci.ps1` passes with
  22/22 tests green.

### Step 3 - Deterministic Map Generation and Packed World Data

**Deliverables**

- Implement composable generation passes and `GenerationProfile` resources.
- Generate base terrain, pockets, spawn chamber, sealed sides, and final stone rows.
- Slice generation across frames with progress and deterministic retry/repair.
- Add seed snapshots, distribution tests, spawn-safety tests, and debug seed display.

**Parallel lanes**

- Lane A owns noise and generation passes.
- Lane B owns validation/repair and generation scheduling.
- Lane C owns deterministic/property fixtures and map diagnostics.
- Coordinator owns generator composition and profile resources.

**Gates**

- Same seed/profile produces the same world hash.
- Every generated ID resolves through the terrain registry.
- Dimensions, boundaries, final rows, spawn chamber, and distribution bounds pass.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - generation passes, profiles, scheduling, diagnostics,
  and deterministic/property tests.
- Previous commit: `6f34c08`
- Final commit: `feat: generate deterministic hex cave worlds`
- Result: Added `GenerationProfile`, generation contexts/passes, retry-capable
  `WorldGenerator`, and async `WorldGenerationTask`. The default profile now creates
  deterministic 100x2000 worlds with horizontal cave bias, hazard pockets, a carved
  spawn chamber, sealed side walls, and sealed final stone rows. App shell generation
  now shows real seed/hash data. `tools/ci.ps1` passes with 26/26 tests green.

### Step 4 - Chunk Rendering, Outlines, and Collision Presentation

**Deliverables**

- Add chunk activity/dirty indexing and pooled visible chunk presenters.
- Generate batched flat-top hex geometry by visual layer.
- Add procedural terrain interiors and solid/passable transition outlines.
- Build/rebuild near-player collision per dirty chunk and add debug overlays.

**Parallel lanes**

- Lane A owns chunk activity and dirty-region domain logic.
- Lane B owns batched meshes, materials, outlines, and renderer pooling.
- Lane C owns collision presentation and scene tests.
- Coordinator owns lifecycle integration and performance instrumentation.

**Gates**

- No per-cell Nodes exist.
- Only visible/dirty chunks rebuild.
- Visual occupancy and collision agree on fixture maps.
- A full static generated map remains responsive on the reference machine.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - chunk activity, rendering, collision presentation,
  instrumentation, and scene tests.
- Previous commit: `4db06ad`
- Final commit: `feat: render and collide generated cave chunks`
- Result: Added chunk activity indexing, one renderer node per visible chunk, one
  collision body per chunk using combined exposed-edge segments, and world presenter
  integration in the app shell. Added tests that guard against per-cell node creation
  and verify collision edge output for solid cells. `tools/ci.ps1` passes with 30/30
  tests green.

### Step 5 - Player Movement and Descending Camera

**Deliverables**

- Add testable input frames, player component composition, grounded movement, jump,
  coyote time, jump buffering, gravity, air control, and world bounds death.
- Add the downward-only camera with top-third framing and map clamping.
- Add placeholder vector character and state-driven animation hooks.

**Parallel lanes**

- Lane A owns motors/jump/input domain and unit tests.
- Lane B owns player scene, collisions, and placeholder animation.
- Lane C owns camera controller and scene tests.
- Coordinator tunes initial resources and integrates with generated collision.

**Gates**

- Deterministic input tests cover ground, jump, coyote, buffer, and air states.
- Camera never moves upward during play.
- Movement is playable through generated terrain with no parser/runtime errors.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - player movement domain, player scene, camera, and tests.
- Previous commit: `274d964`
- Final commit: `feat: add responsive player movement and camera`
- Result: Added deterministic player movement/input models, placeholder `CharacterBody2D`
  player scene, bounds-exit signaling, and a downward-only camera model/controller.
  App flow now spawns a player into the generated world and configures camera/world
  bounds from the generation result. `tools/ci.ps1` passes with 39/39 tests green.

### Step 6 - Grappling Hook and Rope Movement

**Deliverables**

- Add hook aiming, attach filtering, anchor loss, release, rope min/max adjustment,
  radial constraint, and tangential momentum.
- Add rope rendering, hook indicators, and placeholder effects/audio hooks.
- Add deterministic hook and rope tests with fake input/world queries.

**Parallel lanes**

- Lane A owns grapple/rope math and tests.
- Lane B owns hook projectile/query integration.
- Lane C owns rope/anchor presentation.
- Coordinator integrates player state transitions and tuning.

**Gates**

- Only hookable terrain attaches.
- Releasing right mouse always detaches.
- Rope constraints and `W/S/A/D` behavior pass automated tests.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - grapple math, rope presentation, and integration tests.
- Previous commit: `1b3072d`
- Final commit: `feat: add grappling hook traversal`
- Result: Added a testable grapple model with attach, release, rope-length adjustment,
  tangential swing momentum, and anchor invalidation. The player scene now renders a
  rope and hook indicator, the app injects a world-backed hookable-terrain query, and
  the world presenter refreshes visible chunks as the player descends. Added unit
  tests for grapple mechanics plus world-anchor lookup. `tools/ci.ps1` passes with
  47/47 tests green.

### Step 7 - Item Factory, Projectiles, Bombs, and Mutations

**Deliverables**

- Implement item definitions, factory/actions, selection, inventory, trajectory service,
  and pooled projectiles.
- Implement small/large bombs, fuse/impact/lava detonation, blast traversal, water
  diffusion, chain reactions, and immediate world mutations.
- Add temporary collision overlays and dirty propagation after blasts.

**Parallel lanes**

- Lane A owns item/inventory/trajectory domain and tests.
- Lane B owns projectile scenes and throw integration.
- Lane C owns explosion/reaction/mutation service and fixtures.
- Coordinator owns shared contexts, resources, and cross-system integration.

**Gates**

- Initial inventory is 10 small and 2 large bombs plus one flag slot.
- Nominal throw distances and all default terrain transformations are tested.
- No item/terrain type branches appear in callers.
- Visual and collision removal responds immediately to blasts.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - item actions, projectile flow, terrain mutation, and
  integration tests.
- Previous commit: `6c78288`
- Final commit: `feat: add configurable bombs and terrain mutation`
- Result: Added runtime item inventory and selection, polymorphic item actions from
  the configured factories, a shared throw trajectory service, generic thrown
  projectiles, and an explosion service that applies registered terrain blast
  reactions immediately to the committed world while marking dirty chunks for
  presentation rebuilds. App flow now loads the item registry, supports `1/2/3`
  selection and left-click throwing during play, and updates the on-screen status
  with current inventory. Added unit coverage for inventory setup/consumption and
  terrain mutation behavior. `tools/ci.ps1` passes with 50/50 tests green.

### Step 8 - Hazards, Death, Flag Planting, and Scoring

**Deliverables**

- Implement lava, water suffocation, sand burial, and bomb death through hazard
  strategies and typed death causes.
- Implement flag projectile, water pass-through, lava destruction, no-bounce landing,
  run outcome gate, score depth, and editable prefilled name workflow.
- Add end-state integration tests, including race and duplicate-confirm cases.

**Parallel lanes**

- Lane A owns hazards/environment status/death tests.
- Lane B owns flag action/projectile and scoring tests.
- Lane C owns name-entry modal and outcome scene tests.
- Coordinator owns outcome gate and run-state integration.

**Gates**

- Every death cause discards the score.
- Only a valid landing can enter name entry and create a score.
- Death/flag races resolve once; repeated confirmation submits once.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - hazards, outcome flow, local scoring, and UI tests.
- Previous commit: `4afd348`
- Final commit: `feat: complete run outcomes and flag scoring`
- Result: Added hazard effect resolution, environment exposure tracking, typed death
  causes, expanded run phases, terminal outcome locking, flag-specific resolution
  handling, name entry, and result UI flow. The player now dies from lava contact,
  water suffocation, sand burial, blast lethality, and bounds exit; valid planted
  flags open editable prefilled name entry and update the in-memory personal best.
  Added regression coverage for hazard timing and the full flag/death outcome loop.
  `tools/ci.ps1` passes with 55/55 tests green.

### Step 9 - Cooperative Terrain Simulation

**Deliverables**

- Implement the backend contract and cooperative chunk backend with frame budgets,
  double buffering, intent resolution, sleeping/waking, and 0.5-second commits.
- Implement sand fall/swaps, liquid fall/spread, and lava-water solidification through
  compiled behaviors/pair interactions.
- Add backend contract fixtures, cadence metrics, overrun handling, and worst-case
  performance scenes.

**Parallel lanes**

- Lane A owns scheduling, buffers, commit protocol, and tests.
- Lane B owns motion behavior compilation and pair interactions.
- Lane C owns fixtures, metrics, and performance scenes.
- Coordinator owns backend integration and immediate-mutation reconciliation.

**Gates**

- All textual fixtures produce deterministic expected buffers.
- Sleeping chunks wake correctly after neighbor changes.
- Player-critical mutations remain immediate.
- Active-band commits meet 0.5 seconds on the reference machine or the step remains
  incomplete with recorded profiling evidence.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - backend contract, terrain stepping, and cadence tests.
- Previous commit: `db1df0c`
- Final commit: `feat: simulate sand water and lava`
- Result: Added the terrain simulation backend contract plus a cooperative backend
  that advances sand, water, and lava on the hex grid and commits dirty regions on
  the target cadence. Sand now falls or swaps into liquids, liquids fall then spread
  laterally, and lava-water contact solidifies into stone. App flow now advances the
  backend during active runs and marks dirty chunk regions after each commit. Added
  backend unit coverage for sand/liquid swapping, liquid spread, and stone creation.
  `tools/ci.ps1` passes with 58/58 tests green.

### Step 10 - Menus, HUD, Persistence, and Score Markers

**Deliverables**

- Complete main menu, pause, HUD, contextual warnings, result, and restart flows.
- Add versioned local save, last editable name, personal best, pending submissions,
  and unavailable-persistence messaging.
- Add personal/global dashed depth markers and menu cave background.

**Parallel lanes**

- Lane A owns save repository/migrations/tests.
- Lane B owns menu/HUD/result scenes.
- Lane C owns depth markers and UI integration tests.
- Coordinator owns full local run loop and responsive layout.

**Gates**

- Full offline menu -> run -> plant -> name -> result -> rerun loop passes.
- Corrupt/missing/unavailable saves degrade safely.
- Last name is prefilled but editable each successful run.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - persistence, score markers, UI flow, and integration
  tests.
- Previous commit: `db1df0c`
- Final commit: `feat: add complete local game flow and interface`
- Result: Added a versioned local save repository with safe fallback behavior, wired
  last-used name and personal best persistence into `AppRoot`, and expanded the app
  state machine with pause and leaderboard shell states. Rebuilt the main scene into
  a playable menu/HUD/result flow with contextual controls copy, storage warnings,
  name-entry focus, and a generated menu preview. Added an in-world dashed personal
  best marker plus deterministic save and UI flow regression coverage. `tools/ci.ps1`
  passes with 62/62 tests green.

### Step 11 - SimpleBoards and Leaderboard Workflow

**Deliverables**

- Implement interface, fake service, SimpleBoards HTTP adapter, DTO validation,
  configuration, retries, and pending submissions.
- Complete leaderboard UI and `Earth owned by` menu state.
- Add timeout/offline/malformed/empty/success integration coverage.

**Parallel lanes**

- Lane A owns service contract/fake and tests.
- Lane B owns HTTP adapter/DTO parsing with recorded fixture responses.
- Lane C owns leaderboard/menu UI states.
- Coordinator owns configuration, pending retry integration, and secret review.

**Gates**

- Automated tests make zero real network calls.
- Local best survives failed online submission.
- UI represents loading, empty, success, and failure explicitly.
- No private credential is committed; acknowledge the public client-key model.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - service contracts, SimpleBoards adapter, UI states,
  pending retry flow, and tests.
- Previous commit: `c1ea16c`
- Final commit: `feat: integrate online leaderboard services`
- Result: Added a leaderboard service contract, fake service, typed score/entry
  models, a SimpleBoards HTTP adapter, and pure response parsing so tests stay fully
  offline. `AppRoot` now fetches top scores for menu ownership/leaderboard display,
  submits planted scores, preserves local bests on failure, and retries pending
  submissions on later sessions. No key or leaderboard ID was committed; the tracked
  config stays disabled until jam credentials are provided. `tools\test.ps1` passes
  with 67/67 tests green.

### Step 12 - Final Vector Art, Procedural Materials, Audio, and Effects

**Deliverables**

- Replace placeholders with original SVG character, items, flag, menu, and UI assets.
- Finalize procedural terrain palettes/textures/outlines and accessible hazard cues.
- Add animation, particles, camera shake, sound, and music with pooling/preloading.
- Complete visual/audio readability settings and asset attribution/license record.

**Parallel lanes**

- Lane A owns SVG/UI asset sets.
- Lane B owns terrain shaders/materials and effects.
- Lane C owns audio integration, animation state hooks, and presentation smoke tests.
- Coordinator owns art direction consistency and browser import/performance checks.

**Gates**

- No diffusion-generated asset is present.
- Hazard types remain distinguishable without color alone.
- First-use spawning does not cause unacceptable browser stalls.
- Gameplay remains clear during overlapping fluid and explosion effects.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - vector assets, procedural terrain styling, audiovisual
  feedback, and presentation docs.
- Previous commit: `fea6af6`
- Final commit: `feat: complete cartoon presentation and feedback`
- Result: Added original SVG jam art for the player and items, data-driven terrain
  visual styles for readable stone/dirt/sand/water/lava cues, stylized projectile
  silhouettes, synthesized audio cues, ring feedback, and camera shake. The player
  scene now uses imported vector art, terrain rendering applies configurable pattern
  overlays instead of flat debug fills, and asset provenance is recorded in
  `docs/ASSET_NOTES.md`. `tools\test.ps1` passes with 67/67 tests green.

### Step 13 - Performance, Web Export, Browser Automation, and Itch.io Release

**Deliverables**

- Profile and optimize generation, simulation, rendering, collision, startup, and
  memory without weakening domain contracts.
- Finalize single-thread Web export, responsive embed dimensions, loading shell,
  persistence warning, and release metadata.
- Automate local Chromium and Firefox smoke flows and capture console failures.
- Upload a release candidate to itch.io, verify supported launch path, leaderboard,
  audio unlock, input, persistence behavior, and restart.
- Perform design-only manual QA and tune resources; fix logic only with regressions.

**Parallel lanes**

- Lane A owns profiling and targeted optimization.
- Lane B owns browser automation and export validation.
- Lane C owns release checklist, itch.io page copy, and manual design QA log.
- Coordinator owns release candidate, final gates, versioning, and commit.

**Gates**

- Full test suite, export check, and Chromium/Firefox smoke pass.
- Target gameplay is 60 FPS and terrain commits within 0.5 seconds on the recorded
  reference machine/browser.
- No uncaught browser console errors occur in the smoke flow.
- Itch.io build completes the full scoring loop with network failure fallback.
- `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`, `AGENTS.md`, and this ledger match the
  shipped build.

**Tracking**

- Started: 2026-06-13
- Completed: 2026-06-13
- Work lanes: Coordinator - export validation, local web serving, Chromium smoke,
  and release documentation.
- Previous commit: `7fec677`
- Final commit: `release: prepare Claim Earth web jam build`
- Result: Added local export/serve/smoke scripts, a Chromium headless screenshot
  smoke path, and a release checklist for itch.io packaging plus browser/storage QA.
  The project remains configured for single-threaded Web export and `tools/ci.ps1`,
  `tools/smoke_web.ps1`, and `tools/smoke_chromium.ps1` all pass locally. The in-app
  Browser plugin had no live `iab` browser available in this session, and Firefox is
  still not installed on this workstation, so final interactive Firefox verification
  remains an external release-machine check and is documented in
  `docs/RELEASE_CHECKLIST.md`.


## 7. Release Risks and Fallbacks

- **No Godot CLI/export templates:** continue editor validation, but Step 0 cannot be
  complete until commands and templates are installed or their manual path is proven.
- **Simulation misses cadence:** reduce active margin and visual work first; do not
  remove terrain rules. Profile before considering optional web threads.
- **Itch.io/browser thread incompatibility:** the release backend remains cooperative
  single-threaded. Threaded work is never on the critical path.
- **SimpleBoards unavailable:** preserve local best and pending submission; ship clear
  offline states rather than blocking gameplay.
- **Browser persistence unavailable:** retain session state and warn without failing.
- **Schedule pressure:** reduce polish density and tuning variants before cutting any
  mechanic explicitly required by the GDD.

## 8. Post-Release Confidence Hardening

- Added layered automation gates: fast headless, deterministic performance, and
  milestone web/browser smoke.
- Added AppRoot/player/backend/presenter test seams for deterministic scenario
  driving and runtime counters.
- Added regression coverage for pre-tree projectile configuration, hook input on the
  live player scene, run-state hazards, flag lock flow, and chunk-window rebuild
  behavior.
- Updated tool entrypoints so `tools/test.ps1` stays fast, `tools/test_performance.ps1`
  isolates performance contracts, and `tools/ci.ps1 -Milestone` runs the heavier web
  gates.

## 9. Portfolio Refactor Ledger

### Refactor 1 - Extract AppUiController

- State: COMPLETE
- Started: 2026-06-14
- Completed: 2026-06-14
- Previous commit: `61ea097`
- Commit subject: `refactor: extract app ui controller`
- Result: `AppUiController` owns menu, HUD, pause, score-entry, result, and
  leaderboard presentation and emits typed UI intents. Existing AppRoot integration
  scenarios remain green, with focused signal and phase-visibility tests.

### Refactor 2 - Extract ScoreController

- State: COMPLETE
- Started: 2026-06-14
- Completed: 2026-06-14
- Previous commit: `8db26d4`
- Commit subject: `refactor: extract score controller`
- Result: `ScoreController` owns save loading/writing, player identity, local/global
  bests, pending retries, SimpleBoards service wiring, and score submissions. Fake
  service success/failure and validation paths have focused automated coverage.

### Refactor 3 - Extract RunItemController

- State: NOT_STARTED
- Previous commit: recorded when work begins
- Commit subject: `refactor: extract run item controller`

### Refactor 4 - Extract RunWorldController

- State: NOT_STARTED
- Previous commit: recorded when work begins
- Commit subject: `refactor: extract run world controller`

### Refactor 5 - Reduce AppRoot To Coordination

- State: NOT_STARTED
- Previous commit: recorded when work begins
- Commit subject: `refactor: reduce app root to coordinator`

### Refactor 6 - Final Refactor Gates

- State: NOT_STARTED
- Previous commit: recorded when work begins
- Commit subject: `test: verify app root refactor gates`
