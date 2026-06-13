# Claim Earth Agent Instructions

These instructions apply to the entire repository.

## Sources of truth

- Product behavior: `docs/GAME_DESIGN.md`
- Technical design, boundaries, test strategy, and build order:
  `docs/ARCHITECTURE.md`
- Active implementation status, ownership, gates, and commit sequence:
  `docs/EXECUTION_PLAN.md`
- When implementation and documentation disagree, stop and reconcile the documents
  in the same change. Do not silently invent a third behavior.

## Non-negotiable constraints

- Use Godot 4.6 and typed GDScript for shipped gameplay code.
- The release target is an itch.io Web build for current desktop Chromium and
  Firefox using the Compatibility renderer.
- Do not introduce C# runtime code, GDExtension, or a mandatory threaded/compute
  dependency. They are incompatible with the required low-risk web release.
- All graphics must be vector assets or procedural textures. Do not use diffusion
  image generation.
- Keep the complete map fixed at 100 by 2000 cells unless the GDD is deliberately
  revised. Side boundaries and the final two rows are indestructible stone.
- Terrain simulation commits every 0.5 seconds while player input, physics,
  projectiles, hazards, and rendering remain responsive each frame.
- A score exists only after a valid planted flag. Death and lava-destroyed flags
  never save a score.

## Architecture rules

- Depend on interfaces/contracts and inject implementations at the composition root.
- Terrain and item behavior is polymorphic and resource-configured.
- Never branch over terrain or item type, ID, enum, resource path, class name, or
  display name in gameplay code. Use behavior strategies, registries, factories, or
  pair interactions.
- Keep hot simulation data packed and data-oriented. Do not create one Node per map
  cell.
- World mutation must pass through `WorldMutationService`; rendering and collision
  presenters are consumers, not authorities.
- Keep `TerrainSimulationBackend` replaceable. The cooperative backend is the release
  baseline; alternative backends must pass identical contract fixtures.
- Avoid global mutable state and broad event buses. Use typed direct calls within a
  subsystem and signals across ownership boundaries.
- Put tuning values in validated `.tres` resources rather than magic constants.
- Preserve deterministic seeds for generation and simulation diagnostics.

## Testing rules

- Use GUT 9.6 for Godot 4.6.
- Add unit tests with each domain behavior and integration tests with each workflow.
- Every bug fix includes a deterministic regression test when technically possible.
- New terrain and item definitions must automatically participate in registry contract
  tests.
- Randomized tests print and retain their seed on failure.
- Keep network tests offline through `FakeLeaderboardService`; never submit test
  scores to SimpleBoards.
- Before considering work complete, run relevant tests, the full headless suite, and
  the Web export smoke check when export behavior is affected.
- Manual QA evaluates game feel, balance, clarity, and polish. It is not the primary
  way to find deterministic logic defects.

## Working style

- Execute one step at a time from `docs/EXECUTION_PLAN.md`. Update its state, evidence,
  and next-step previous commit reference as part of every step.
- End every completed execution step with one coordinator-owned Git commit using the
  ledger's commit subject. Subagents never commit.
- All agents share the current worktree. Assign disjoint write sets, never create
  additional worktrees, and never allow concurrent edits to shared configuration,
  scenes, resources, or planning documents.
- Use subagents to save context for bounded parallel lanes after interfaces are fixed;
  the coordinator owns integration, tests, the ledger, and Git.
- Follow the staged build order in `docs/ARCHITECTURE.md`; leave the project playable
  and tests green after each stage.
- Prefer the smallest implementation that satisfies the documented contract.
- Do not add abstractions without a concrete extension, testing, or duplication
  benefit.
- Keep scenes focused on composition and presentation; keep deterministic rules in
  testable non-Node classes where practical.
- Update both design documents when a product or architecture decision changes.
