# Claim Earth Agent Guide

These instructions apply to the entire repository. The base game is implemented;
work is now maintenance, portfolio polish, and feature development.

`README.md` is the human project entry point. This file is the operating guide for
coding agents and should stay focused on implementation constraints.

## Start Here

1. Read `docs/GAME_DESIGN.md` for the current player-facing contract.
2. Read `docs/ARCHITECTURE.md` for ownership boundaries and extension recipes.
3. Read `tools/README.md` for local commands.
4. For visual or art changes, read `docs/ASSET_NOTES.md`.
5. For export or release work, read `docs/RELEASE_CHECKLIST.md`.
6. Inspect the closest implementation and tests before proposing a new abstraction.

There is intentionally no execution ledger or prescribed build sequence. Use Git
history for historical context. Keep documentation focused on the current system.

## Project Constraints

- Godot 4.6.3, typed GDScript, Compatibility renderer.
- Primary release target: itch.io Web on current desktop Chromium and Firefox.
- Do not add C# runtime code, GDExtension, or a required threaded/compute path.
- Keep the default Web export playable without cross-origin isolation.
- Visual assets must be SVG/vector or procedurally generated.
- Preserve deterministic world seeds and resource-driven tuning.
- A score exists only after a valid flag landing. Death and a lava-destroyed flag
  never save a score.

## Architecture Boundaries

- `AppRoot` composes controllers, routes signals, and owns run-state transitions.
- `AppUiController` owns UI presentation and emits user intents.
- `RunWorldController` owns generation, player lifetime, simulation scheduling,
  camera/bounds setup, and presenter attachment.
- `RunItemController` owns inventory, projectiles, explosions, and flag resolution.
- `ScoreController` owns local persistence and leaderboard workflows.
- `WorldGrid` is authoritative terrain state. `WorldPresenter` consumes committed
  cells and rebuilds visible dirty chunks.
- Terrain and item behavior is selected through resources, strategies, registries,
  and factories. Never add central branches on terrain/item IDs, names, classes, or
  resource paths.
- Keep simulation data packed. Never create one Node per map cell.
- Use typed direct calls inside one ownership boundary and typed signals across
  boundaries. Avoid autoload state and broad event buses.
- Put gameplay tuning in validated `.tres` resources instead of script constants.

## Change Guidance

- New terrain: add behavior/style resources, register the definition in
  `config/terrain/catalog.tres`, and extend registry/simulation tests.
- New item: add an `ItemDefinition`, action factory/action, resources, catalog entry,
  and item workflow tests. Selection code must remain type-agnostic.
- Generation changes: edit passes/profile resources and retain seed determinism,
  spawn safety, valid IDs, and the final two stone rows.
- UI changes: keep formatting and visibility in `AppUiController`; route gameplay
  intent through `AppRoot`.
- Simulation changes: preserve `TerrainSimulationBackend` and committed/working
  buffer semantics. Rendering, player physics, and input must stay frame-responsive.
- Leaderboard changes: depend on `LeaderboardService`; automated tests use
  `FakeLeaderboardService` and never call SimpleBoards.

## Verification

- Every bug fix gets a deterministic regression test when practical.
- Domain rules belong in unit tests; complete player workflows belong in integration
  tests; structural frame-loop risks belong in performance tests.
- Run `./tools/test.ps1` for every code change.
- Run `./tools/test_performance.ps1` for world, simulation, rendering, collision, or
  frame-loop changes.
- Run `./tools/ci.ps1 -Milestone` for export, browser, release, or broad changes.
- Check GDScript diagnostics and `git diff --check` before completion.
- Manual QA is for feel, balance, visual clarity, and browser presentation, not for
  discovering deterministic correctness bugs.

## Working Style

- Work with existing uncommitted changes; never discard changes you did not make.
- Keep changes scoped and leave the project playable and tests green.
- Update `GAME_DESIGN.md` when player-visible behavior changes.
- Update `ARCHITECTURE.md` when ownership, data flow, extension points, or required
  verification changes.
- Do not add planning/history sections to these documents. A temporary task plan may
  live in the conversation or issue tracker and should be removed when obsolete.
